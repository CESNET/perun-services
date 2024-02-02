# Generic JSON GEN

### [GEN](../concepts/gen.md)

This service generates JSON using the [getHashedDataWithGroups](../modules/PerunServicesInit.md#gethasheddatawithgroups) method.
The data from the method is then parsed and transformed into a JSON hierarchy.
The data about the facility and script running are stored inside the `metadata` field.
Other information is conveyed in 4 distinct sections: `vos`, `groups`, `resources` and `users`.
The presence of each of these sections is controlled by the **UUID attributes** specified as **required** by the service.

#### Configuration

The service is configured using the following **UUID Attributes**:

- `facility` - **mandatory attribute**, which specifies the facility to be used for the data retrieval.
- `vo` - optional attribute, which specifies the VO to be used for the data retrieval.
- `group` - optional attribute, which specifies the group to be used for the data retrieval.
- `resource` - optional attribute, which specifies the resource to be used for the data retrieval.
- `user` - optional attribute, which specifies the user to be used for the data retrieval.

#### Technical details

- UUIDs are used as an identifier in resulting JSON.
- No data in entity means that the entity will be an empty hash
	- e.g. if there are no VOs, the `vos` section will be an empty hash
- References to other entities are done using UUIDs
- Non-virtual attributes will default to predefined values:
	- string → ""
	- integer → null
	- boolean → false
	- list → []
	- map/hash → {}
- Virtual attributes will have no default value forced (e.g. virt:isBlacklisted can have 3 states: true, false, null)

#### Example

Attributes set: facility uuid, user uuid, vo uuid, vo name, vo createdAt, member status, user firstName, user-facility
blacklisted
Example output of the service:

```json
{
	"metadata": {
		"version": "1.0.1",
		"facility": {
			"facilityName": "facility1",
			"facilityUuid": "facility_uuid_1",
			"destinations": [
				"destination1"
			],
			"attributes": {
				"urn:perun:facility:attribute-def:def:hostName": "hostname",
				"urn:perun:facility:attribute-def:def:desc": {
					"cs": "Testovací facilita",
					"en": "Test facility"
				}
			}
		}
	},
	"vos": {
		"vo_uuid_1": {
			"attributes": {
				"urn:perun:vo:attribute-def:core:name": "VO name",
				"urn:perun:vo:attribute-def:core:createdAt": "2019-01-01 00:00:00"
			}
		}
	},
	"users": {
		"user_uuid_1": {
			"allowed_vos": {
				"vo_uuid_1": {
					"attributes": {
						"urn:perun:member:attribute-def:core:status": "VALID"
					}
				}
			},
			"attributes": {
				"urn:perun:user:attribute-def:core:firstName": "John",
				"urn:perun:user_facility:attribute-def:virt:blacklisted": true
			}
		}
	}
}
```

### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to the remote machine.

### [SLAVE](../concepts/slave.md)

Calls external script, which location needs to be set in a [PRE](../concepts/pre-mid-post.md#pre-script) script.