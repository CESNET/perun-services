# Ldap LSAAI

### [GEN](../concepts/gen.md)

The gen script generates two ldif files - one for users and one for groups.

### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to external machine.

### [SLAVE](../concepts/slave.md)

Sorts generated entries, fetches data from LDAP, and updates LDAP with modified objects.
The prescript contains LDAP credentials and search filters for user and group entries.