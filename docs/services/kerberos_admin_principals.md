# Kerberos Admin Principals

# Generic JSON GEN

### [GEN](../concepts/gen.md)

This service generates file using the [getHashedHierarchicalData](../modules/PerunServicesInit.md#gethashedhierarchicaldata) method.
The file contains a list of kerberosAdminPrincipals in ascending order (no duplicate values).


### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to external machine.

### [SLAVE](../concepts/slave.md)

Copies file to the directory, set in a [PRE](../concepts/pre-mid-post.md#pre-script) script (defaults to `/var/spool/perun/kerberos_admin_principals`).