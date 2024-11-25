import re
import subprocess

from sys_operation_classes import SysOperation


class Destination:
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
    S3_PATTERN = re.compile(
        r"^(https?://[-a-zA-Z0-9+&@#/%?=~_|!:,.;()*$']+)/([-a-zA-Z0-9+&@#%?=~_|!:,.;()*$'']+)$"
    )
    URL_JSON_PATTERN = URL_PATTERN

    def __init__(self, destination: str, service_name: str, facility_name: str):
        self.destination = destination
        self.service_name = service_name
        self.facility_name = facility_name
        self.port = None

    def check_destination_format(
        self, destination: str = None, custom_error_message: str = None
    ):
        """
        Checks destination format. Dies if format mismatches.

        :param destination: optional param, if not set, self.destination is used
        :param custom_error_message: optional param, basicly useful only if custom destination is set
        """
        if not destination:
            destination = self.destination
        if not (re.fullmatch(self.check_destination_pattern, destination)):
            SysOperation.die_with_error(
                custom_error_message
                or "Destination '"
                + destination
                + "' is not in a valid format for hostname"
            )

    def prepare_destination(self):
        """
        Sets instance params host, hostname and port.
        """
        raise NotImplementedError

    def process_data(self, process_tar):
        """
        Transforms data for format of given destination.
        Make sure to correctly terminate the returned subprocess!

        :param process_tar: process object with data to be transformed
        :return: process object with transformed data
        """
        transformation_process = subprocess.Popen(
            "cat", stdin=process_tar.stdout, stdout=subprocess.PIPE
        )
        return transformation_process


class HostDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.HOST_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        self.hostname = self.destination
        self.host = "root@" + self.destination


class UserHostDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.USER_AT_HOST_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        self.hostname = self.destination.split("@")[1]
        self.host = self.destination


class UserHostPortDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.USER_AT_HOST_PORT_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        self.host = self.destination.split(":")[0]
        self.hostname = self.host.split("@")[1]
        self.port = self.destination.split(":")[1]


class UrlDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.URL_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        self.host = self.destination
        self.hostname = self.destination


class WindowsDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.USER_AT_HOST_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        self.host = self.destination
        self.hostname = self.host.split("@")[1]

    def process_data(self, process_tar):
        # converts stdin to base64
        transformation_process = subprocess.Popen(
            "base64", stdin=process_tar.stdout, stdout=subprocess.PIPE
        )
        return transformation_process


class WindowsProxyDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.USER_AT_HOST_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        windows_proxy = SysOperation.get_windows_proxy()
        self.check_destination_format(
            windows_proxy,
            "Value of WINDOWS_PROXY '"
            + windows_proxy
            + "' is not in valid format user@host",
        )
        self.destination, windows_proxy = windows_proxy, self.destination
        self.host = self.windows_proxy  # propagate on proxy instead of destination
        self.hostname = self.destination.split("@")[
            1
        ]  # hostname file content from original destination

    def process_data(self, process_tar):
        # converts stdin to base64 and append single space and "$DESTINATION" at the end of it
        transformation_process_1 = subprocess.Popen(
            "base64", stdin=process_tar.stdout, stdout=subprocess.PIPE
        )
        sed_command = ["sed", "-e", "$s/$/ " + self.destination + "/g"]
        transformation_process = subprocess.Popen(
            sed_command, stdin=transformation_process_1.stdout, stdout=subprocess.PIPE
        )
        # this MIGHT be insufficient to correctly close the process (however no instances of base64 zombie processes
        # were reported)
        transformation_process_1.stdout.close()
        return transformation_process


class EmailDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.EMAIL_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        pass


class ServiceSpecificDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = None
        self.check_destination_format()
        self.prepare_destination()

    def check_destination_format(self):
        pass

    def prepare_destination(self):
        pass


class S3Destination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.S3_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        match = Destination.S3_PATTERN.match(self.destination)
        self.host = self.destination
        self.endpoint = match.group(1)
        self.hostname = match.group(2)


class UrlJsonDestination(Destination):
    def __init__(self, destination: str, service_name: str, facility_name: str):
        if service_name != "generic_json_gen":
            raise ValueError(
                "UrlJsonTransport only supports 'generic_json_gen' service."
            )
        super().__init__(destination, service_name, facility_name)
        self.check_destination_pattern = Destination.URL_JSON_PATTERN
        self.check_destination_format()
        self.prepare_destination()

    def prepare_destination(self):
        self.host = self.destination
        self.hostname = self.destination


class DestinationFactory:
    DESTINATION_TYPE_URL = "url"
    DESTINATION_TYPE_EMAIL = "email"
    DESTINATION_TYPE_HOST = "host"
    DESTINATION_TYPE_USER_HOST = "user@host"
    DESTINATION_TYPE_USER_HOST_PORT = "user@host:port"
    DESTINATION_TYPE_USER_HOST_WINDOWS = "user@host-windows"
    DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY = "host-windows-proxy"
    DESTINATION_TYPE_SERVICE_SPECIFIC = "service-specific"
    DESTINATION_TYPE_S3 = "s3"
    DESTINATION_TYPE_URL_JSON = "url-json"

    @staticmethod
    def create_destination(
        destination: str,
        service_name: str,
        facility_name: str,
        destination_type: str = DESTINATION_TYPE_HOST,
    ) -> Destination:
        """
        Creates destination object based on destination type

        :param destination_type: destination type
        :return: destination object
        """
        if destination_type == DestinationFactory.DESTINATION_TYPE_URL:
            return UrlDestination(destination, service_name, facility_name)
        elif destination_type == DestinationFactory.DESTINATION_TYPE_HOST:
            return HostDestination(destination, service_name, facility_name)
        elif destination_type == DestinationFactory.DESTINATION_TYPE_USER_HOST:
            return UserHostDestination(destination, service_name, facility_name)
        elif destination_type == DestinationFactory.DESTINATION_TYPE_USER_HOST_PORT:
            return UserHostPortDestination(destination, service_name, facility_name)
        elif destination_type == DestinationFactory.DESTINATION_TYPE_USER_HOST_WINDOWS:
            return WindowsDestination(destination, service_name, facility_name)
        elif destination_type == DestinationFactory.DESTINATION_TYPE_S3:
            return S3Destination(destination, service_name, facility_name)
        elif destination_type == DestinationFactory.DESTINATION_TYPE_URL_JSON:
            return UrlJsonDestination(destination, service_name, facility_name)
        elif (
            destination_type
            == DestinationFactory.DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY
        ):
            return WindowsProxyDestination(destination, service_name, facility_name)
        elif (
            destination_type == DestinationFactory.DESTINATION_TYPE_EMAIL
            or destination_type == DestinationFactory.DESTINATION_TYPE_SERVICE_SPECIFIC
        ):
            SysOperation.die_with_error(
                f"Destination type {destination_type} is not supported yet."
            )
        else:
            raise ValueError(f"Unknown destination type {destination_type}")
