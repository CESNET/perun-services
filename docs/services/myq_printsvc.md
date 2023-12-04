# myq_printsvc

### [GEN](../concepts/gen.md)

Generates a CSV file with information about users assigned to the facility resources.
Name, email and chip numbers from the _chipNumbers_ attribute are retrieved for the users, along with names of the resources 
the user belongs to.

For resources with the _myqIncludeWorkplaceInGroups_ attribute set to true the name is replaced with a 
list of workplaces the user belongs to in that resource - in this context _workplace_ constitutes as a group with the 
_inetCispr_ attribute set, which also serves as the name of that workplace. In this case only direct members of assigned
groups are processed

Finally, the script prepares the CSV in the desired format. Because chip numbers are stored in a hexadecimal format in Perun,
 and in an inverted byte order on the destination server, the card bits need to be reversed during this process.

### [SEND](../concepts/send.md)

The send script copies the resulting CSV file from the spool folder to a folder defined by the destination, which in this case
usually is a mounted drive. The rest is handled by a server-side script.
