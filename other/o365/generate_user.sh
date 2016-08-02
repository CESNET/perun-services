#!/bin/bash

# required fields for creating user: accountEnabled, displayName, mailNickname, userPrincipalName, passwordProfile
# input file has to contain these data: displayName;mailNickname;userPrincipalName;password

ACCESS_TOKEN=`cat /tmp/o365-access-token`

while IFS='' read -r line || [[ -n "$line" ]]; do
    IFS=';' read -a values <<< "$line"
    USER="{\"accountEnabled\":true,\"displayName\":\"${values[0]}\",\"mailNickname\":\"${values[1]}\",\"userPrincipalName\":\"${values[2]}\",\"passwordProfile\":{\"forceChangePasswordNextSignIn\":false,\"password\":\"${values[3]}\"}}"
    echo $USER  > tmp_create_user.json
    curl --header "Content-type: application/json" -X POST --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @tmp_create_user.json 'https://graph.microsoft.com/v1.0/users'
done < "$1"
rm tmp_create_user.json
