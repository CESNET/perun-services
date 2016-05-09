# -*- coding: utf-8 -*-

import json
import requests
import urllib3
from optparse import OptionParser

urllib3.disable_warnings()

# IPA connection init
LOGIN_HEADERS = {'Content-Type': 'application/x-www-form-urlencoded'}
ALLOWED_ERROR_CODES = []
IPA_SERVICE_GROUPS = [u"admins", u"ipausers"]


def main(file, user, password, url):
    global BASE_URL
    global HEADERS
    global SESSION

    BASE_URL = "https://"+url
    HEADERS = {'Content-Type': 'application/json', 'referer': BASE_URL+"/ipa"}

    SESSION = requests.session()
    SESSION.post(BASE_URL+"/ipa/session/login_password",
         data="user="+user+"&password="+password,
         headers=LOGIN_HEADERS,
         verify=False)

    input = open(file, "r").read()

    decoded = json.loads(input, "utf-8")

    print "Get current users list..."
    # get current users lists
    response = ipa_query("user_find", "", {"in_group": "members", "pkey_only": True})
    ipa_users = []
    for member in response["result"]["result"]:
        ipa_users.append(member["uid"][0])

    print "Get current groups list..."
    response = ipa_query("group_find", "", {"pkey_only": True})
    ipa_groups = []
    for group in response["result"]["result"]:
        ipa_groups.append(group["cn"][0])

    print "Checking groups..."
    for group, subgroups in decoded['groups'][0].iteritems():
        check_group(group, subgroups)

    print "Modify user list"
    users_from_perun = []
    for member in decoded['members']:
        print " - "+member["user_login"]
        # check if user exists
        response = ipa_query("user_show", member["user_login"], {"no_members": True}, [4001])

        user_params = {"givenname": unicode("%s %s" % (member["first_name"], member["middle_name"])).strip(),
                       "displayname": unicode("%s %s %s %s %s" % (
                           member["title_before"], member["first_name"], member["middle_name"], member["last_name"],
                           member["title_after"])).strip(),
                       "sn": member["last_name"],
                       "mail": [member["mail"]],
                       "title": member["title_before"]+":"+member["title_after"]}

        # if user exists, update
        if response['error'] is None:
            # When account needs no modification, return error with code 4202 [EmptyModList]
            ipa_query("user_mod", member["user_login"], user_params, [4202])

        elif response['error']['code'] == 4001:
            # when user doesnt exists just create it
            ipa_query("user_add", member["user_login"], user_params)

        for group in member['groups']:
            ipa_query("group_add_member", group, {"user": member['user_login']})
        users_from_perun.append(member["user_login"])

    print "Disable unactive users..."
    users_to_delete = list(set(ipa_users) - set(users_from_perun))
    for user in users_to_delete:
        ipa_query("user_disable", user)

    perun_groups = [x.lower() for x in decoded["groups"][0].keys()]
    groups_to_delete = list(set(ipa_groups) - set(perun_groups) - set(IPA_SERVICE_GROUPS))

    print "Delete needless groups..."
    for group in groups_to_delete:
        # 4018 - systemgroup, 4309 - ProtectedEntryError
        ipa_query("group_del", group, {}, [4018, 4309])

    return 0


def ipa_query(method, args=[], options={}, accepted_errors=[]):
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
    result = SESSION.post(BASE_URL + "/ipa/session/json", data=json.dumps(payload),
                              headers=HEADERS,
                              verify=False, )
    try:
        result = result.json()
    except:
        raise Exception("Server response not in JSON: \n"+str(result))

    if result['error'] is not None:
        if result['error']['code'] not in accepted_errors:
            raise Exception(
                "IPA server returned unknown error code while calling: \n" \
                + unicode(payload) + "\nReturned: " + unicode(result))

    return result


def check_group(group, subgroups, visited_groups=[]):
    # if I doesnt visit this group already...
    if group not in visited_groups:
        # ...check if exists, create it if dont
        response = ipa_query("group_show", group, {"no_members": True}, [4001])
        if response['error'] is not None:
            ipa_query("group_add", group)

        # for all its subgroups
        for subgroup in subgroups:
            # ...check if them exists, create their childs...
            check_group(subgroup, subgroups[subgroup], visited_groups)
            # and connect them with their parents
            # next state will fail silently if subgroup is already member of group
            ipa_query("group_add_member", group, {"group": subgroup})
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
