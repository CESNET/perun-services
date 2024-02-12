# Generic JSON generator - Group - Resource relationship example

## Description

Required attributes to see group-resource relationships: **group uuid**, **resource uuid**. 
The relationship is represented by the assigned_groups key in the resources section.

## Attributes set on the service

- facility uuid
- group uuid 
- resource uuid 
- resource name 
- resource description 
- group name 
- group description 
- group-resource projectName 
- group-resource isUnixGroup

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
				// Group attributes
			}
		}
		// Other groups
	},
	"resources": { 
		"resource_uuid_1": {
			"attributes": {
				"urn:perun:resource:attribute-def:core:name": "Resource name",
				"urn:perun:resource:attribute-def:core:description": "Resource description"
				// Resources attributes
			},
			"assigned_groups": { // Resource - Group relationship
				"group_uuid_1": {
					"attributes": {	
						"urn:perun:group_resource:attribute-def:def:projectName": "Project name",
						"urn:perun:group_resource:attribute-def:def:isUnixGroup": 1
						// Group-resources attributes
					}
				}
			}
		}
		// Other resources
	},
}
```