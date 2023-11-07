# Perun Data Generator

The perunDataGenerator.pm is a module for generating general data structure, which needs to be imported and cannot run
separately. The attributes are grouped, but
their names are not transformed. All service's required attributes are taken into account, and depending on chosen
method processed or skipped. The resulting format of the data is JSON. It contains two main methods used in scripts:
_generateUsersDataInJSON_ and _generateMemberUsersDataInJson_. Both methods support filtering invalid VO members, then
also _urn:perun:member:attribute-def:core:status_ attribute needs to be required for service.

### generateUsersDataInJSON

The _generateUsersDataInJSON_ method stores only user and user_facility attributes, which are grouped for each user
to a single object. The result structure will look like this (depending on required attributes):

```
[
   {
     "urn:perun:user:attribute-def:core:displayName": "Joe Doe",
     "urn:perun:user_facility:attribute-def:virt:isBanned": false
   }
]
```

### generateMemberUsersDataInJson

The _generateMemberUsersDataInJson_ method stores user, user_facility, member, member_resource, resource
and facility attributes. The resulting structure groups users' data under "users" section and resources' data
with assigned members under "groups" section. The assigned members are linked with their user attributes with the
"link_id" property. The structure can look like this:

```
{
   "groups" : [
      {
         "members" : [
            {
               "link_id" : 1,
               "urn:perun:member:attribute-def:core:status" : "VALID",
               "urn:perun:member_resource:attribute-def:virt:isBanned" : false
            }
         ],
         "urn:perun:resource:attribute-def:core:name" : "perun_resource"
      }
   ],
   "urn:perun:facility:attribute-def:core:name" : "perun_facility",
   "users" : [
      {
         "link_id" : 1,
         "urn:perun:user:attribute-def:core:displayName" : "Joe Doe",
         "urn:perun:user_facility:attribute-def:virt:isBanned" : false
      }
   ]
}
```