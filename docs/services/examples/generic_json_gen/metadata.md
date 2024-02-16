# Generic JSON generator - Metadata example

## Description

Required attributes to see Metadata (and run the service) section: **facility uuid**.

The metadata part of each output will contain information about the facility, including any required facility
attributes. This information is generated in the same manner in all other showcased examples.

### Important

`facility_name`, `facility_uuid` and `destination` fields are always filled with the information from the facility *
*regardless** of the other Required Attributes set.

## Attributes set on the service

- facility uuid
- facility hostName
- facility desc

## Output

```jsonc
{
	"metadata": {
		"version": "1.0.1", // Version of the script
		"facility": {
			"facilityName": "facility1", // Name of the facility
			"facilityUuid": "facility_uuid_1", // UUID of the facility
			"destinations": [ // List of destinations
				"destination1"
			],
			"attributes": { // Facility attributes
				"urn:perun:facility:attribute-def:def:hostName": "hostname",
				"urn:perun:facility:attribute-def:def:desc": {
					"cs": "Testovací facilita",
					"en": "Test facility"
				}
				// Facility attributes
			}
		}
	}
}
```