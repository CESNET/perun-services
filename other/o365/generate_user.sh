#!/bin/bash

# required fields for creating user: accountEnabled, displayName, mailNickname, userPrincipalName, passwordProfile
# input file has to contain these data: displayName;mailNickname;userPrincipalName;password

ACCESS_TOKEN=`cat /tmp/o365-access-token`
TMPFILE=`mktemp -t create_user_XXX.json` || exit 1

while IFS='' read -r line || [[ -n "$line" ]]; do
    IFS=';' read -a values <<< "$line"
    USER="{\"accountEnabled\":true,\"displayName\":\"${values[0]}\",\"mailNickname\":\"${values[1]}\",\"userPrincipalName\":\"${values[2]}\",\"passwordProfile\":{\"forceChangePasswordNextSignIn\":false,\"password\":\"${values[3]}\"}}"
    echo $USER  > $TMPFILE
    curl --header "Content-type: application/json" -X POST --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @$TMPFILE 'https://graph.microsoft.com/v1.0/users'
done < "$1"
rm $TMPFILE
