# Generic JSON generator - Resource example

## Description

Required attributes to see Resources section: **resource uuid**.

## Attributes set on the service

- facility uuid
- resource uuid 
- resource name 
- resource description

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
	}
}
```