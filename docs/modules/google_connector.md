# Google connector

## Description
Formerly G Suite. Connects to Google Workspace. Creates, removes and updates objects using Google libraries for Python.

## Setting up service account
Firstly, generate your service account email in your Developers Console
according to [this guide](https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount).

Secondly, generate the [credentials service file](../configurations/google_service_file).

Thirdly, set your API Scopes according 
to [this guide](https://developers.google.com/identity/protocols/oauth2/service-account#delegatingauthority) to be able 
to access Google Groups data via service account. Otherwise, you will get Insufficient Permission Exception.

If you wish to use Drive API, enable it in developer console. Just adding scopes is not sufficient.

## Input files format
Based on desired action, you must prepare CSV file splitted by ';' containing either domain users, 
groups and their members or team drives and their users.

### Groups
`email;name;members_identifiers`
```
group1@domain.org;Group One;user1@domain.org,user2@domain.org,user3@domain.org
group2@domain.org;Group Two;
group3@domain.org;Group Three;user4@domain.org
```

### Team drives
`name; primaryMails`
```
TeamDriveNameOne; user1@domain.org,user2@domain.org
TeamDriveNameTwo;
```

### Users
`primaryMail;givenName;FamilyName;suspended flag`
```
user1@domain.org;User;One;
user2@domain.org;User;Two;
user3@domain.org;User;Three;suspended
user4@domain.org;User;Four;
```

## Dependencies
```
pip install google-api-python-client google-auth google-auth-httplib2
```
