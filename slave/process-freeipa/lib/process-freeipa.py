# -*- coding: utf-8 -*-

import json
import requests
import urllib3
from optparse import OptionParser

urllib3.disable_warnings()


def main(file, user, password, url):
	ipa = IPAConnector(url, user, password)
	print ipa.login()

	input = open(file, "r").read()
	decoded = json.loads(input, "utf-8")

	# print "Get current users list..."
	# # get current users lists
	# response = ipa.query("user_find", "", {"in_group": "members", "pkey_only": True})
	# ipa_users = []
	# for member in response["result"]["result"]:
	#	 ipa_users.append(member["uid"][0])
	#
	# print "Get current groups list..."
	# response = ipa.query("group_find", "", {"pkey_only": True})
	# ipa_groups = []
	# for group in response["result"]["result"]:
	#	 ipa_groups.append(group["cn"][0])

	print "Checking groups..."
	for group, subgroups in decoded['groups'][0].iteritems():
		check_group(ipa, group, subgroups)

	print "Modify user list"
	# users_from_perun = []
	for member in decoded['members']:
		print " # " + member["user_login"]

		user = ipa.query("user_show", member["user_login"])["result"]["result"]

		for group in member['groups']:
			if group not in user["memberof_group"]:
				ipa.query("group_add_member", group, {"user": member['user_login']})
				print "\t + " + group

		for group in list(set(user["memberof_group"]) - set(member["groups"]) - set(ipa.service_groups)):
			ipa.query("group_remove_member", group, {"user": member['user_login']})
			print "\t - " + group


			# users_from_perun.append(member["user_login"])

	# print "Disable unactive users..."
	# users_to_delete = list(set(ipa_users) - set(users_from_perun))
	# for user in users_to_delete:
	#	 ipa.query("user_disable", user)

	# perun_groups = [x.lower() for x in decoded["groups"][0].keys()]
	# groups_to_delete = list(set(ipa_groups) - set(perun_groups) - set(ipa.service_groups))
	#
	# print "Delete needless groups..."
	# for group in groups_to_delete:
	#	 # 4018 - systemgroup, 4309 - ProtectedEntryError
	#	 ipa.query("group_del", group, {}, [4018, 4309])

	return 0


class IPAConnector():
	base_url = None
	headers = None
	session = None
	login_headers = {'Content-Type': 'application/x-www-form-urlencoded'}

	# IPA connection init
	service_groups = [u"admins", u"ipausers"]

	def __init__(self, base_url, user, password):
		self.base_url = "https://" + base_url
		self.user = user
		self.password = password
		self.session = requests.session()
		self.headers = {'Content-Type': 'application/json', 'referer': self.base_url + "/ipa"}

	def login(self):
		return self.session.post(self.base_url + "/ipa/session/login_password",
								 data="user=" + self.user + "&password=" + self.password,
								 headers=self.login_headers,
								 verify=False)

	def query(self, method, args=[], options={}, accepted_errors=[]):
		if not isinstance(args, list):
			args = [args]
		options['version'] = "2.156"
		payload = {
			"method": method,
			"params": [
				args,
				options
			]
		}
		result = self.session.post(self.base_url + "/ipa/session/json", data=json.dumps(payload),
								   headers=self.headers,
								   verify=False, )
		try:
			result = result.json()
		except:
			raise Exception("Server response not in JSON: \n" + str(result))

		if result['error'] is not None:
			if result['error']['code'] not in accepted_errors:
				raise Exception(
					"IPA server returned unknown error code while calling: \n" \
					+ unicode(payload) + "\nReturned: " + unicode(result))

		return result


def check_group(ipa, group, subgroups, visited_groups=[]):
	# if I doesnt visit this group already...
	if group not in visited_groups:
		# ...check if exists, create it if dont
		response = ipa.query("group_show", group, {"no_members": True}, [4001])
		if response['error'] is not None:
			ipa.query("group_add", group)

		# for all its subgroups
		for subgroup in subgroups:
			# ...check if them exists, create their childs...
			check_group(ipa, subgroup, subgroups[subgroup], visited_groups)
			# and connect them with their parents
			# next state will fail silently if subgroup is already member of group
			ipa.query("group_add_member", group, {"group": subgroup})
		visited_groups.append(group)
	else:
		return visited_groups


if __name__ == "__main__":
	parser = OptionParser()
	parser.add_option("-f", "--perun-file", dest="perun_file", help="path to file from Perun")
	parser.add_option("-o", "--host-url", dest="host", help="FreeIPA host example: ipa.cesnet.cz")
	parser.add_option("-u", "--user", dest="user", help="FreeIPA user to access JSON API")
	parser.add_option("-p", "--password", dest="password", help="FreeIPA user password to access JSON API")
	(options, args) = parser.parse_args()
	main(options.perun_file, options.user, options.password, options.host)

