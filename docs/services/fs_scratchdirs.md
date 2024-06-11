# fs_scratchdirs

### [GEN](../concepts/gen.md)

Retrieves UID, login, GIDs, status for resource members and matches them with the scratch mount point directories defined in the
facility/resource attributes (which also include the permissions for those directories).
If a directory is defined both in the facility attribute and any resource attribute, the resource attribute permission
value is used. The attribute module itself ensures that duplicates among resource attribute directories cannot happen, but another check is performed in case of race conditions and inconsistencies.
The retrieved user information is then saved in the gen file in the format:

``{SCRATCH_DIRECTORY}\t{login}\t{UID}\t{GID}\t{STATUS}\t{UMASK}``

one user-scratch_directory entry per line, meaning one user appears in as many lines as mount point directories they are assigned to.

### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to the remote machine.

### [SLAVE](../concepts/slave.md)

Checks whether the scratch mount point directories exist and creates a scratch directory for each user in that mount point.
Consequently, changes ownership of those directories to the UID and GID of the respective user and sets the permissions 
based on the facility/resource attribute values mentioned earlier.