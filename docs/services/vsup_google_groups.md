# vsup_google_groups

Propages users and groups to Google.

### [GEN](../concepts/gen.md)

The groups and users data are generated in a .csv format (see [Google Connector](../modules/google_connector.md)).

### [SEND](../concepts/send.md)
#### Users
New users will have random password generated, so different type of authentication must be provided for
your domain - e.g. using Shibboleth IdP. You can mark users as suspended to suspend them in Google.
Existing username is updated if changed.

Domain users missing in input file are suspended by default, but you can allow deletion by setting 
`allow_delete` in configuration file.

#### Groups
Groups are identified by their mail. Name of Group is updated if changed. Group members are updated if changed.
For managing only groups (filled with public google accounts outside your domain) you can use IDs as provided 
by their Google Identity registered in Perun.

## Configuration
Two configuration files are required. The main configuration [vsup_google_groups.py](../configurations/vsup_google_groups.py)
located in `/etc/perun/services/vsup_google_groups` and the authentication 
credentials [google_service_file](../configurations/google_service_file).

### Dependencies
See [Google Connector](../modules/google_connector.md).
