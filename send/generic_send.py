import os
import subprocess
import sys
import tempfile
import re

timeout = "7200"  # 120 * 60 sec = 2h
timeout_kill = "60"  # 60 sec to kill after timeout

perun_cert = "/etc/perun/ssl/perun-send.pem"
perun_key = "/etc/perun/ssl/perun-send.key"
perun_chain = "/etc/perun/ssl/perun-send.chain"

# predefined different types of destination
destination_type_url = "url"
destination_type_email = "email"
destination_type_host = "host"
destination_type_user_host = "user@host"
destination_type_user_host_port = "user@host:port"
destination_type_user_host_windows = "user@host-windows"
destination_type_user_host_windows_proxy = "host-windows-proxy"

# regex checks
hostPattern = re.compile("^(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)$|^(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}$")
userAtHostPattern = re.compile("^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@(?:(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)$|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}$)")
userAtHostPortPattern = re.compile("^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@(?:(?!:\/\/)(?=.{1,255}$)((.{1,63}\.){1,127}(?![0-9]*$)[a-z0-9-]+\.?)|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}):[0-9]+")
urlPattern = re.compile("^(https?|ftp|file)://[-a-zA-Z0-9+&@#/%?=~_|!:,.;()*$']*[-a-zA-Z0-9+&@#/%=~_|()*$']")

if __name__ == "__main__":
	if len(sys.argv) != 4 and len(sys.argv) != 3:
		print("Error: Expected number of arguments is 2 or 3 (FACILITY_NAME, DESTINATION and optional DESTINATION_TYPE)", file=sys.stderr)
		exit(1)

	facility_name = sys.argv[1]
	destination = sys.argv[2]
	if len(sys.argv) == 3:
		# if there is no destination type, use default 'host'
		destination_type = destination_type_host
	else:
		destination_type = sys.argv[3]

	service_name = os.getenv('SERVICE_NAME')
	if service_name is None:
		print("Error: $SERVICE_NAME is not set", file=sys.stderr)
		exit(1)

	# choose transport command, only url type has different transport command at this moment
	if destination_type == destination_type_url:
		# FIXME - test this use-case
		transport_command = ["curl"]
		# add certificate to the curl if cert file and key file exists and they are readable
		if os.access(perun_cert, os.R_OK) and os.access(perun_key, os.R_OK) and os.access(perun_chain, os.R_OK):
			transport_command.extend(["--cert", perun_cert, "--key", perun_key, "--cacert", perun_chain])
		# add standard CURL params
		temp = tempfile.NamedTemporaryFile(mode="w+")
		transport_command.extend(["-i", "-H", "Content-Type:application/x-tar", "-w", "%{http_code}", "--show-error",
								  "--silent", "-o", temp.name, "-X", "PUT", "--data-binary", "@-"])
		# Append optional BA credentials to URL destinations from standardized config
		try:
			sys.path.insert(1, f'/etc/perun/services/' + service_name + '/')
			credentials = __import__(service_name).credentials
			if destination in credentials.keys():
				username = credentials.get(destination).get('username')
				password = credentials.get(destination).get('password')
				transport_command.extend(["-u", username + ":" + password])
		except Exception:
			# this means that config file does not exist or properties are not set
			pass
	else:
		transport_command = ["ssh", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o",
							 "GSSAPIAuthentication=no", "-o", "GSSAPIKeyExchange=no", "-o", "ConnectTimeout=5"]

	# override existing variable transport_command
	try:
		sys.path.insert(1, '/etc/perun/services/' + service_name + '/')
		transport_command = __import__(service_name).transport_command
	except ImportError:
		# this means that config file does not exist
		pass

	# load variable windows_proxy from generic_send configuration
	try:
		sys.path.insert(1, '/etc/perun/services/generic_send')
		windows_proxy = __import__("generic_send_conf").windows_proxy
	except ImportError:
		# this means that config file does not exist
		pass

	slave_command = "/opt/perun/bin/perun"
	service_files_base_dir = os.getcwd() + "/../gen/spool"
	service_files_dir = service_files_base_dir + "/" + facility_name + "/" + service_name

	# just safety check, this it should be a directory
	if not os.path.isdir(service_files_dir):
		print("$SERVICE_FILES_DIR: " + service_files_dir + " is not a directory", file=sys.stderr)
		exit(1)

	if destination_type == destination_type_host:
		if not (re.fullmatch(hostPattern, destination)):
			print("Destination '" + destination + "' is not in a valid format for hostname", file=sys.stderr)
			exit(1)
		hostname = destination
		host = "root@" + destination
	elif destination_type == destination_type_user_host:
		if not (re.fullmatch(userAtHostPattern, destination)):
			print("Destination '" + destination + "' is not in valid format user@host", file=sys.stderr)
			exit(1)
		hostname = destination.split("@")[1]
		host = destination
	elif destination_type == destination_type_user_host_port:
		if not (re.fullmatch(userAtHostPortPattern, destination)):
			print("Destination '" + destination + "' is not in valid format user@host:port", file=sys.stderr)
			exit(1)
		host = destination.split(":")[0]
		hostname = host.split("@")[1]
		port = destination.split(":")[1]
		transport_command.extend(["-p", port])
	elif destination_type == destination_type_url:
		if not (re.fullmatch(urlPattern, destination)):
			print("Destination '" + destination + "' is not in valid URL format", file=sys.stderr)
			exit(1)
		host = destination
		hostname = destination
	elif destination_type == destination_type_user_host_windows:
		if not (re.fullmatch(userAtHostPattern, destination)):
			print("Destination '" + destination + "' is not in valid format user@host", file=sys.stderr)
			exit(1)
		host = destination
		hostname = host.split("@")[1]
	elif destination_type == destination_type_user_host_windows_proxy:
		if locals().get("windows_proxy") is None:
			windows_proxy = os.getenv("WINDOWS_PROXY")
			if windows_proxy is None:
				print('Variable WINDOWS_PROXY is not defined. It is usually defined in /etc/perun/services/generic_send/generic_send.conf.', file=sys.stderr)
				exit(1)
		if not (re.fullmatch(userAtHostPattern, destination)):
			print("Destination '" + destination + "' is not in valid format user@host", file=sys.stderr)
			exit(1)
		if not (re.fullmatch(userAtHostPattern, windows_proxy)):
			print("Value of WINDOWS_PROXY '" + windows_proxy + "' is not in valid format user@host", file=sys.stderr)
			exit(1)
		host = windows_proxy                  # propagate on proxy instead of destination
		hostname = destination.split("@")[1]  # hostname file content from original destination
	elif destination_type == destination_type_email:
		print("Destination type " + destination_type + " is not supported yet.", file=sys.stderr)
		exit(1)
	else:
		print("Unknown destination type " + destination_type + ".", file=sys.stderr)
		exit(1)

	# add host to the transport command for all types of destination
	transport_command.append(host)
	# add also slave command if this is not url type of destination
	if destination_type != destination_type_url:
		transport_command.append(slave_command)

	# default tar mode - create an archive
	tar_mode = "-c"
	# should we gzip the resulting tar archive?
	# do it for HTTP transport by default
	if destination_type == destination_type_url:
		# send a gziped tar archive via HTTP(s)
		tar_mode = tar_mode + "z"

	temp_dir = tempfile.TemporaryDirectory(prefix="perun-send.")
	temp_file = tempfile.NamedTemporaryFile(mode="w+", prefix="hostname_", dir=temp_dir.name)
	temp_file.write(hostname)
	temp_file.flush()
	temp_file_name = os.path.basename(temp_file.name)

	tar_command = ["tar", tar_mode, "-C", service_files_dir, "--exclude=_destination", ".", "-C", temp_dir.name, ".",
				   "--transform=flags=r;s|" + temp_file_name + "|HOSTNAME|"]

	# FIXME - works only for destinations type "host" or do we generate folders like "user@host" for that type?
	# determine DIR with special configuration for destination (this dir may not exist) ==IT MUST BE ABSOLUTE PATH (because of double -C in tar command)==
	service_files_for_destination = service_files_dir + "/_destination/" + destination
	# if there is no specific data for destination, use "all" destination
	if not os.path.isdir(service_files_for_destination):
		service_files_for_destination = service_files_dir + "/_destination/all"

	if os.path.isdir(service_files_for_destination):
		tar_command.extend(["-C", service_files_for_destination, "."])

	process_tar = subprocess.Popen(tar_command, stdout=subprocess.PIPE)

	if destination_type == destination_type_user_host_windows_proxy:
		# converts stdin to base64 and append single space and "$DESTINATION" at the end of it
		transformation_process_1 = subprocess.Popen("base64", stdin=process_tar.stdout, stdout=subprocess.PIPE)
		sed_command = ["sed", "-e", "$s/$/ "+destination+"/g"]
		transformation_process = subprocess.Popen(sed_command, stdin=transformation_process_1.stdout, stdout=subprocess.PIPE)
		transformation_process_1.stdout.close()
	elif destination_type == destination_type_user_host_windows:
		# converts stdin to base64
		transformation_process = subprocess.Popen("base64", stdin=process_tar.stdout, stdout=subprocess.PIPE)
	else:
		# just prints stdin to stdout for other destination types
		transformation_process = subprocess.Popen("cat", stdin=process_tar.stdout, stdout=subprocess.PIPE)
	process_tar.stdout.close()

	timeout_command = ["timeout",  "-k", timeout_kill, timeout]
	timeout_command.extend(transport_command)
	process = subprocess.Popen(timeout_command, stdin=transformation_process.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	transformation_process.stdout.close()
	(stdout, stderr) = process.communicate()

	# close temp file with HOSTNAME will delete the file
	temp_file.close()

	if process.returncode == 124:
		# special situation when error code 124 has been thrown. That means - timeout and terminated from our side
		print(stdout.decode("utf-8"), end='')
		print(stderr.decode("utf-8"), file=sys.stderr, end='')
		print("Communication with slave script was timed out with return code: " + str(process.returncode) + " (Warning: this error can mask original error 124 from peer!)", file=sys.stderr, end='')
	else:
		# in all other cases we need to resolve if 'ssh' or 'curl' was used
		if destination_type == destination_type_url:
			# in this situation 'curl' was used
			if process.returncode == 0:
				# check if curl ended without an error (ERR_CODE = 0) (if not, we can continue as usual, because there is an error on STDERR)
				if int(stdout) != 200:
					# check if HTTP_CODE is different from OK (200)
					# if yes, then we will use HTTP_CODE as ERROR_CODE which is always non-zero
					temp.seek(0, 0)
					print(temp.read(), file=sys.stderr)
				else:
					# if HTTP_CODE is 200, then call was successful and result call can be printed with info
					# result call is saved in temp file
					temp.seek(0, 0)
					print(temp.read())
					exit(0)
		else:
			# in this situation 'ssh' was used, STDOUT has to be printed
			print(stdout.decode("utf-8"), end='')
			print(stderr.decode("utf-8"), file=sys.stderr, end='')
		# for all situations different from time-out by our side we can return value from ERR_CODE as the result
		if process.returncode != 0:
			print("Communication with slave script ends with return code: " + str(process.returncode), file=sys.stderr, end='')

	exit(process.returncode)
