#!/bin/bash

# input file has to contain these data: userPrincipalName;newPassword

ACCESS_TOKEN=`cat /tmp/o365-access-token`
TMPFILE=`mktemp -t update_user_password_XXX.json` || exit 1

while IFS='' read -r line || [[ -n "$line" ]]; do
    IFS=';' read -a values <<< "$line"
    USER=${values[0]}
    PASSWORD=${values[1]}
    UDPATE_JSON="{\"passwordProfile\":{\"password\":\"$PASSWORD\"}}"
    echo $UDPATE_JSON  > $TMPFILE
    curl --header "Content-type: application/json" -X PATCH --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @$TMPFILE "https://graph.microsoft.com/v1.0/users/$USER"
done < "$1"
rm $TMPFILE
