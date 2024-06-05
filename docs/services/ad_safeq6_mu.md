# ad_safeq6_mu

### [GEN](../concepts/gen.md)

This script generates `.ldiff` files (`ad_safeq6_mu.ldif` and `ad_safeq6_mu_groups.ldif`) with the following columns:

- For users: `cn`, `givenName`, `sn`, `mail`, `displayName`, `otherPager`, `memberOf`, `postalAddress`
- For groups: `cn`, `member`

Required parameters for the correct connection to LDAP tree:

- `urn:perun:facility:attribute-def:def:adBaseDN`
	- Example: `OU=Users, DC=example,DC=com` 	
- `urn:perun:facility:attribute-def:def:adGroupBaseDN`
	- Example: `O=Groups, DC=example,DC=com`

### [SEND](../concepts/send.md)

This script sends the `.ldiff` files to the LDAP server. Setup is similar to other ldap scripts. As parameters, the script requires the following:
Example of call: 
```bash
./ad_safeq6_mu <facility_name> <namespace_params>
```


### [SLAVE](../concepts/slave.md)

As the SEND part already pushes data to the LDAP server, the SLAVE script is not provided.