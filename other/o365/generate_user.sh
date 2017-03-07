#!/bin/bash

# script needs following arguments: display_name  email  password
# password must be at least 8 characters long

if [ -z "$1" -o -z "$2" -o -z "$3"]
then
    echo "USAGE: $0  display_name  email  password"
    exit 1
fi

ACCESS_TOKEN=`cat /tmp/o365-access-token`
TMPFILE=`mktemp -t create_user_XXX.json` || exit 1

DISPLAY_NAME="$1"
USER="$2"
USER_NAME="$(basename "$USER" "@czechglobe.cz")"
PASSWORD="$3"

# Create new account
echo "creating user $DISPLAY_NAME"
UPDATE_JSON="{\"accountEnabled\":true,\"displayName\":\"$DISPLAY_NAME\",\"mailNickname\":\"$USER_NAME\",\"userPrincipalName\":\"$USER\",\"passwordProfile\":{\"forceChangePasswordNextSignIn\":false,\"password\":\"D3faultHeslo\"}}"
echo "$UPDATE_JSON"  > $TMPFILE
echo $UPDATE_JSON
curl --header "Content-type: application/json" -X POST --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @$TMPFILE 'https://graph.microsoft.com/v1.0/users'

# Set user Location ( CZ :))
echo "Set location, password requirements"
UPDATE_JSON="{\"usageLocation\":\"CZ\",\"passwordPolicies\":\"DisablePasswordExpiration,DisableStrongPassword\"}"
echo "$UPDATE_JSON"  > $TMPFILE
echo $UPDATE_JSON
curl --header "Content-type: application/json" -X PATCH --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @$TMPFILE "https://graph.microsoft.com/v1.0/users/$USER"

#Set password
echo "Set password"
UPDATE_JSON="{\"passwordProfile\":{\"forceChangePasswordNextSignIn\":false,\"password\":\"$PASSWORD\"}}"
echo "$UPDATE_JSON"  > $TMPFILE
echo $UPDATE_JSON
curl --header "Content-type: application/json" -X PATCH --header "Authorization: $ACCESS_TOKEN" --header "Accept: application/json" -d @$TMPFILE "https://graph.microsoft.com/v1.0/users/$USER"

rm $TMPFILE
