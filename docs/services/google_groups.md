# google_groups

Propages groups with members and team drives with permissions to Google.

### [GEN](../concepts/gen.md)

The groups data and team drives are generated in a .csv format (see [Google Connector](../modules/google_connector.md)).


### [SEND](../concepts/send.md)
#### Groups
Groups are identified by their mail. Name of Group is updated if changed. Group members are updated if changed.
For managing only groups (filled with public google accounts outside your domain) you can use IDs as provided 
by their Google Identity registered in Perun.

#### Drives
TeamDrives are identified by their name. TeamDrive user permissions are updated if changed.
User identifier is just primaryMail. Every User has equal permission with full access as organizer. 
TeamDrives missing in input file are suspended by default, but can be deleted if specified in `allow_delete_teamdrive`
configuration option.

## Configuration
Two configuration files are required. The main configuration [google_groups.py](../configurations/google_groups.py)
located in `/etc/perun/services/google_groups` and the authentication 
credentials [google_service_file](../configurations/google_service_file).

### Dependencies
See [Google Connector](../modules/google_connector.md).
