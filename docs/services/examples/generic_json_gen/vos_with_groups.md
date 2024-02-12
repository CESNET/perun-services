# Generic JSON generator - Group - Vo relationship example

## Description

Required attributes to see group-vo relationships: **vo uuid**, **group uuid**. 
The relationship is represented by the `voUuid` key in the groups section.

## Attributes set on the service

- facility uuid
- group uuid 
- vo uuid 
- vo name 
- vo createdAt 
- group name 
- group description

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
				// vo attributes
			}
		}
		// Other VOs
	},
	"groups": {
		"group_uuid_1": {
			"voUuid": "vo_uuid_1", // represents the vo-group relationship
			"attributes": {
				"urn:perun:group:attribute-def:core:name": "Group name",
				"urn:perun:group:attribute-def:core:description": "Group description"
				// group attributes
			}
		}
		// Other groups
	}
}
```