# Generic JSON generator - User - Group (Group membership) relationship example

## Description

Required attributes to see user-group relationships (group membership): **user uuid**, **group uuid**. 
The relationship is represented by the `allowed_groups` key in the users section.

## Attributes set on the service

- facility uuid 
- user uuid 
- group uuid 
- group name 
- group description 
- member-group status 
- user firstName 
- user-facility blacklisted

## Output

```jsonc
{
	"metadata" : {
		// Generated as in metadata.md file
	},
	"groups": {
		"group_uuid_1": {
			"attributes": {
				"urn:perun:group:attribute-def:core:name": "Group name",
				"urn:perun:group:attribute-def:core:description": "Group description"
				// Other attributes
			}
		}
		// Other groups
	},
	"users": { // Users
		"user_uuid_1": {
            "allowed_groups": { 
				"group_uuid_1": {
					"attributes": {
						"urn:perun:member_group:attribute-def:core:status": "VALID"
						// Member-Group attributes
					}
				}
			},
			"attributes": {
				"urn:perun:user:attribute-def:core:firstName": "John",
				"urn:perun:user-facility:attribute-def:virt:blacklisted": true
				// User and User-Facility attributes
			}
		}
	}
}
```