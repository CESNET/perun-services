# Generic JSON generator - User - Resource (Member-Resource membership) relationship example

## Description

Required attributes to see user-resource relationships: **user uuid**, **resource uuid**. 
The relationship is represented by the `allowed_resources` key in the users section.

## Attributes set on the service

- facility uuid 
- user uuid 
- resource uuid 
- resource name 
- resource description 
- member-resource groupStatus 
- member-resource isBanned 
- user firstName 
- user-facility blacklisted

## Output

```jsonc
{
	"metadata" : {
		// Generated as in metadata.md file
	},
	"resources": {
		"resource_uuid_1": {
			"attributes": {
				"urn:perun:resource:attribute-def:core:name": "Resource name",
				"urn:perun:resource:attribute-def:core:description": "Resource description"
				// Resource attributes
			}
		}
		// Other resources
	},
	"users": { // Users
		"user_uuid_1": { 
			"allowed_resources": { 
				"resource_uuid_1": {
					"attributes": {
						"urn:perun:member_resource:attribute-def:virt:groupStatus": "EXPIRED",
						"urn:perun:member_resource:attribute-def:virt:isBanned": true
						// Member-Resource attributes
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