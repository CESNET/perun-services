# Generic JSON generator - Complete example

## Description

This example shows all objects and relationships used at once.

## Attributes set on the service

- facility uuid 
- user uuid
- group uuid 
- resource uuid 
- vo uuid 
- vo name 
- vo createdAt 
- group name 
- group description 
- resource name 
- resource description 
- group-resource projectName 
- group-resource isUnixGroup 
- member status 
- member-group status 
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
	"vos": {  // Shown when vo uuid is required
		"vo_uuid_1": {
			"attributes": {
				"urn:perun:vo:attribute-def:core:name": "VO name",
				"urn:perun:vo:attribute-def:core:createdAt": "2019-01-01 00:00:00"
				// Vo attributes
			}
		}
		// Other VOs
	},
	"groups": {  // Shown when group uuid is required
	    "voUuid": "vo_uuid_1",  // Shown when vo uuid is required
		"group_uuid_1": {
			"attributes": {
				"urn:perun:group:attribute-def:core:name": "Group name",
				"urn:perun:group:attribute-def:core:description": "Group description"
				// Group attributes
			}
		}
		// Other groups
	},
	"resources": {  // Shown when resource uuid is required
	    "voUuid": "vo_uuid_1",  // Shown when vo uuid is required
		"resource_uuid_1": {
			"attributes": {
				"urn:perun:resource:attribute-def:core:name": "Resource name",
				"urn:perun:resource:attribute-def:core:description": "Resource description"
				// Resource attributes
			},
			"assigned_groups": { // Shown when group uuid is required
				"group_uuid_1": {
					"attributes": {	
						"urn:perun:group_resource:attribute-def:def:projectName": "Project name",
						"urn:perun:group_resource:attribute-def:def:isUnixGroup": 1
						// Group-Resource attributes
					}
				}
			}
		}
		// Other resources
	},
	"users": { // Added when user uuid is required
		"user_uuid_1": {
			"allowed_vos": { // Added when vo uuid is required
				"vo_uuid_1": { //Member attributes
					"attributes": {
						"urn:perun:member:attribute-def:core:status": "VALID"
						// Member attributes
					}
				}
			},
			"allowed_groups": { // Added when group uuid is required
				"group_uuid_1": {
					"attributes": {
						"urn:perun:member_group:attribute-def:core:status": "VALID"
						// Member-Group attributes
					}
				}
			},
			"allowed_resources": {
				"resource_uuid_1": { // Added when resource uuid is required
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