import os
import re
import subprocess
import sys
import tempfile

from destination_classes import Destination, DestinationFactory, UrlDestination
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
        :param transport_command:
        :param destination:
        :param destination_type:
        :return: (returncode, stdout, stderr)
        """
        process_tar = subprocess.Popen(tar_command, stdout=subprocess.PIPE)
        transformation_process = self.destination_class_obj.process_data(process_tar)
        process_tar.stdout.close()

        the_process = subprocess.Popen(
            self.transport_command,
            stdin=transformation_process.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        transformation_process.stdout.close()
        (stdout, stderr) = the_process.communicate()
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

    def send(self):
        """
        The actual sending is done here.
        handle_transport_return_code must be implemented for this.
        """
        with (
            SysOperation.get_temp_dir() as hostname_dir,
            open(os.path.join(hostname_dir, "HOSTNAME"), mode="w+") as hostfile,
        ):
            # prepare hostfile

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
            tar_command = SysOperation.prepare_tar_command(
                self.tar_mode,
                hostname_dir,
                generated_files_dir,
                self.destination_class_obj.destination,
            )
            # prepend timeout command
            timeout_command = [
                "timeout",
                "-k",
                str(Transport.TIMEOUT_KILL),
                str(Transport.TIMEOUT),
            ]
            timeout_command.extend(self.transport_command)
            self.transport_command = timeout_command

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
        :param content_type: for example 'application/json'
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
            if int(stdout) not in self.http_ok_codes:
                # check if HTTP_CODE is different from OK
                # if yes, then we will use HTTP_CODE as ERROR_CODE which is always non-zero
                self.temp.seek(0, 0)
                print(self.temp.read(), file=sys.stderr)
            else:
                # if HTTP_CODE is OK, then call was successful and result call can be printed with info
                # result call is saved in temp file
                self.temp.seek(0, 0)
                print(self.temp.read())
                exit(0)


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

SERVICES_DIR = "/etc/perun/services"
# predefined different types of destination
DESTINATION_TYPE_URL = "url"
DESTINATION_TYPE_EMAIL = "email"
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
EMAIL_PATTERN = re.compile(
    r"([A-Za-z0-9]+[.-_])*[A-Za-z0-9]+@[A-Za-z0-9-]+(\.[A-Z|a-z]{2,})+"
)
SIMPLE_PATTERN = re.compile(r"\w+")


def get_custom_config_properties(
    service_name: str, destination: str, properties: list[str]
):
    """
    Retrieves custom properties from config file in /etc/perun/services/{service_name}/{service_name}.py file.

    Example of such file - supplement $ variables with destination, property names and values
    credentials = {
                    "$url1": { '$property_1': "$our_token", '$property_2': "$our_secret" },
                    "$url2": { '$property_1': "$our_other_token", '$property_2': "$our_other_secret" }
    }

    :param service_name: name of the service
        (used both as the folder name and the credentials python file name)
    :param destination: key used to search in the credentials map
    :param properties: list of properties to be retrieved
    :return: list of values in the same order as provided properties,
                             None if file does not exist or any property is missing
    """
    try:
        sys.path.insert(1, f"{SERVICES_DIR}/{service_name}/")
        credentials = __import__(service_name).credentials
        result = []
        if destination in credentials:
            for p in properties:
                result.append(credentials.get(destination).get(p))
        return result
    except Exception:
        # this means that config file does not exist or properties are not set
        return None


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
    elif destination_type == DESTINATION_TYPE_EMAIL:
        if not (re.fullmatch(EMAIL_PATTERN, destination)):
            SysOperation.die_with_error(
                "Destination '" + destination + "'  is not in a valid format for email"
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
