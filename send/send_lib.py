import fcntl
import subprocess
import sys
import re
import os
import tempfile
import shutil
from typing import Optional

PERUN_CERT = "/etc/perun/ssl/perun-send.pem"
PERUN_KEY = "/etc/perun/ssl/perun-send.key"
PERUN_CHAIN = "/etc/perun/ssl/perun-send.chain"
MAIN_LOCK_DIR = "/var/lock"
TEMPORARY_DIR = "/tmp"
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

TIMEOUT = 7200  # 120 * 60 sec = 2h
TIMEOUT_KILL = 60  # 60 sec to kill after timeout

http_ok_codes = [200, 201, 202, 203, 204]

# regex checks
HOST_PATTERN = re.compile(
	"^(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)$|^(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}$")
USER_AT_HOST_PATTERN = re.compile(
	"^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@(?:(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)$|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}$)")
USER_AT_HOST_PORT_PATTERN = re.compile(
	"^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@(?:(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}):[0-9]+")
URL_PATTERN = re.compile("^(https?|ftp|file)://[-a-zA-Z0-9+&@#/%?=~_|!:,.;()*$']*[-a-zA-Z0-9+&@#/%=~_|()*$']")
EMAIL_PATTERN = re.compile(r'([A-Za-z0-9]+[.-_])*[A-Za-z0-9]+@[A-Za-z0-9-]+(\.[A-Z|a-z]{2,})+')
SIMPLE_PATTERN = re.compile(r'\w+')


class FileLock(object):
	"""
	Object for ensuring a single process of service/destination provisioning is running.
	Creates locked file, lock is removed when script exits (if not used as context manager).
	If another process locked the file, this process will terminate immediately when trying to create lock.
	"""

	def __init__(self, lockfile):
		self.lockfile = lockfile
		self.dir_fd = os.open(self.lockfile, os.O_CREAT | os.O_RDWR)
		try:
			fcntl.flock(self.dir_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
		except IOError as ex:
			die_with_error('Unable to get lock, service propagation was already running.')

	def __enter__(self):
		return self

	def __exit__(self, exc_type, exc_val, exc_tb):
		# the file itself should probably not be removed (https://unix.stackexchange.com/a/368167)
		fcntl.flock(self.dir_fd, fcntl.LOCK_UN)
		os.close(self.dir_fd)


def check_input_fields(args: list[str], destination_type_required: bool = False) -> None:
	"""
	Checks input script parameters are present (facility name, destination, (optional) destination type).
	Dies if parameters mismatch.
	:param destination_type_required: True if destination type is required, default is False
	:param args: parameters passed to script (sys.argv)
	"""
	if len(args) != 4:
		if destination_type_required:
			die_with_error("Error: Expected number of arguments is 3 (FACILITY_NAME, DESTINATION and DESTINATION_TYPE)")
		elif len(args) != 3:
			die_with_error(
				"Error: Expected number of arguments is 2 or 3 (FACILITY_NAME, DESTINATION and optional DESTINATION_TYPE)")


def check_destination_format(destination: str, destination_type: str, custom_pattern: re.Pattern = None) -> None:
	"""
	Checks destination format. Dies if format mismatches.
	:param destination:
	:param destination_type:
	:param custom_pattern: use only for service-specific type.
	"""
	if custom_pattern is not None:
		if not (re.fullmatch(custom_pattern, destination)):
			die_with_error("Destination '" + destination + "' is not in a valid format")
	elif destination_type == DESTINATION_TYPE_HOST:
		if not (re.fullmatch(HOST_PATTERN, destination)):
			die_with_error("Destination '" + destination + "' is not in a valid format for hostname")
	elif destination_type == DESTINATION_TYPE_USER_HOST:
		if not (re.fullmatch(USER_AT_HOST_PATTERN, destination)):
			die_with_error("Destination '" + destination + "' is not in valid format user@host")
	elif destination_type == DESTINATION_TYPE_USER_HOST_PORT:
		if not (re.fullmatch(USER_AT_HOST_PORT_PATTERN, destination)):
			die_with_error("Destination '" + destination + "' is not in valid format user@host:port")
	elif destination_type == DESTINATION_TYPE_URL:
		if not (re.fullmatch(URL_PATTERN, destination)):
			die_with_error("Destination '" + destination + "' is not in valid URL format")
	elif destination_type == DESTINATION_TYPE_USER_HOST_WINDOWS:
		if not (re.fullmatch(USER_AT_HOST_PATTERN, destination)):
			die_with_error("Destination '" + destination + "' is not in valid format user@host")
	elif destination_type == DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY:
		if not (re.fullmatch(USER_AT_HOST_PATTERN, destination)):
			die_with_error("Destination '" + destination + "' is not in valid format user@host")
	elif destination_type == DESTINATION_TYPE_EMAIL:
		if not (re.fullmatch(EMAIL_PATTERN, destination)):
			die_with_error("Destination '" + destination + "'  is not in a valid format for email")
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
		die_with_error("Not allowed destination type '" + destination_type +
					   "', only destination type allowed is '" + allowed_destination + "'")


def check_windows_proxy_format(windows_proxy: str) -> None:
	"""
	Checks format of windows proxy. Dies if format mismatches.
	:param windows_proxy: defined in a configuration
	"""
	if windows_proxy is None:
		die_with_error(
			'Variable WINDOWS_PROXY is not defined. It is usually defined in /etc/perun/services/generic_send/generic_send.conf.')
	if not (re.fullmatch(USER_AT_HOST_PATTERN, windows_proxy)):
		die_with_error("Value of WINDOWS_PROXY '" + windows_proxy + "' is not in valid format user@host")


def prepare_temporary_directory() -> tempfile.TemporaryDirectory:
	"""
	Prepares temporary directory `/tmp/perun-send.{generated name}`.
	Use with context manager:
		with send_lib.prepareTemporaryDirectory() as tmpdir:
	so it is removed afterwards with all its content.
	:return: created temporary directory
	"""
	return tempfile.TemporaryDirectory(prefix="perun-send.", dir=TEMPORARY_DIR)


def copy_files_to_directory(path_from: str, path_to: str, name_pattern: re.Pattern = None) -> None:
	"""
	Copy file(s) to another directory. Copies all files, if file_pattern not specified.
	Does not recursively copy subdirectory files.
	Use name_pattern to specify exact name of file or possible suffixes with given regex.
	:param path_from:
	:param path_to:
	:param name_pattern:	examples:
							r"(?:json|txt|scim)$"      -- files with these suffixes
							r'^(some-regex-here)$'     -- full filename match
	"""
	if name_pattern is None:
		name_pattern = re.compile(".*")  # match anything
	for filename in os.listdir(path_from):
		f = os.path.join(path_from, filename)
		if os.path.isfile(f) and name_pattern.match(filename):
			try:
				shutil.copy(f, path_to)
			except IOError as e:
				die_with_error("Cannot copy to " + path_to, 254)


def check_script_file(script_filepath: str) -> None:
	"""
	Checks if script file exists and is executable.
	:param script_filepath:
	"""
	if not os.access(script_filepath, os.X_OK):
		die_with_error("Can't locate or execute script file!", 253)


def get_global_service_name() -> str:
	"""
	Gets service name from environment variable SERVICE_NAME.
	Usable when script is called by other script which set this variable.
	Terminates if not exist.
	:return: service name
	"""
	service_name = os.getenv('SERVICE_NAME')
	if service_name is None:
		die_with_error("Error: SERVICE_NAME environment variable is not set")
	return service_name


def prepare_destination(destination: str, destination_type: str) -> list[str]:
	"""
	Returns host, hostname {, port} parameters from destination
	:param destination:
	:param destination_type:
	:return: list of [host, hostname {,port}]
	"""
	port = None
	if destination_type == DESTINATION_TYPE_HOST:
		hostname = destination
		host = "root@" + destination
	elif destination_type == DESTINATION_TYPE_USER_HOST:
		hostname = destination.split("@")[1]
		host = destination
	elif destination_type == DESTINATION_TYPE_USER_HOST_PORT:
		host = destination.split(":")[0]
		hostname = host.split("@")[1]
		port = destination.split(":")[1]
	elif destination_type == DESTINATION_TYPE_URL:
		host = destination
		hostname = destination
	elif destination_type == DESTINATION_TYPE_USER_HOST_WINDOWS:
		host = destination
		hostname = host.split("@")[1]
	elif destination_type == DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY:
		windows_proxy = get_windows_proxy()
		check_windows_proxy_format(windows_proxy)
		host = windows_proxy  # propagate on proxy instead of destination
		hostname = destination.split("@")[1]  # hostname file content from original destination
	else:
		die_with_error("Unknown destination type " + destination_type + ".")
	return [host, hostname, port]


def get_gen_folder(facility_name: str, service_name: str):
	"""
	Returns path to gen folder from current send folder. Checks it is a directory, dies otherwise.
	:param facility_name:
	:param service_name:
	:return: path to gen folder
	"""
	service_files_base_dir = os.path.dirname(os.path.realpath(sys.argv[0])) + "/../gen/spool"  # don't rely on pwd
	service_files_dir = service_files_base_dir + "/" + facility_name + "/" + service_name

	if not os.path.isdir(service_files_dir):
		die_with_error("SERVICE_FILES_DIR: " + service_files_dir + " is not a directory")

	return service_files_dir


def create_lock(service_name: str, destination: str, custom_lock_dir: str = None) -> FileLock:
	"""
	Creates lock "perun-service_name-destination.lock" file. If not specified otherwise, predefined directory is used.
	If lock already exists on the file, current script will terminate.
	:param destination:
	:param service_name:
	:param custom_lock_dir:
	:return: created lock file
	"""
	if custom_lock_dir is not None:
		lock_dir = custom_lock_dir
		if not os.access(custom_lock_dir, os.W_OK):
			die_with_error("LOCK_DIR: " + custom_lock_dir + " is not a directory")
	else:
		lock_dir = MAIN_LOCK_DIR
		if not os.access(MAIN_LOCK_DIR, os.W_OK):
			lock_dir = TEMPORARY_DIR

	if destination is not None:
		lockfile = "perun-{}-{}.lock".format(service_name, escape_filename(destination))
	else:
		lockfile = "perun-{}.lock".format(service_name)
	lockfile = os.path.join(lock_dir, lockfile)
	return FileLock(lockfile)


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
		sys.path.insert(1, os.path.join(SERVICES_DIR, "generic_send"))
		windows_proxy = __import__("generic_send_conf").windows_proxy
	except ImportError:
		# this means that config file does not exist
		pass
	if windows_proxy is None:
		windows_proxy = os.getenv("WINDOWS_PROXY")
	return windows_proxy


def load_custom_transport_command(service_name: str) -> Optional[list[str]]:
	"""
	Retrieves custom transport command from config file located in service directory.
	Config file must end with .py -> "/etc/perun/services/service_name/service_name.py")
	Transport command must be list of strings, so it is possible to append to it later in the scripts.
	:param service_name:
	:return: transport command or null if not resolved
	"""
	try:
		sys.path.insert(1, os.path.join(SERVICES_DIR, service_name))
		return __import__(service_name).transport_command
	except Exception:
		# this means that config file does not exist or property is not set
		return None


def die_with_error(message: str, code: int = 1) -> None:
	"""
	Print message to standard error output and terminate script.
	:param message:
	:param code: return code, 1 if not set otherwise
	"""
	print(message, file=sys.stderr)
	exit(code)


def exec_script(script_path: str, arguments: list[str]):
	"""
	Checks script is executable and executes it with passed parameters
	:param script_path: path to script file
	:param arguments: parameters for the script (e.g. ["-d", "my_destination", "-s", "my_servicename"])
	:return: process running the script
	"""
	check_script_file(script_path)
	command = [script_path]
	command.extend(arguments)
	return subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def escape_filename(filename: str) -> str:
	"""
	Checks if provided filename contains any forbidden characters and escapes them.

	:param filename: filename to escape
	:return: escaped filename
	"""
	return filename.replace('/', '⧸')  # replace classic slash with U+29F8


def get_auth_credentials(service_name: str, destination: str):
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
		sys.path.insert(1, f'{SERVICES_DIR}/{service_name}/')
		credentials = __import__(service_name).credentials
		if destination in credentials.keys():
			username = credentials.get(destination).get('username')
			password = credentials.get(destination).get('password')
			auth = (username, password)
	except Exception:
		# this means that config file does not exist or properties are not set
		pass
	return auth


def get_custom_config_properties(service_name: str, destination: str, properties: list[str]):
	"""
	Retrieves custom properties from config file in /etc/perun/services/{service_name}/{service_name}.py file.

	Example of such file - supplement $ variables with destination, property names and values
	credentials = {
		"$url1": { '$property_1': "$our_token", '$property_2': "$our_secret" },
		"$url2": { '$property_1': "$our_other_token", '$property_2': "$our_other_secret" }
	}

	:param service_name: name of the service (used both as the folder name and the credentials python file name)
	:param destination: key used to search in the credentials map
	:param properties: list of properties to be retrieved
	:return: list of values in the same order as provided properties, None if file does not exist or any property is missing
	"""
	try:
		sys.path.insert(1, f'{SERVICES_DIR}/{service_name}/')
		credentials = __import__(service_name).credentials
		result = []
		if destination in credentials.keys():
			for p in properties:
				result.append(credentials.get(destination).get(p))
		return result
	except Exception:
		# this means that config file does not exist or properties are not set
		return None
