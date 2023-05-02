#!/usr/bin/env python3.7
import json
import os.path
import re
import sys
import requests

import send_lib

SERVICE_NAME = "feudal"

send_lib.check_input_fields(sys.argv, True)

facility = sys.argv[1]
destination = sys.argv[2]
destination_type = sys.argv[3]

send_lib.check_destination_type_allowed(destination_type, send_lib.DESTINATION_TYPE_SERVICE_SPECIFIC)

credentials_filename = re.sub(r'^https?://', '', destination)

pattern = r'^[A-Za-z0-9_.-]+$'
send_lib.check_destination_format(credentials_filename, destination_type, re.compile(pattern))

if re.fullmatch(re.compile(r'.*\.\..*'), credentials_filename):
	send_lib.die_with_error("Unsupported destination (\"..\" cannot be part of destination name)")

with open(f'/etc/perun/services/feudal/{credentials_filename}', 'r') as f:
	credentials = f.read().strip()

if not credentials:
	send_lib.die_with_error('No credentials available in configuration')
# TODO verify credentials file format
auth = (credentials.split(' ')[0], credentials.split(' ')[1])

service_files_dir = send_lib.get_gen_folder(facility, SERVICE_NAME)

send_lib.create_lock(SERVICE_NAME, destination)

# Get users
response = requests.get(f"{destination}/upstream/users/", auth=auth)
response.raise_for_status()

error_code = 0
headers = {'Content-Type': 'application/json'}
# Handle users
for user in json.loads(response.text):
	user_file_path = f"{service_files_dir}/users/{user}"
	if os.path.exists(user_file_path):
		print("Updating: ", user)
		with open(user_file_path) as f:
			response = requests.post(f"{destination}/upstream/userinfo/", headers=headers, auth=auth, data=f.read())
			if response.status_code != 0:
				error_code = 1

	else:
		print("Deleting: ", user)
		response = requests.delete(f"{destination}/upstream/user/{user}/", headers=headers, auth=auth)
		if response.status_code != 0:
			error_code = 1

exit(error_code)
