# Perun Services Init

The perunServicesInit.pm is a module for initializing services. It can be run separately, but it is also used in
[PerunDataGenerator](../modules/PerunDataGenerator.md). The module is used for initializing services, creating temporary
folders, calling the Perun API.

## getHashedHierarchicalData

Generates hashed hierarchical data structure for given service and facility.
If enforcing consents is turned on on the instance and on the resource's consent hub,
generates only the users that granted a consent to all the service required attributes.
New UNSIGNED consents are created to users that don't have a consent containing all the
service required attributes.

```jsonc
{
 attributes: {...hashes...}
 hierarchy: {
   "1": {    ** facility id **
     members: {    ** all members on the facility **
        "4" : 5,    ** member id : user id **
        "6" : 7,    ** member id : user id **
       ...
     }
     children: [
       "2": {    ** resource id **
         children: [],
         voId: 99,
         members: {    ** all members on the resource with id 2 **
           "4" : 5    ** member id : user id **
         }
       },
       "3": {
         ...
       }
     ]
   }
 }
```

## getHashedDataWithGroups

Generates hashed data with group structure for given service and facility.
If enforcing consents is turned on on the instance and on the resource's consent hub,
generates only the users that granted a consent to all the service required attributes.
New UNSIGNED consents are created to users that don't have a consent containing all the
service required attributes.

Generates data in format:

 ```jsonc
 attributes: {...hashes...}
 hierarchy: {
   "1": {    ** facility id **
     members: {    ** all members on the facility **
        "4" : 5,    ** member id : user id **
        "6" : 7,    ** member id : user id **
       ...
     }
     children: [
       "2": {    ** resource id **
         voId: 99,
         children: [
           "89": {    ** group id **
              "children": {},
              "members": {
                  "91328": 57986,
                  "91330": 60838
              }
           }
         ],
         "members": {    ** all members on the resource with id 2 **
             "91328": 57986,
             "91330": 60838
         }
       },
       "3": {
         ...
       }
     ]
   }
 }
 ```