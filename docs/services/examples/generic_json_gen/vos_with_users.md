# Generic JSON generator - User - VO (Member) relationship example

## Description

Required attributes to see user-vo relationships (membership): **user uuid**, **vo uuid**. 
The relationship is represented by the `allowed_vos` key in the users section.

## Attributes set on the service

- facility uuid 
- user uuid 
- vo uuid 
- vo name 
- vo createdAt 
- member status 
- user firstName 
- user-facility blacklisted

## Output

```jsonc
{
	"metadata" : {
		// Generated as in metadata.md file
	},
	"vos": {
		"vo_uuid_1": {
			"attributes": {
				"urn:perun:vo:attribute-def:core:name": "VO name",
				"urn:perun:vo:attribute-def:core:createdAt": "2019-01-01 00:00:00"
				// Vo attributes
			}
		}
		// Other VOs
	},
	"users": { // Users
		"user_uuid_1": { 
			"allowed_vos": {
				"vo_uuid_1": {
					"attributes": {
						"urn:perun:member:attribute-def:core:status": "VALID"
						// Member attributes
					}
				}
			},
			"attributes": {
				"urn:perun:user:attribute-def:core:firstName": "John",
				"urn:perun:user_facility:attribute-def:virt:blacklisted": true
				// User and User-Facility attributes
			}
		}
	}
}
```