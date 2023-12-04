# Generic JSON GEN

### [GEN](../concepts/gen.md)

This service generate JSON using the [getHashedDataWithGroups](../modules/PerunServicesInit.md#gethasheddatawithgroups) method.
Based on the required attributes set on the service (see Perun Admin panel), the script will generate JSON structure. Empty fields are removed from the JSON.


### [SEND](../concepts/send.md)

The script uses [generic_send.py](../modules/generic_sender.md) to send data to the API.

### [SLAVE](../concepts/slave.md)

No slave script is provided.