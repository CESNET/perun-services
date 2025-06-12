# checkin

### [GEN](../concepts/gen.md)

Gen script prepares a json structure which gathers group affiliations for users on the facility with an EGI login. 
It also adds a prefix and suffix necessary for the CheckIn API, does some formatting and prints it to the gen json file

### [SEND](../concepts/send.md)

The send script loads Perun user group affiliations from the gen json file, retrieves necessary authentication
information from the service configuration file, retrieves the access token, retrieves user affiliations from the CheckIn
EGI destination and compares them with the Perun user group affiliations and updates them using the CheckIn API.
Users` affiliations are cleared if the user is missing in Perun, otherwise the affiliations are set to Perun values.
At the end the script prints a summary of the changes to stdout, some error are also printed to stderr.
An optional DEBUG option is available to print more information.

