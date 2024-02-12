# Generic JSON generator - Group example

## Description

Required attributes to see Groups section: **group uuid**.

## Attributes set on the service

- facility uuid 
- group uuid 
- group name 
- group description

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
	}
}
```