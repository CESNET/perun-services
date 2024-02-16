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
- **Non-virtual** attributes will default to predefined values:
	- string → ""
	- integer → null
	- boolean → false
	- list → []
	- map/hash → {}
- **Virtual** attributes will have no default value forced (e.g. virt:isBlacklisted can have 3 states: true, false, null)
- Attribute values are not removed when the value is null
- UUID attributes are not shown among other attributes in the “attributes” subsection

### Example outputs
Metadata part is not shown in the examples, but it is present in all outputs.
- [metadata](examples/generic_json_gen/metadata.md)

#### Lone objects (no relationships)
Each of these examples shows a single entity with no relationships to other entities.
- [vos](examples/generic_json_gen/vos.md)
- [groups](examples/generic_json_gen/groups.md)
- [resources](examples/generic_json_gen/resources.md)
- [users](examples/generic_json_gen/users.md)

#### Relationships
The relationship is signalled using **UUID attributes** of more related entities. For example: if the service has UUID for the group and resource set, information about both will be generated, and some relationship values will be included (for precisely what is included, see examples).

The script terminates with an error if any relationship attributes are required (e.g. `urn:perun:group_resource:attribute-def:def:projectName`) and the entities' UUIDs are not set as required attributes (group uuid and resource uuid).

- [groups and vos](examples/generic_json_gen/vos_with_groups.md)
- [groups and resources](examples/generic_json_gen/resources_with_groups.md)
- [resources and vos](examples/generic_json_gen/vos_with_resources.md)
- [users and members](examples/generic_json_gen/vos_with_users.md)
- [users and groups](examples/generic_json_gen/groups_with_users.md)
- [users and resources](examples/generic_json_gen/resources_with_users.md)

##### Three entity relationships
Every 3 entity relationships:
- Resource - Group - Vo 
- User - Vo - Group 
- User - Vo - Resource 
- User - Group - Resource

Return the data as a combination of the outputs, as shown in above examples.

#### Complete example
- [complete](examples/generic_json_gen/complete.md)


### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to the remote machine.

### [SLAVE](../concepts/slave.md)

Calls external script, which location needs to be set in a [PRE](../concepts/pre-mid-post.md#pre-script) script.