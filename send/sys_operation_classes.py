import datetime
import importlib
import os
import sys
import tarfile
import tempfile
from importlib import import_module
from typing import Optional


class SysOperation:
    MAIN_LOCK_DIR = "/var/lock"
    TEMPORARY_DIR = "/tmp"
    SERVICES_DIR = "/etc/perun/services"
    LOG_DIR = "/var/log/perun/spool_tmp"

    @staticmethod
    def die_with_error(message: str, code: int = 1) -> None:
        """
        Print message to standard error output and terminate script.
        :param message:
        :param code: return code, 1 if not set otherwise
        """
        print(message, file=sys.stderr)
        exit(code)

    @staticmethod
    def get_global_service_name() -> str:
        """
        Gets service name from environment variable SERVICE_NAME.
        Usable when script is called by other script which set this variable.
        Terminates if not exist.
        :return: service name
        """
        service_name = os.getenv("SERVICE_NAME")
        if service_name is None:
            SysOperation.die_with_error(
                "Error: SERVICE_NAME environment variable is not set"
            )
        return service_name

    @staticmethod
    def load_custom_transport_command(service_name: str) -> Optional[list[str]]:
        """
        Retrieves custom transport command from config file located in service directory.
        Config file must end with .py -> "/etc/perun/services/service_name/service_name.py")
        Transport command must be list of strings, so it is possible to append to it later in the scripts.
        :param service_name:
        :return: transport command or null if not resolved
        """
        try:
            sys.path.insert(1, os.path.join(SysOperation.SERVICES_DIR, service_name))
            return import_module(service_name).transport_command
        except Exception:
            # this means that config file does not exist or property is not set
            return None

    # @staticmethod
    # def get_temporary_file() -> tempfile.NamedTemporaryFile:
    #     """
    #     Returns temporary file.
    #     :return: temporary file
    #     """
    #     return tempfile.NamedTemporaryFile(mode="w+")

    @staticmethod
    def get_auth_credentials_from_service_file(service_name: str, destination: str):
        """
        Retrieves credentials from a file located in the /etc/perun/services/{service_name}/{service_name}.py file.
        The file is a python file containing map of {destination: {'username': username, 'password': password}} mapping.

        Example of such file - supplement $ variables with destination url, username and password
        credentials = {
                        "$url1": { 'username': "$user1", 'password': "$pwd1" },
                        "$url2": { 'username': "$user2", 'password': "$pwd2" }
        }

        :param service_name: name of the service (used both as the folder name and the credentials python file name)
        :param destination: key used to search in the credentials map
        :return: (username, password) if credentials retrieved, None otherwise
        """
        auth = None

        try:
            sys.path.insert(1, f"{SysOperation.SERVICES_DIR}/{service_name}/")
            credentials = import_module(service_name).credentials
            if destination in credentials:
                username = credentials.get(destination).get("username")
                password = credentials.get(destination).get("password")
                auth = (username, password)
        except Exception:
            # this means that config file does not exist or properties are not set
            pass
        return auth

    @staticmethod
    def get_windows_proxy() -> str:
        """
        Retrieves windows proxy in order:
                        1. defined in generic send config
                        2. environment variable
                        3. None
        :return: windows proxy or None if not resolved
        """
        windows_proxy = None
        try:
            # load variable windows_proxy from generic_send configuration
            sys.path.insert(1, os.path.join(SysOperation.SERVICES_DIR, "generic_send"))
            windows_proxy = import_module("generic_send_conf").windows_proxy
        except ImportError:
            # this means that config file does not exist
            pass
        if windows_proxy is None:
            windows_proxy = os.getenv("WINDOWS_PROXY")
        return windows_proxy

    @staticmethod
    def get_temp_dir():
        return tempfile.TemporaryDirectory(
            prefix="perun-send.", dir=SysOperation.TEMPORARY_DIR
        )

    @staticmethod
    def get_gen_folder(facility_name: str, service_name: str):
        """
        Returns path to gen folder from current send folder. Checks it is a directory, dies otherwise.
        :param facility_name:
        :param service_name:
        :return: path to gen folder
        """
        service_files_base_dir = (
            os.path.dirname(os.path.realpath(sys.argv[0])) + "/../gen/spool"
        )  # don't rely on pwd
        service_files_dir = (
            service_files_base_dir + "/" + facility_name + "/" + service_name
        )

        if not os.path.isdir(service_files_dir):
            SysOperation.die_with_error(
                "SERVICE_FILES_DIR: " + service_files_dir + " is not a directory"
            )

        return service_files_dir

    @staticmethod
    def persist_spool_files(
        facility_name: str, service_name: str, directories: list[str]
    ):
        """
        Persists spool files recursively as archive in the log folder
        :param facility_name: name of the facility
        :param service_name: name of the service
        :param directories: directories to include in the archive
        """
        # temporary way to locally disable logging -> manually pass -1 as task run id to the send script
        # ideally change when send scripts can take named parameters
        task_run_id = SysOperation.get_run_id(
            SysOperation.get_gen_folder(facility_name, service_name) + "/RUN_ID"
        )
        if int(task_run_id) == -1:
            return
        archive_enabled = SysOperation.is_archive_enabled()
        if archive_enabled:
            archive_spool_folder = (
                f"{SysOperation.LOG_DIR}/{facility_name}/{service_name}"
            )
            if not os.path.exists(archive_spool_folder):
                os.makedirs(archive_spool_folder)
            timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
            archive_name = f"spooldata_{task_run_id}_{timestamp}"
            SysOperation.archive_files(archive_spool_folder, archive_name, directories)

    @staticmethod
    def get_run_id(run_id_filepath: str) -> int:
        """
        Retrieves run id from the passed filepath. Checks whether file exists and extracts the id
        :param run_id_filepath: filepath
        :return: run id
        """
        if not os.path.exists(run_id_filepath):
            return -1
        with open(run_id_filepath) as run_id_file:
            run_id = int(run_id_file.readline())
        return run_id

    @staticmethod
    def is_archive_enabled() -> bool:
        service_files_base_dir = (
            os.path.dirname(os.path.realpath(sys.argv[0])) + "/../gen/spool"
        )
        archive_file_path = service_files_base_dir + "/ARCHIVE"
        if not os.path.exists(archive_file_path):
            return False
        with open(archive_file_path) as archive_file:
            archive_enabled = int(archive_file.readline())
        return bool(archive_enabled)

    @staticmethod
    def archive_files(path: str, archive_name: str, directories: list[str]):
        """
        Creates archive of content of directories (recursively) in the filepath
        :param path: target directory to save archive to
        :param archive_name: archive name
        :param directories: directories to merge and archive
        """
        with tarfile.open(
            path + f"/{archive_name}.tar.gz", "w:gz", format=tarfile.GNU_FORMAT
        ) as archive:
            for directory in directories:
                archive.add(directory, arcname=".")

    @staticmethod
    def prepare_tar_command(
        tar_mode: str, hostname_dir: str, service_files_dir: str, destination: str
    ) -> list[str]:
        """
        Prepares command for extracting generated service files and hostname.
        Default tar mode can be obtained for destination type.
        If available, adds destination specific directory.
        :param tar_mode:
        :param hostname_dir: directory containing HOSTNAME file
        :param service_files_dir: generated service data directory
        :param destination:
        :return: completed tar command
        """
        tar_command = ["tar", tar_mode]
        tar_command.extend(["-C", hostname_dir, "."])
        tar_command.extend(["-C", service_files_dir, "--exclude=_destination", "."])

        # FIXME - works only for destinations type "host" or do we generate folders like "user@host" for that type?
        # determine DIR with special configuration for destination (this dir may not exist)
        # ==IT MUST BE ABSOLUTE PATH (because of double -C in tar command)==
        service_files_for_destination = (
            service_files_dir + "/_destination/" + destination
        )
        # if there is no specific data for destination, use "all" destination
        if not os.path.isdir(service_files_for_destination):
            service_files_for_destination = service_files_dir + "/_destination/all"

        if os.path.isdir(service_files_for_destination):
            tar_command.extend(["-C", service_files_for_destination, "."])

        return tar_command

    @staticmethod
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
            sys.path.insert(1, f"{SysOperation.SERVICES_DIR}/{service_name}/")
            credentials = importlib.import_module(service_name).credentials
            result = []
            if destination in credentials:
                for p in properties:
                    result.append(credentials.get(destination).get(p))

            return result
        except Exception:
            # this means that config file does not exist or properties are not set
            return None

    @staticmethod
    def get_generated_json_file_path(facility_name: str, service_name: str) -> str:
        """
        Returns absolute path to a single json file generated by the service for given facility.
        Raises a FileNotFoundError if there is no json file or more than one.

        :param facility_name: name of the facility
        :param service_name: name of the service
        :return: absolute path to the generated json
        """
        generated_files_dir = SysOperation.get_gen_folder(facility_name, service_name)

        json_files = [f for f in os.listdir(generated_files_dir) if f.endswith(".json")]
        if len(json_files) != 1:
            raise FileNotFoundError(
                "Expected one generated JSON file, found " + str(len(json_files))
            )

        json_file_path = os.path.join(generated_files_dir, json_files[0])
        return json_file_path
