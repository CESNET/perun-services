#!/bin/bash

# script needs following arguments: email  password

if [ -o -z "$1" -o -z "$2" ]
then
    echo "USAGE: $0  email  password"
    exit 1
fi

ACCESS_TOKEN=`cat /tmp/o365-access-token`
TMPFILE=`mktemp -t update_user_password_XXX.json` || exit 1

USER="$1"
PASSWORD="$2"

#Set password
echo "Updating password"
UPDATE_JSON="{\"passwordProfile\":{\"forceChangePasswordNextSignIn\":false,\"password\":\"$PASSWORD\"}}"
echo "$UPDATE_JSON"  > $TMPFILE
echo $UPDATE_JSON
curl --header "Content-type: application/json" -X PATCH --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @$TMPFILE "https://graph.microsoft.com/v1.0/users/$USER"

rm $TMPFILE
