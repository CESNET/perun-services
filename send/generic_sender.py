import os
import sys
import tempfile
import send_lib
import subprocess


def process(tar_command, transport_command, destination: str, destination_type: str):
	"""
	Process data. Extract files and convert to base64 for host windows destination types.
	:param tar_command:
	:param transport_command:
	:param destination:
	:param destination_type:
	:return: (returncode, stdout, stderr)
	"""
	process_tar = subprocess.Popen(tar_command, stdout=subprocess.PIPE)
	if destination_type == send_lib.DESTINATION_TYPE_USER_HOST_WINDOWS_PROXY:
		# converts stdin to base64 and append single space and "$DESTINATION" at the end of it
		transformation_process_1 = subprocess.Popen("base64", stdin=process_tar.stdout, stdout=subprocess.PIPE)
		sed_command = ["sed", "-e", "$s/$/ " + destination + "/g"]
		transformation_process = subprocess.Popen(sed_command, stdin=transformation_process_1.stdout,
												  stdout=subprocess.PIPE)
		transformation_process_1.stdout.close()
	elif destination_type == send_lib.DESTINATION_TYPE_USER_HOST_WINDOWS:
		# converts stdin to base64
		transformation_process = subprocess.Popen("base64", stdin=process_tar.stdout, stdout=subprocess.PIPE)
	else:
		# just prints stdin to stdout for other destination types
		transformation_process = subprocess.Popen("cat", stdin=process_tar.stdout, stdout=subprocess.PIPE)
	process_tar.stdout.close()

	the_process = subprocess.Popen(transport_command, stdin=transformation_process.stdout, stdout=subprocess.PIPE,
								   stderr=subprocess.PIPE)
	transformation_process.stdout.close()
	(stdout, stderr) = the_process.communicate()
	return the_process.returncode, stdout, stderr


def prepare_tar_command(tar_mode: str, hostname_dir: str, service_files_dir: str, destination: str) -> list[str]:
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
	service_files_for_destination = service_files_dir + "/_destination/" + destination
	# if there is no specific data for destination, use "all" destination
	if not os.path.isdir(service_files_for_destination):
		service_files_for_destination = service_files_dir + "/_destination/all"

	if os.path.isdir(service_files_for_destination):
		tar_command.extend(["-C", service_files_for_destination, "."])

	return tar_command


def prepare_url_transport_command(temp, content_type: str = "application/x-tar", method: str = "PUT"):
	"""
	Prepares base transport command for CURL connection.
	If available, adds common perun certificate.
	:param temp:
	:param content_type: for example 'application/json'
	:return: transport command
	"""
	transport_command = ["curl"]
	# add certificate to the curl if cert file and key file exist, and they are readable
	if os.access(send_lib.PERUN_CERT, os.R_OK) and os.access(send_lib.PERUN_KEY, os.R_OK) and os.access(
		send_lib.PERUN_CHAIN, os.R_OK):
		transport_command.extend(
			["--cert", send_lib.PERUN_CERT, "--key", send_lib.PERUN_KEY, "--cacert", send_lib.PERUN_CHAIN])
	# add standard CURL params
	transport_command.extend(["-i", "-H", "Content-Type:" + content_type, "-w", "%{http_code}", "--show-error",
							  "--silent", "-o", temp.name, "-X", method, "--data-binary", "@-"])
	return transport_command


def prepare_ssh_transport_command():
	"""
	Prepares base transport command for SSH connection.
	:return: transport command
	"""
	return ["ssh", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o",
			"GSSAPIAuthentication=no", "-o", "GSSAPIKeyExchange=no", "-o", "ConnectTimeout=5"]


if __name__ == "__main__":
	send_lib.check_input_fields(sys.argv)
	facility_name = sys.argv[1]
	destination = sys.argv[2]
	if len(sys.argv) == 3:
		# if there is no destination type, use default 'host'
		destination_type = send_lib.DESTINATION_TYPE_HOST
	else:
		destination_type = sys.argv[3]
		if destination_type == send_lib.DESTINATION_TYPE_EMAIL or destination_type == send_lib.DESTINATION_TYPE_SERVICE_SPECIFIC:
			print("Destination type " + destination_type + " is not supported yet.", file=sys.stderr)
			exit(1)

	send_lib.check_destination_format(destination, destination_type)
	service_name = send_lib.get_global_service_name()

	# choose transport command, only url type has different transport command at this moment
	transport_command = send_lib.load_custom_transport_command(service_name)
	if transport_command is None and destination_type == send_lib.DESTINATION_TYPE_URL:
		# FIXME - test this use-case
		temp = tempfile.NamedTemporaryFile(mode="w+")
		# errors will be saved to temp file
		transport_command = prepare_url_transport_command(temp)
		# append BA credentials if present in service config for the destination
		auth = send_lib.get_auth_credentials(service_name, destination)
		if auth != None:
			username = auth[0]
			password = auth[1]
			transport_command.extend(["-u", username + ":" + password])
	elif transport_command is None:
		transport_command = prepare_ssh_transport_command()

	host, hostname, port = send_lib.prepare_destination(destination, destination_type)
	if port is not None:
		transport_command.extend(["-p", port])

	# add host to the transport command for all types of destination
	transport_command.append(host)

	# add also slave command if this is not url type of destination
	slave_command = "/opt/perun/bin/perun"
	if destination_type != send_lib.DESTINATION_TYPE_URL:
		transport_command.append(slave_command)

	# prepare temporary directory with hostfile, use as context manager, so it gets removed automatically
	with send_lib.prepare_temporary_directory() as hostname_dir:
		with open(os.path.join(hostname_dir, "HOSTNAME"), mode='w+') as hostfile:
			# prepare hostfile
			hostfile.write(hostname)
			hostfile.flush()

			# define how files generated by gen script will be extracted for transport
			generated_files_dir = send_lib.get_gen_folder(facility_name, service_name)
			# default tar mode - create an archive
			tar_mode = "-c"
			# should we gzip the resulting tar archive?
			# do it for HTTP transport by default
			if destination_type == send_lib.DESTINATION_TYPE_URL:
				# send a gziped tar archive via HTTP(s)
				tar_mode = tar_mode + "z"
			tar_command = prepare_tar_command(tar_mode, hostname_dir, generated_files_dir, destination)

			# prepend timeout command
			timeout_command = ["timeout", "-k", str(send_lib.TIMEOUT_KILL), str(send_lib.TIMEOUT)]
			timeout_command.extend(transport_command)
			transport_command = timeout_command

			# process
			return_code, stdout, stderr = process(tar_command, transport_command, destination, destination_type)

			if return_code == 124:
				# special situation when error code 124 has been thrown. That means - timeout and terminated from our side
				print(stdout.decode("utf-8"), end='')
				print(stderr.decode("utf-8"), file=sys.stderr, end='')
				print("Communication with slave script was timed out with return code: " + str(
					return_code) + " (Warning: this error can mask original error 124 from peer!)", file=sys.stderr,
					  end='')
			else:
				# in all other cases we need to resolve if 'ssh' or 'curl' was used
				# TODO: how do we treat custom configed transport commands?
				if destination_type == send_lib.DESTINATION_TYPE_URL:
					# in this situation 'curl' was used
					if return_code == 0:
						# check if curl ended without an error (ERR_CODE = 0) (if not, we can continue as usual, because there is an error on STDERR)
						if int(stdout) not in send_lib.http_ok_codes:
							# check if HTTP_CODE is different from OK
							# if yes, then we will use HTTP_CODE as ERROR_CODE which is always non-zero
							temp.seek(0, 0)
							print(temp.read(), file=sys.stderr)
						else:
							# if HTTP_CODE is OK, then call was successful and result call can be printed with info
							# result call is saved in temp file
							temp.seek(0, 0)
							print(temp.read())
							exit(0)
				else:
					# in this situation 'ssh' was used, STDOUT has to be printed
					print(stdout.decode("utf-8"), end='')
					print(stderr.decode("utf-8"), file=sys.stderr, end='')
				# for all situations different from time-out by our side we can return value from ERR_CODE as the result
				if return_code != 0:
					print("Communication with slave script ends with return code: " + str(return_code), file=sys.stderr,
						  end='')

			exit(return_code)
