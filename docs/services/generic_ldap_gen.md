# Generic LDAP GEN

### [GEN](../concepts/gen.md)

The gen script ensures that all the necessary required facility attributes are set and consequently retrieves all 
required resource and user attributes and prints them into LDIF files `{SERVICE_NAME}._groups/users.ldif`.
Only the attributes present in the mapping facility attributes are printed and matched with the LDAP attribute name.
The gen script also prepares multiple files containing information necessary for the send script, such as the LDAP search
filters, whether to disable or remove missing entities, etc.
Some formatting of the Perun values (convertion to base 64 where necessary and escaping) is also done.

#### Required attributes
* urn:perun:facility:attribute-def:def:ldapBaseDN - base DN of the LDAP server
* urn:perun:facility:attribute-def:def:ldapBaseDNGroup - base DN of the LDAP server used for groups
* urn:perun:facility:attribute-def:def:ldapUserDNAttribute - either `uid` or `cn`
* urn:perun:facility:attribute-def:def:ldapUserAttrMap - mapping of Perun user attributes to LDAP attributes, e.g. `urn:perun:user:attribute-def:def:sshPublicKey` = `sshKeys`
* urn:perun:facility:attribute-def:def:ldapGroupAttrMap - mapping of Perun resource attributes to LDAP attributes, e.g. `urn:perun:resource:attribute-def:virt:voShortName` = `organization`
* urn:perun:facility:attribute-def:def:ldapUserObjectClasses - list of objectClasses to append to the user entries, e.g. `person, top`
* urn:perun:facility:attribute-def:def:ldapGroupObjectClasses - list of objectClasses to append to the group entries, e.g. `groupOfNames, top`
* urn:perun:facility:attribute-def:def:ldapDeactivate - flag whether to deactivate entries missing in Perun instead of removing
* urn:perun:facility:attribute-def:def:ldapDeactivateAttributeName - the name of the LDAP attribute to set to true when entry deactivated
* urn:perun:facility:attribute-def:def:ldapUserFilter - filter value which will be used to search LDAP for user entries, e.g. `(objectClass=person)`
* urn:perun:facility:attribute-def:def:ldapGroupFilter - filter value which will be used to search LDAP for group entries, e.g. `(objectClass=groupOfUniqueNames)`

### [SEND](../concepts/send.md)

The send script uses the `ldap3` python module to connect to the LDAP server using basic auth and optionally a TLS certificate.
Credentials need to be present in `/etc/perun/services/{service_name}/{service_name}.py`, example:
```python
import ldap3
import ssl

credentials = {
                        "$destination": { 'username': "$username", 'password': "$password" },
                        "$destinationCERT": { 'username': "$username", 'password': "$password", "tls": ldap3.Tls(
            local_private_key_file="$private_key_file",
            local_certificate_file="$cert_file",
            validate=ssl.CERT_REQUIRED,
            version=ssl.PROTOCOL_TLSv1_2,
            ca_certs_file="$ca_file"
        ) },
        }
```

To learn more about the options for TLS see https://ldap3.readthedocs.io/en/latest/ssltls.html#the-tls-object.
By default the send script inserts `ldap3.Tls(validate=ssl.CERT_REQUIRED, version=ssl.PROTOCOL_TLSv1_2)`, requiring the server to provide a valid certificate.

The script loads all the information passed from the GEN script files, parses Perun groups(resources) and users from the LDIF files.
The LDAP group and user entries are retrieved from the LDAP server using provided filters (from the facility attributes).
It then compares Perun entries against the LDAP entries, modifying only the attributes from the mapping facility attributes.
Entries missing in Perun and present in LDAP are either removed or marked as deactivated, based on the facility configuration.
Symmetrically entries missing in LDAP and present in Perun are added with all the mapped attributes.
Every change is logged into `./logs/{facility}/{service_name}/{service_name}.log` and a summary is printed at the end of the propagation.


