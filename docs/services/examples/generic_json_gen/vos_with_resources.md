# Generic JSON generator - Resource - Vo relationship example

## Description

Required attributes to see vo-resource relationships: **vo uuid**, **resource uuid**.
The relationship is represented by the `voUuid` key in the resources section.

## Attributes set on the service

- facility uuid 
- vo uuid 
- resource uuid 
- vo name 
- vo createdAt 
- resource name 
- resource description

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
	"resources": { 
		"resource_uuid_1": {
			"voUuid": "vo_uuid_1", // Represents vo-resource relationship
			"attributes": {
				"urn:perun:resource:attribute-def:core:name": "Resource name",
				"urn:perun:resource:attribute-def:core:description": "Resource description"
				// Resource attributes
			}
		}
		// Other resources
	}
}
```