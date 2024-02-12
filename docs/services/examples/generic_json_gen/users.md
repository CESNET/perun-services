# Generic JSON generator - User example

## Description

Required attributes to see Users section: **user uuid**.

## Attributes set on the service

- facility uuid 
- user uuid 
- user-facility blacklisted

## Output

```jsonc
{
	"metadata" : {
		// Generated as in metadata.md file
	},
	"users": { // Users
		"user_uuid_1": { 
			"attributes": { // All other attributes without any relationships to other entities (e.g. Facility-User)
				"urn:perun:user_facility:attribute-def:virt:blacklisted": true
				// User attributes
			}
		}
	}
}
```