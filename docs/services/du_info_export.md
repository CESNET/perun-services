# du_info_export

### [GEN](../concepts/gen.md)

This script generates two sets of JSON files within a directory named `Data`. A single JSON file 
named `<facilityName>-du_info_export` containing overall information about the facility and a separate JSON file
named `<facilityName>-<voName>` for each VO that has a resource on the specified facility, 
containing information specific to that VO.

The script uses the [getHashedDataWithGroups](../modules/PerunServicesInit.md#gethasheddatawithgroups) method to create files containing following information:

The `<facilityName>-du_info_export` file contains list of users who are members of resources on the facility,
along with their attributes and associated data. This includes data about the quotas for a member
on each resource in the following attributes:
- `member_resource:attribute-def:virt:dataQuotas` - the data quota in format `'SoftQuota:HardQuota'`, e.g. `'10G:20T'`
- `member_resource:attribute-def:virt:fileQuotas` - the file quota in format `'SoftQuota:HardQuota'`, e.g. `'100:2000'`
- `member_resource:attribute-def:virt:bucketQuota` - the bucket quota in format `'SoftQuota:HardQuota'`, e.g. `'100:2000'`. Special case is `'-1:-1''` when the creation of new buckets is not allowed

And their admin override versions `dataQuotasOverride`, `fileQuotasOverride`,`bucketQuotaOverride`.

The `<facilityName>-<voName>` file for each VO provides information about the VO including:
`FileType`, `Name`, `LongName`, `FromEmail`, `ToEmail`, `Facility`, `PerunVOID`. 
It also includes detailed data on `Resources`, `Groups` and `Managers` assigned to the VO.


### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to external machine.
