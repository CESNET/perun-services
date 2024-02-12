# Generic JSON generator - Vo example

## Description

Required attributes to see VOs section: **vo uuid**.

## Attributes set on the service

- facility uuid 
- vo uuid 
- vo name 
- vo createdAt

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
	}
}
```