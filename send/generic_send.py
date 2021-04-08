import os
import shlex
import subprocess
import sys
import tempfile

timeout = "5400"  # 90s * 60 sec = 1.5h
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
		# add certificate to the curl if cert file and key file exists and they are readable
		if os.access(perun_cert, os.R_OK) and os.access(perun_key, os.R_OK) and os.access(perun_chain, os.R_OK):
			perun_cert_setting = "--cert " + perun_cert + " --key " + perun_key + " --cacert " + perun_chain
		else:
			perun_cert_setting = ""
		temp = tempfile.NamedTemporaryFile(mode="w+")
		transport_command = "curl " + perun_cert_setting + " -i -H Content-Type:application/x-tar -w %{http_code} --show-error --silent -o " + temp.name + " -X PUT --data-binary @- "
	else:
		transport_command = "ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no -o GSSAPIKeyExchange=no -o ConnectTimeout=5"

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
	# dir which contains special configuration for this destination (this dir may not exist)  ==IT MUST BE ABSOLUTE PATH (because of double -C in tar command)==
	service_files_for_destination = service_files_dir + "/_destination/" + destination

	# just safety check, this it should be a directory
	if not os.path.isdir(service_files_dir):
		print("$SERVICE_FILES_DIR: " + service_files_dir + " is not a directory", file=sys.stderr)
		exit(1)

	if destination_type == destination_type_host:
		hostname = destination
		host = "root@" + destination
	elif destination_type == destination_type_user_host:
		hostname = destination.split("@")[1]
		host = destination
	elif destination_type == destination_type_user_host_port:
		host = destination.split(":")[0]
		hostname = host.split("@")[1]
		port = destination.split(":")[1]
		transport_command = transport_command + "-p " + port
	elif destination_type == destination_type_url:
		host = destination
		hostname = destination
	elif destination_type == destination_type_user_host_windows:
		host = destination.split(":")[0]
		hostname = host.split("@")[1]
	elif destination_type == destination_type_user_host_windows_proxy:
		if locals().get("windows_proxy") is None:
			windows_proxy = os.getenv("WINDOWS_PROXY")
			if windows_proxy is None:
				print('Variable WINDOWS_PROXY is not defined. It is usually defined in /etc/perun/services/generic_send/generic_send.conf.', file=sys.stderr)
				exit(1)
		host = destination.split("@")[1]
	elif destination_type == destination_type_email:
		print("Destination type " + destination_type + " is not supported yet.", file=sys.stderr)
		exit(1)
	else:
		print("Unknown destination type " + destination_type + ".", file=sys.stderr)
		exit(1)

	# add host to the transport command for all types of destination
	transport_command = transport_command + " " + host
	# add also slave command if this is not url type of destination
	if destination_type != destination_type_url:
		transport_command = transport_command + " " + slave_command

	# default tar mode - create an archive
	tar_mode = "-c"
	# should we gzip the resulting tar archive?
	# do it for HTTP transport by default
	if destination_type == destination_type_url:
		# send a gziped tar archive via HTTP(s)
		tar_mode = tar_mode + "z"

	temp_dir = tempfile.TemporaryDirectory()
	temp_file = tempfile.TemporaryFile(mode="w+", dir=temp_dir.name)
	temp_file.write(hostname)

	if os.path.isdir(service_files_for_destination):
		tar_command = "tar " + tar_mode + " -C " + service_files_for_destination + " . -C " + service_files_dir + "  --exclude=\"_destination\" .  -C " + temp_dir.name + " ."
	else:
		tar_command = "tar " + tar_mode + " -C " + service_files_dir + "  --exclude=\"_destination\" .  -C " + temp_dir.name + " ."

	process_tar = subprocess.Popen(shlex.split(tar_command), stdout=subprocess.PIPE)

	if destination_type == destination_type_user_host_windows_proxy:
		# converts stdin to base64 and append single space and "$DESTINATION" at the end of it
		transformation_process_1 = subprocess.Popen("base64", stdin=process_tar.stdout, stdout=subprocess.PIPE)
		transformation_process = subprocess.Popen("sed -e \"\$s/\$/ $DESTINATION/g\"", stdin=transformation_process_1.stdout, stdout=subprocess.PIPE)
		transformation_process_1.stdout.close()
	elif destination_type == destination_type_user_host_windows:
		# converts stdin to base64
		transformation_process = subprocess.Popen("base64", stdin=process_tar.stdout, stdout=subprocess.PIPE)
	else:
		# just prints stdin to stdout for other destination types
		transformation_process = subprocess.Popen("cat", stdin=process_tar.stdout, stdout=subprocess.PIPE)
	process_tar.stdout.close()

	timeout_command = "timeout -k " + timeout_kill + " " + timeout + " " + transport_command
	process = subprocess.Popen(shlex.split(timeout_command), stdin=transformation_process.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	transformation_process.stdout.close()
	stdout = process.communicate()[0]

	if process.returncode == 124:
		# special situation when error code 124 has been thrown. That means - timeout and terminated from our side
		print(stdout.decode("utf-8"))
		print("Communication with slave script was timed out with return code: " + str(process.returncode) + " (Warning: this error can mask original error 124 from peer!)", file=sys.stderr)
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
			print(stdout.decode("utf-8"))
		# for all situations different from time-out by our side we can return value from ERR_CODE as the result
		if process.returncode != 0:
			print("Communication with slave script ends with return code: " + str(process.returncode), file=sys.stderr)

	exit(process.returncode)
