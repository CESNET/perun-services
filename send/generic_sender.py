import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

import boto3
import botocore.handlers
import requests
from botocore.config import Config
from destination_classes import (
    Destination,
    DestinationFactory,
    S3Destination,
    S3JsonDestination,
    UrlDestination,
    UrlJsonDestination,
)
from sys_operation_classes import SysOperation


class Transport:
    TIMEOUT = 9000  # 150 * 60 sec = 2.5h
    TIMEOUT_KILL = 60  # 60 sec to kill after timeout

    def __init__(self, destination: Destination, temp: tempfile.NamedTemporaryFile):
        self.destination_class_obj = destination
        self.temp = temp

    def prepare_transport(self, opts: str):
        """
        Prepares transport.
        """
        self.set_transport_command()
        self.extend_transport_command(opts)

    def set_transport_command(self):
        """
        Prepares transport command and saves it as an instance param self.transport_command.
        """
        raise NotImplementedError

    def init_transport_command(self):
        """
        Helper method for creating transport command.
        :return: transport command
        """
        raise NotImplementedError

    def process_data(self, tar_command):
        """
        Process data. Extract files and convert to base64 for host windows destination types.
        :param tar_command:
        :return: (returncode, stdout, stderr)
        """
        process_tar = subprocess.Popen(tar_command, stdout=subprocess.PIPE)
        transformation_process = self.destination_class_obj.process_data(process_tar)
        # the code below does not raise any exceptions, so try block (or context manager) should not be necessary
        # however if the issue persists / arises again, look into context managers / try blocks to
        # handle interruptions, etc.
        the_process = subprocess.Popen(
            self.transport_command,
            stdin=transformation_process.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        (stdout, stderr) = the_process.communicate()

        (stdout_temp, stderr_temp) = transformation_process.communicate()
        if transformation_process.returncode != 0:
            print(stderr_temp.decode("utf-8"), file=sys.stderr, end="")

        (stdout_temp, stderr_temp) = process_tar.communicate()
        if process_tar.returncode != 0:
            print(stderr_temp.decode("utf-8"), file=sys.stderr, end="")

        return the_process.returncode, stdout, stderr

    def extend_transport_command(self, opts: str):
        """
        Adds port and opts to transport command.
        :param transport_command: transport command
        :param port: port
        """
        if self.destination_class_obj.port is not None:
            self.transport_command.extend(["-p", self.destination_class_obj.port])
        if opts:
            self.transport_command.extend(opts)
        self.transport_command.append(self.destination_class_obj.host)

    def handle_transport_return_code(
        self, return_code: int, stdout: bytes, stderr: bytes
    ):
        """
        Handles transport method's return code.
        :param return_code: return code
        """
        raise NotImplementedError

    def prepare_directories_and_files(self):
        hostname_dir = SysOperation.get_temp_dir()
        with open(os.path.join(hostname_dir.name, "HOSTNAME"), mode="w+") as hostfile:
            hostfile.write(self.destination_class_obj.hostname)
            hostfile.flush()

            generated_files_dir = SysOperation.get_gen_folder(
                self.destination_class_obj.facility_name,
                self.destination_class_obj.service_name,
            )
            SysOperation.persist_spool_files(
                self.destination_class_obj.facility_name,
                self.destination_class_obj.service_name,
                [hostname_dir, generated_files_dir],
            )
            return hostname_dir, generated_files_dir

    def prepare_tar_command(self, hostname_dir, generated_files_dir):
        return SysOperation.prepare_tar_command(
            self.tar_mode,
            hostname_dir,
            generated_files_dir,
            self.destination_class_obj.destination,
        )

    def prepend_timeout_command(self, transport_command):
        timeout_command = [
            "timeout",
            "-k",
            str(Transport.TIMEOUT_KILL),
            str(Transport.TIMEOUT),
        ]
        timeout_command.extend(transport_command)
        return timeout_command

    def send(self):
        """
        The actual sending is done here.
        handle_transport_return_code must be implemented for this.
        """
        hostname_dir, generated_files_dir = self.prepare_directories_and_files()
        tar_command = self.prepare_tar_command(hostname_dir.name, generated_files_dir)
        # prepend timeout command
        self.transport_command = self.prepend_timeout_command(self.transport_command)

        return_code, stdout, stderr = self.process_data(tar_command)

        if return_code == 124:
            # special situation when error code 124 has been thrown. That means - timeout and terminated from our side
            print(stdout.decode("utf-8"), end="")
            print(stderr.decode("utf-8"), file=sys.stderr, end="")
            print(
                "Communication with slave script was timed out with return code: "
                + str(return_code)
                + " (Warning: this error can mask original error 124 from peer!)",
                file=sys.stderr,
                end="",
            )
        else:
            self.handle_transport_return_code(return_code, stdout, stderr)
            if return_code != 0:
                print(
                    "Communication with slave script ends with return code: "
                    + str(return_code),
                    file=sys.stderr,
                    end="",
                )
        exit(return_code)


class SshTransport(Transport):
    tar_mode = "-c"

    def set_transport_command(self):
        self.transport_command = SysOperation.load_custom_transport_command(
            self.destination_class_obj.service_name
        )
        if self.transport_command is None:
            self.transport_command = self.init_transport_command()

    def init_transport_command(self):
        """
        Prepares base transport command for SSH connection.
        :return: transport command
        """
        return [
            "ssh",
            "-o",
            "PasswordAuthentication=no",
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "GSSAPIAuthentication=no",
            "-o",
            "GSSAPIKeyExchange=no",
            "-o",
            "ConnectTimeout=5",
        ]

    def extend_transport_command(self, opts):
        """
        Adds port, opts and slave command to transport command.
        :param transport_command: transport command
        :param port: port
        """
        super().extend_transport_command(opts)

        slave_command = "/opt/perun/bin/perun"
        self.transport_command.append(slave_command)

    def handle_transport_return_code(self, return_code, stdout, stderr):
        print(stdout.decode("utf-8"), end="")
        print(stderr.decode("utf-8"), file=sys.stderr, end="")


class UrlTransport(Transport):
    PERUN_CERT = "/etc/perun/ssl/perun-send.pem"
    PERUN_KEY = "/etc/perun/ssl/perun-send.key"
    PERUN_CHAIN = "/etc/perun/ssl/perun-send.chain"
    tar_mode = "-cz"
    http_ok_codes = [200, 201, 202, 203, 204]

    def set_transport_command(self):
        self.transport_command = SysOperation.load_custom_transport_command(
            self.destination_class_obj.service_name
        )
        if self.transport_command is None:
            self.transport_command = self.init_transport_command()

            # append BA credentials if present in service config for the destination
            auth = SysOperation.get_auth_credentials_from_service_file(
                self.destination_class_obj.service_name,
                self.destination_class_obj.destination,
            )
            if auth is not None:
                username, password = auth
                if username and password:
                    self.transport_command.extend(["-u", f"{username}:{password}"])

    def init_transport_command(
        self, content_type: str = "application/x-tar", method: str = "PUT"
    ):
        """
        Prepares base transport command for CURL connection.
        If available, adds common perun certificate.
        :param temp:
        :param content_type: for example 'application/json
        :return: transport command
        """
        transport_command = ["curl"]
        # add certificate to the curl if cert file and key file exist, and they are readable
        if (
            os.access(UrlTransport.PERUN_CERT, os.R_OK)
            and os.access(UrlTransport.PERUN_KEY, os.R_OK)
            and os.access(UrlTransport.PERUN_CHAIN, os.R_OK)
        ):
            transport_command.extend(
                [
                    "--cert",
                    UrlTransport.PERUN_CERT,
                    "--key",
                    UrlTransport.PERUN_KEY,
                    "--cacert",
                    UrlTransport.PERUN_CHAIN,
                ]
            )
        # errors will be saved to temp file

        # add standard CURL params
        transport_command.extend(
            [
                "-i",
                "-H",
                "Content-Type:" + content_type,
                "-w",
                "%{http_code}",
                "--show-error",
                "--silent",
                "-o",
                self.temp.name,
                "-X",
                method,
                "--data-binary",
                "@-",
            ]
        )
        return transport_command

    def handle_transport_return_code(self, return_code, stdout, stderr):
        if return_code == 0:
            # check if curl ended without an error (ERR_CODE = 0)
            # (if not, we can continue as usual, because there is an error on STDERR)
            http_code = int(stdout)
            if http_code not in self.http_ok_codes:
                # check if HTTP_CODE is different from OK
                # if yes, then we will use HTTP_CODE as ERROR_CODE which is always non-zero
                self.temp.seek(0, 0)
                # print(self.temp.read(), file=sys.stderr)
                print(
                    f"Call to URL JSON endpoint ({self.destination_class_obj.destination}) failed with error message"
                    f" ({self.temp.read()}): Status code: {http_code}",
                    file=sys.stderr,
                )
                exit(http_code)
            else:
                # if HTTP_CODE is OK, then call was successful and result call can be printed with info
                # result call is saved in temp file
                self.temp.seek(0, 0)
                print(self.temp.read())
                exit(0)
        else:
            print(stderr.decode("utf-8"), file=sys.stderr, end="")
            exit(return_code)


class S3Transport(Transport):
    tar_mode = "-cz"

    def __init__(self, destination: Destination, temp: tempfile.NamedTemporaryFile):
        super().__init__(destination, temp)
        # Allow ':' in bucket name; ':' separate tenant and bucket in '<S3-bucket-address>'
        botocore.handlers.VALID_BUCKET = re.compile(r"^[a-zA-Z0-9.\-_:]{1,255}$")
        access_key, secret_key, filename_extension, extension_format = (
            SysOperation.get_custom_config_properties(
                destination.service_name,
                destination.destination,
                ["access_key", "secret_key", "filename_extension", "extension_format"],
            )
        )

        if not (access_key and secret_key):
            raise ValueError("""access key and secret key must be configured in the service 
                             configuration in /etc/perun/services/{service_name}/{service_name}.py file.
                             
                             Example of such file:
                             
                             credentials = {
                                "<S3-bucket-address>": { 'access_key': "<key>", 
                                'secret_key': "<key>", 'filename_extension': True/False,
                                 'extension_format': "<strftime()-friendly string>", 'url_endpoint': "<url>",
                                  'auth_type': "basic",
                                  'credentials': { 'username': "<ba-username>", 'password': "<ba-password>" } }
                             }
                             """)

        self.bucket_name = destination.hostname
        self.filename_extension = (
            filename_extension if isinstance(filename_extension, bool) else False
        )
        self.extension_format = (
            extension_format
            if isinstance(extension_format, str)
            else "%Y-%m-%d_%H:%M:%S"
        )
        self.s3_client = boto3.client(
            "s3",
            endpoint_url=destination.endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            config=Config(
                request_checksum_calculation="when_required",
                response_checksum_validation="when_required",
            ),
        )

    def prepare_transport(selfself, opts: str):
        # Not needed
        pass

    def send(self):
        """
        Custom send function, since we are not generating any command here, but rather using boto3.
        """
        hostname_dir, generated_files_dir = self.prepare_directories_and_files()
        tar_command = self.prepare_tar_command(hostname_dir.name, generated_files_dir)
        process_tar = subprocess.Popen(tar_command, stdout=subprocess.PIPE)
        tar_output_path = os.path.join(
            hostname_dir.name, f"{self.destination_class_obj.service_name}.tar.gz"
        )

        with open(tar_output_path, "wb") as tar_output_file:
            shutil.copyfileobj(process_tar.stdout, tar_output_file)

        (stdout, stderr) = process_tar.communicate()
        if process_tar.returncode != 0:
            print(stderr.decode("utf-8"), file=sys.stderr, end="")

        dst_filename = self.prepare_dst_filename(
            f"{self.destination_class_obj.facility_name}/{self.destination_class_obj.service_name}",
            "tar.gz",
        )
        s3_dst_filename_url = self.upload_file_to_s3(tar_output_path, dst_filename)

        # Call configured URL endpoint
        self.call_url_endpoint(s3_dst_filename_url)

    def prepare_dst_filename(self, filename_base, format):
        filename_extension_string = ""
        if self.filename_extension:
            filename_extension_string = (
                f"_{datetime.now().strftime(self.extension_format)}"
            )

        return f"{filename_base}{filename_extension_string}.{format}"

    def upload_file_to_s3(self, local_filepath, dst_filename):
        """
        Uploads file to S3 Bucket using boto3 library. Returns url of the uploaded file

        :param local_filepath: Path to the local file being uploaded
        :param dst_filename: Name the uploaded file should have in the S3 bucket
        :return: url of the uploaded file
        """
        s3_dst_filename_url = f"{self.destination_class_obj.destination}/{dst_filename}"
        self.s3_client.upload_file(local_filepath, self.bucket_name, dst_filename)
        print(
            f"Upload of file ({dst_filename}) to S3 bucket ({self.bucket_name}) successful."
        )
        return s3_dst_filename_url

    def call_url_endpoint(self, s3_dst_filename_url):
        # Make the URL call if endpoint and auth configuration are present
        url, auth_type, credentials = SysOperation.get_custom_config_properties(
            self.destination_class_obj.service_name,
            self.destination_class_obj.destination,
            ["url_endpoint", "auth_type", "credentials"],
        )

        if url:
            headers = {}
            auth = None
            if auth_type == "basic":
                auth = (credentials.get("username"), credentials.get("password"))
            elif auth_type == "bearer":
                headers["Authorization"] = f"Bearer {credentials.get('token')}"

            data = {"uploaded_filename": s3_dst_filename_url}
            response = requests.post(
                url,
                headers=headers,
                auth=auth,
                json=data,
            )
            if response.status_code not in range(200, 300):
                print(
                    f"Call to URL endpoint ({url}) with data ({data}) failed. Status code: {response.status_code}",
                    file=sys.stderr,
                )
                exit(response.status_code)
            else:
                print(
                    f"Successfully called URL endpoint ({url}) with data ({data}). Status code: {response.status_code}"
                )
        else:
            print(
                f"No URL endpoint set. If any is to be called, it must be configured in /etc/perun/services/"
                f"{self.destination_class_obj.service_name}/{self.destination_class_obj.service_name}.py file."
            )


class S3JsonTransport(S3Transport):
    def send(self):
        """
        Custom send function, since we are not generating any command here, but rather using boto3.
        """
        json_file_path = SysOperation.get_generated_json_file_path(
            self.destination_class_obj.facility_name,
            self.destination_class_obj.service_name,
        )

        file_basename = os.path.splitext(os.path.basename(json_file_path))[0]

        dst_filename = self.prepare_dst_filename(
            f"{self.destination_class_obj.facility_name}/{file_basename}",
            "json",
        )

        s3_dst_filename_url = self.upload_file_to_s3(json_file_path, dst_filename)

        # Call configured URL endpoint
        self.call_url_endpoint(s3_dst_filename_url)


class UrlJsonTransport(UrlTransport):
    def init_transport_command(
        self, content_type: str = "application/json", method: str = "PUT"
    ):
        return super().init_transport_command(content_type, method)

    def send(self):
        """
        Send JSON data to the destination. Prepares transport command, processes JSON data, and executes the transport.
        """
        json_file_path = SysOperation.get_generated_json_file_path(
            self.destination_class_obj.facility_name,
            self.destination_class_obj.service_name,
        )

        with open(json_file_path, "rb") as json_file:
            self.transport_command = self.prepend_timeout_command(
                self.transport_command
            )
            process = subprocess.Popen(
                self.transport_command,
                stdin=json_file,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            (stdout, stderr) = process.communicate()

        self.handle_transport_return_code(process.returncode, stdout, stderr)


class TransportFactory:
    @staticmethod
    def create_transport(
        destination: Destination, temp: tempfile.NamedTemporaryFile
    ) -> Transport:
        """
        Creates transport based on destination type.

        :param temp: temporary file for logs
        :param destination: destination object
        :return: transport object
        """
        if isinstance(destination, UrlDestination):
            return UrlTransport(destination, temp)
        elif isinstance(destination, S3JsonDestination):
            return S3JsonTransport(destination, temp)
        elif isinstance(destination, S3Destination):
            return S3Transport(destination, temp)
        elif isinstance(destination, UrlJsonDestination):
            return UrlJsonTransport(destination, temp)
        elif isinstance(destination, Destination):
            return SshTransport(destination, temp)
        else:
            raise ValueError(
                f"Unsupported destination type: {type(destination).__name__}"
            )


def send(
    service_name: str,
    facility_name: str,
    destination: str,
    destination_type: str = None,
    opts=None,
) -> None:
    """
    Sends data to destination.

    :param service_name: service name
    :param facility_name: facility name
    :param destination: destination
    :param destination_type: destination type (optional, defaults to Host destination type)
    :param opts: additional options (optional)
    """
    if opts is None:
        opts = []

    destination = DestinationFactory.create_destination(
        destination, service_name, facility_name, destination_type
    )

    with tempfile.NamedTemporaryFile(mode="w+") as temp:
        transport = TransportFactory.create_transport(destination, temp)
        transport.prepare_transport(opts)
        transport.send()


def check_input_fields(
    args: list[str],
    destination_type_required: bool = False,
    generic_script: bool = False,
) -> None:
    """
    Checks input script parameters are present (facility name, destination, (optional) destination type).
    Dies if parameters mismatch.
    :param generic_script: True if calling script is generic (and includes the service name argument)
    :param destination_type_required: True if destination type is required, default is False
    :param args: parameters passed to script (sys.argv)
    """

    if generic_script:
        if len(args) != 5:
            # Destination type gets passed by the engine every time so this shouldn't be an issue
            SysOperation.die_with_error(
                "Error: Expected number of arguments is 4 (FACILITY_NAME, DESTINATION, DESTINATION_TYPE"
                " and SERVICE_NAME)"
            )
    elif len(args) != 4:
        if destination_type_required:
            SysOperation.die_with_error(
                "Error: Expected number of arguments is 3 (FACILITY_NAME, DESTINATION and DESTINATION_TYPE)"
            )
        elif len(args) != 3:
            SysOperation.die_with_error(
                "Error: Expected number of arguments is 2 or 3 (FACILITY_NAME, DESTINATION and optional DESTINATION_TYPE)"
            )


if __name__ == "__main__":
    check_input_fields(sys.argv)
    service_name = SysOperation.get_global_service_name()
    if len(sys.argv) == 3:
        send(service_name, sys.argv[1], sys.argv[2])
    elif len(sys.argv) == 4:
        send(service_name, sys.argv[1], sys.argv[2], sys.argv[3])
    else:
        # shouldn't happen since we check input params at start
        SysOperation.die_with_error("Wrong number of input parameters")


#############################################################################################################################
# Here are some functions only included for compability - so the script has the same API as the old one.
# These are just copies of the old functions - they are not used in the script.
#############################################################################################################################

# predefined different types of destination
DESTINATION_TYPE_URL = "url"
DESTINATION_TYPE_HOST = "host"
DESTINATION_TYPE_USER_HOST = "user@host"
DESTINATION_TYPE_USER_HOST_PORT = "user@host:port"
DESTINATION_TYPE_USER_HOST_WINDOWS = "user@host-windows"
DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY = "host-windows-proxy"
DESTINATION_TYPE_SERVICE_SPECIFIC = "service-specific"


# regex checks
HOST_PATTERN = re.compile(
    r"^(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)$|^(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25["
    r"0-5]|2[0-4]\d|[0-1]?\d?\d)){3}$"
)
USER_AT_HOST_PATTERN = re.compile(
    r"^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@(?:(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)["
    r"a-z0-9-]+\.?)$|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}$)"
)
USER_AT_HOST_PORT_PATTERN = re.compile(
    r"^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@(?:(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)["
    r"a-z0-9-]+\.?)|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}):[0-9]+"
)
URL_PATTERN = re.compile(
    r"^(https?|ftp|file)://[-a-zA-Z0-9+&@#/%?=~_|!:,.;()*$']*[-a-zA-Z0-9+&@#/%=~_|()*$']"
)
SIMPLE_PATTERN = re.compile(r"\w+")


def check_destination_format(
    destination: str, destination_type: str, custom_pattern: re.Pattern = None
) -> None:
    """
    Checks destination format. Dies if format mismatches.
    :param destination:
    :param destination_type:
    :param custom_pattern: use only for service-specific type.
    """
    if custom_pattern is not None:
        if not (re.fullmatch(custom_pattern, destination)):
            SysOperation.die_with_error(
                "Destination '" + destination + "' is not in a valid format"
            )
    elif destination_type == DESTINATION_TYPE_HOST:
        if not (re.fullmatch(HOST_PATTERN, destination)):
            SysOperation.die_with_error(
                "Destination '"
                + destination
                + "' is not in a valid format for hostname"
            )
    elif destination_type == DESTINATION_TYPE_USER_HOST:
        if not (re.fullmatch(USER_AT_HOST_PATTERN, destination)):
            SysOperation.die_with_error(
                "Destination '" + destination + "' is not in valid format user@host"
            )
    elif destination_type == DESTINATION_TYPE_USER_HOST_PORT:
        if not (re.fullmatch(USER_AT_HOST_PORT_PATTERN, destination)):
            SysOperation.die_with_error(
                "Destination '"
                + destination
                + "' is not in valid format user@host:port"
            )
    elif destination_type == DESTINATION_TYPE_URL:
        if not (re.fullmatch(URL_PATTERN, destination)):
            SysOperation.die_with_error(
                "Destination '" + destination + "' is not in valid URL format"
            )
    elif destination_type in (
        DESTINATION_TYPE_USER_HOST_WINDOWS,
        DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY,
    ):
        if not (re.fullmatch(USER_AT_HOST_PATTERN, destination)):
            SysOperation.die_with_error(
                "Destination '" + destination + "' is not in valid format user@host"
            )
    elif destination_type == DESTINATION_TYPE_SERVICE_SPECIFIC:
        pass
    else:
        print("Unknown destination type " + destination_type + ".", file=sys.stderr)
        exit(1)


def check_destination_type_allowed(destination_type: str, allowed_destination):
    """
    Use this method to check destination type matches the only one allowed.
    Terminates if mismatches.
    :param destination_type: requested destination type
    :param allowed_destination: allowed destination type
    """
    if destination_type != allowed_destination:
        SysOperation.die_with_error(
            "Not allowed destination type '"
            + destination_type
            + "', only destination type allowed is '"
            + allowed_destination
            + "'"
        )
