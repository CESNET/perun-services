Upgrade notes

## [16.9.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.8.0...v16.9.0) (2025-06-23)


### Features

* **checkin:** added new service for managing perun entitlements in checkin ([2d8e275](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/2d8e2758e90c9db6d676c971023fe51a094e4b70))
* **ldap_lsaai:** create primary group for every user ([efd5257](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/efd5257a5dc78d12ce40250b6fcc7140b66f3b5a))

## [16.8.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.7.0...v16.8.0) (2025-05-07)


### ⚠ BREAKING CHANGES

* Add attribute `urn:perun:user:attribute-def:def:
login-namespace:lifescienceid-persistent-shadow` as required
 attribute for the service.

### Features

* add new attributes for ldap_lsaai gen ([8556558](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/85565582eee0f632610a16448f0a434e0561bccc))
* **denbi_portal_compute_center:** addition of lsaai scoped attributes ([08d6d8a](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/08d6d8a0859ddb278cccc083b61b57eab51366db))
* **ldap_lsaai:** afiliations to ldap_lsaai gen ([22fd7ba](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/22fd7ba8a0894bd8039631813c2f6672e830d263))


### Bug Fixes

* correctly reference service name in case of  no url endpoint in s3 ([cfbc1d2](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/cfbc1d2cfbb3f0f39b2fde2eb35192d1a113cf57))
* **denbi_portal_compute_center:** typo ([1cdf526](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1cdf5263aa9cada8bb14e63d1372e543163a34b3))
* **ldap_lsaai:** typo ([cfc0e46](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/cfc0e46470f625311bb3b56b40c15643ed7014d3))

## [16.7.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.6.0...v16.7.0) (2025-04-23)


### Features

* s3 destinations customizable filename extension ([0baf505](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/0baf5055ab9a28a054abfa40306e9e6f8fc78534))

## [16.6.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.5.0...v16.6.0) (2025-04-02)


### ⚠ BREAKING CHANGES

* **crm_ceitec:** Remove authz file for SOAP endpoint from instance configuration.

### Features

* **crm_ceitec:** support new json api endpoints ([9d1ec69](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/9d1ec6903c79190633135d024488c94cf8f618f8))
* **pbsmon_json:** extend export with gpu attribute ([e8be012](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/e8be012571fbd7f61b9da1c321b4ce713130b229))


### Bug Fixes

* **drupal_elixir:** check duplicates and invalid names before moving files ([00167b3](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/00167b3ea8c1ff823af25d8bd3b0d0cdc9c10f1c))
* **drupal_elixir:** script always ends with 0 ([deb67dc](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/deb67dca7282c07756b8ed45dc7ffe7d72a21955))
* **drupal_elixir:** swapped exit codes ([5b353e3](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/5b353e3c33cf7eaaeac5e6eba31706301277b4d4))

## [16.5.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.4.0...v16.5.0) (2025-03-10)


### Features

* add new destination s3-json ([c2b9de2](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c2b9de21bede3996c54465e542dfbb58b77f679a))


### Bug Fixes

* fix url-json improper service check ([531ae6d](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/531ae6d79f89f383884f03b7397f8fb5ca6b156d))
* **pbsmon_json:** owner attr ([04572b0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/04572b0b0ff58c58fb959d09cfcc4f27daec694c))

## [16.4.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.3.1...v16.4.0) (2025-02-21)


### Features

* allow specify tenant for S3 destination and change configuration for s3 checksum ([583020d](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/583020dbaf473b688dc10ea93ca8ea6558cd922e))
* s3-allow to add date&time filename ext ([55931c5](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/55931c5160f8cb6f54bb4773474981b53972e1ce))

## [16.3.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.3.0...v16.3.1) (2025-01-22)


### Bug Fixes

* formatted code that caused pipeline format check to fail ([1757344](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/17573445bf9e2a6420c310df8ba0e1c10fb3ee1c))
* **safeq:** use new storage in homedir path ([cd103bd](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/cd103bd4b6294fadd50f4c61902e717555028033))

## [16.3.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.2.1...v16.3.0) (2025-01-09)


### ⚠ BREAKING CHANGES

* **generic_send:** removed generic_send.py

### Features

* new regex for mail validation ([ecebefc](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/ecebefc339ec1ad95dce9b1d5cc3bc121195e15e))


### Others

* **generic_send:** delete generic_send.py ([829b0ee](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/829b0ee2e2054dd774274963b53d3c139c0c2bdb))

## [16.2.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.2.0...v16.2.1) (2024-12-16)


### ⚠ BREAKING CHANGES

* Remove user_facility:virt:blacklisted attribute from all services. Attribute definition can be deleted.

### Bug Fixes

* close subprocesses in senders ([310d68e](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/310d68e629950c5f356561f1c001665fb7ad950d))


### Refactoring

* removed usage of uf:v:blacklisted attribute ([f992605](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/f99260501e8bcf218ca142085f96f5ae29ac38b1))

## [16.2.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.1.1...v16.2.0) (2024-11-21)


### Features

* **generic_sender:** add url-json transport to generic_sender ([7341009](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/7341009f6517f910dd8a7250405d419cc96d9548))

## [16.1.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.1.0...v16.1.1) (2024-11-14)


### Bug Fixes

* **generic_sender:** fix syntaxError caused by nested quotation marks ([9f91fd5](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/9f91fd50d82807912633d2dca00d9692de628bc0))

## [16.1.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v16.0.0...v16.1.0) (2024-11-08)


### Features

* **generic_sender:** add s3 transport to generic_sender ([da61936](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/da619367042f81125e8f88b7d45bb601ecaeacb7))

## [16.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v15.0.2...v16.0.0) (2024-10-24)


### ⚠ BREAKING CHANGES

* **apache_ssl:** Removed `apache_ssl` service.
* **apache_ssl:** Remove `apache_ssl` service from perun instance.

### Bug Fixes

* add missing import ([41e50ba](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/41e50bab57f4fcdd9bb22a1ee2e5957b66670168))
* fix imports and regex strings ([4490e4d](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/4490e4d0a630f4ce3e3bb69bd0826e03cb9b7960))
* use context managers for opened files ([a8301f3](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/a8301f32c7dd7d53ca1263fd1c8a2e808874281e))


### Others

* **apache_ssl:** remove unused service ([ae450bb](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/ae450bb14ea2e8562071d19d7f2aa6940a44f491))

## [15.0.2](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v15.0.1...v15.0.2) (2024-10-17)


### Bug Fixes

* fix imports and regex strings ([19ec634](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/19ec6341d2372716d8768c0350ce3862fea02312))

## [15.0.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v15.0.0...v15.0.1) (2024-10-01)


### Bug Fixes

* bump package version for perun-slave-base ([a98bc88](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/a98bc882183de00cfa00db9391583331658ec2bf))
* **drupal_elixir:** bump package version ([1ca4cc5](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1ca4cc548e8aa1c204dfcc63593ba44b28b05c00))

## [15.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.5.0...v15.0.0) (2024-10-01)


### ⚠ BREAKING CHANGES

* ALL services using generic json gen in combination with slave script need to
rename their PRESCRIPT/POSTSCRIPT to match the PERUN service name

### Features

* allow multiple source services for generic propagation ([494183d](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/494183d81b3bc568c34ddc4f00fe64e6d7e7e9c6))

## [14.5.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.4.0...v14.5.0) (2024-09-20)


### Features

* **drupal_elixir:** users-duplicities.txt users-invalid-names.txt to home directory ([9d5c39a](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/9d5c39a5302b4d7d201c1201653d79e9fd4c56a4))

## [14.4.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.3.0...v14.4.0) (2024-08-28)


### ⚠ BREAKING CHANGES

* **umbraco_mu:** added
urn:perun:member:attribute-def:core:status
to required attributes of umbraco_mu

### Features

* modified and removed several services ([c72fe59](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c72fe593cdede1d40246cbcd8782b5ad1d0f7104))


### Bug Fixes

* **perun-slave-full:** update list of dependant packages ([2e65e1b](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/2e65e1b53ebd59133af63ea73d117d3e30184d70))
* **umbraco_mu:** skip expired vo members ([3bdf7a7](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/3bdf7a7854fa13d6d4066aebfe0e9c16681e008f))

## [14.3.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.2.1...v14.3.0) (2024-08-15)


### Features

* **vsup_web_apps:** include bank accounts from SIS in export ([65ec8ba](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/65ec8ba47cc2d13086afe4c95b5ebeb5dd3eeb6e))


### Bug Fixes

* do not use switch feature of perl in perunServicesUtils.pm ([11d05d0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/11d05d0a0ece444d2cdf279b9b6ae08e0373217b))
* **generic_json:** correctly append data when one user in multiple vos ([1561eb7](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1561eb7f6ed55b5fae063e0b40cfcfcab8faa5ac))

## [14.2.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.2.0...v14.2.1) (2024-08-07)


### Bug Fixes

* **generic_json:** correctly append data when one user in multiple vos ([c292772](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c2927728f37dce58e05ec6436be60a938e146317))

## [14.2.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.1.0...v14.2.0) (2024-08-02)


### Features

* added optional job which checks deprecated modules for python ([c552197](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c5521978aeb8114d8fb52e93f3476d9695f5fe94))


### Bug Fixes

* **mailaliases_generic:** sort mail aliases for each user ([c49727d](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c49727d97c3ad5b915a8fcb11c9d0f489c060486))

## [14.1.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v14.0.0...v14.1.0) (2024-07-04)


### ⚠ BREAKING CHANGES

* **bbmri_negotiator:** Add following attributes as required by the service
- `urn:perun:group:attribute-def:def:serviceID`
- `urn:perun:group:attribute-def:def:admServiceID`
- `urn:perun:group:attribute-def:def:serviceProviderID`
- `urn:perun:group:attribute-def:def:admServiceProviderID`

### Features

* **ad_group_vsup_o365:** optionally allow expired members in o365 ([3f9828c](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/3f9828c9ba50ac5e1cda2985d558c9e0ab14e08c))
* **ad_mu:** added extension attributes ([561be47](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/561be47b23cd42cf229e3ac1c9d65cc5f053fa96))
* **bbmri_negotiator:** 🎸 Extend with service and service_provider mappings ([efa1911](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/efa1911fb91468647aedd9611c8cd1014f61cf9b))
* **kerberos_admin_principals:** delete missing principals from KDC ([9ba46a7](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/9ba46a7a2d8ce5c985b5435ce042ab3c76ee2502))


### Bug Fixes

* check for duplicated chip numbers in relevant services ([4fe1eb1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/4fe1eb1382a81bf038654ec2fddf0fe46cb509f3))

## [14.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v13.2.0...v14.0.0) (2024-06-25)


### ⚠ BREAKING CHANGES

* **ad_safeq6_mu:** groups in ad_safeq6_mu have different name format
* Release packages for affiliations_mapping(_mu), k5login_root, yubikey_root, sshkeys_root, puppet_dashboard, oidc_with_groups_einfra.

### Features

* **fs_scratchdirs:** new service fs_scratchdirs ([1ca25da](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1ca25da672b44ceb32355d4e597a38e1420a865b))
* **ldap_lsaai:** ldap script for provisioning LSAAI users ([5e8d888](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/5e8d888a378aa9a17a9e736e637b59f03251fd45))


### Bug Fixes

* **ad_safeq6_mu:** use shorter group CN (names) ([967fe53](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/967fe5330f4e87d937dbf6d65f77add6cb855424))
* double quote DST_FILE in some slave scripts ([212aee3](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/212aee3994344c557d4334e955c64100a53f0aba))
* **safeq:** new storage server ([1e65848](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1e658483cb0cd7412bb347e7ff24bb61b78ff282))


### Reverts

* revert remove obsolete hack for L- and Guest- accounts ([52e0dc0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/52e0dc0a90222f3731b2bcfdf13107888a2c8da6))

## [13.2.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v13.1.0...v13.2.0) (2024-06-05)


### ⚠ BREAKING CHANGES

* **ad_safeq6_mu:** new config file needed with LDAP address, username and password
* **du_info_export:** Add new bucket quota attributes and mark them required for du_info_export service.
* LOG_DIR has to be configured and the directory has to exist on the engine machine, send scripts now expect another argument (always sent by engine)

### Features

* **ad_safeq6_mu:** new service ad_safeq6_mu ([03a8977](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/03a89773abfcfd62fd3e5a6afbecfc26f69c0de8))
* archive spool files ([b28bef8](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/b28bef8113f5b36e9de9f2ead5eb2e977919c41f))
* **du_info_export:** add bucket quota attributes to export ([6bab380](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/6bab380866573775050966d7a7b1061f3608d57d))
* update hashed data method calls ([ef7f9d5](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/ef7f9d50d5238f53f90090ceadd0cddd93049946))


### Bug Fixes

* **ad_group_mu_ucn:** remove obsolete hack for L- and Guest- accounts ([723e290](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/723e290e2c8d1e46a93c2dc51deeefad2c617976))
* **crm_ceitec:** make sure we use proper muni identity ([0622fc7](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/0622fc7937a0d9179d9640aa04f0ec8616213660))
* **o365_mu_account_status:** add missing quotes ([55a70f4](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/55a70f4a7d46dc7aeae85077a730f7f3a8d9deaa))
* **o365_mu_ukb_forward_status:** add missing quotes ([5903599](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/59035992a65d0fac544d2d89c8610a04a2d28ac4))

## [13.1.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v13.0.0...v13.1.0) (2024-05-23)


### Features

* update some services from generic_send to generic_sender ([e359ce1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/e359ce1a3ff0012a55981476dcae9ca2f19b11b5))


### Bug Fixes

* **afs_group:** fixed group name resolving ([5da92f8](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/5da92f8b2ab4fad80bd4e789f3193389f5bfd91d))
* **drupal_elixir:** 🐛 Unresolved variable in GEN script ([a4e29ea](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/a4e29eac7250400af0bd8a26ec6ab2456f76ba7d))
* extend default sending timeout to 2.5h ([75e6420](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/75e64203938adcd335c9540419a02214002e441c))
* resolving malinglist name / username in various services ([7493351](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/7493351b27cee931080488a0fa8e18d3993b0f55))
* **vsup_stag:** resolve expiration also from study system ([4ac34f1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/4ac34f1ddea062abf9d6331076c4b495ccbed1cd))

## [13.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v12.0.1...v13.0.0) (2024-05-10)


### ⚠ BREAKING CHANGES

* **hadoop_hdfs:** Removed `hadoop_hdfs` service.
* **hadoop_hdfs:** Remove `hadoop_hdfs` service from perun instance.
* **hadoop_hbase:** Removed `hadoop_hbase` service.
* **hadoop_hbase:** Remove `hadoop_hbase` service from perun instance.
* **firewall:** Removed `firewall` service.
* **firewall:** Remove `firewall` service from Perun instance and delete required
attributes `user:def:IPAddresses` and `resource:def:firewallRules`.
* **afs:** Remove "user:virt:organizationsWithLoa:en" from required attributes of AFS service.
Add "user:virt:eduPersonPrincipalNames" instead. Users formerly belonging to 'ruk.cuni.cz' cell will
use facility default, most probably 'ics.muni.cz'.
* Removed `feudal` and `operations_portal_egi` services
* **myq_printsvc:** preferredMail is now a required attribute

### Features

* **afs:** use user:virt:eduPersonPrincipalNames to determine AFS cell ([bdbc8d2](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/bdbc8d20578598ea6e77128ca1f966eb46480e3a))


### Bug Fixes

* handle file names with special characters or spaces correctly ([aba8b58](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/aba8b588ee8e0d5d8368268eab76d420593f48bb))
* **myq_printsvc:** use O365 mail for workplaces if available, preferredMail otherwise ([9add5c8](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/9add5c867e62aacab10222f9701d04144f1e88c1))
* **o365_mu:** use an error code for missing facility name ([3833fc4](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/3833fc40af0b1e25b208a77b4dcef62749a2c383))
* remove extra -o, add missing space in o365 scripts ([53be623](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/53be62347a841b83a99cef029d1ef2ba3a6bb69d))
* **rt:** generate proxy idp eppns from einfra idp identities ([835c0ab](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/835c0abfdbe548a2aafa25cc2ecc43325be03904))
* update slave changelogs ([8f69ac4](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/8f69ac4f6d6b532b1f11a9499b8b40c3d1fd81f8))


### Others

* **firewall:** remove unused service ([e37f926](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/e37f9263aa842125a36d204dd4d42724f2452de7))
* **hadoop_hbase:** remove unused service ([0069ec9](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/0069ec9f5d106f2352b3d6f5131458a3642e46b7))
* **hadoop_hdfs:** remove unused service ([d48674f](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/d48674f9df4e7ddccf1ef18e95d2901761e85965))
* removed services ([3686e0b](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/3686e0b8b4c52acb79c6ab8052deab642c71132d))

## [12.0.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v12.0.0...v12.0.1) (2024-04-09)


### Bug Fixes

* **atlassian_mu:** allow empty name ([84a9e56](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/84a9e56416f5e4df7f9849778e8dfc17dbd957d0))
* **vsup_ifis:** use accented chars in ADR_TYPE ([d7aa09c](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/d7aa09cb05ad1e90268da6145b5c4415184200a1))

## [12.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v11.3.0...v12.0.0) (2024-03-25)


### ⚠ BREAKING CHANGES

* **myq_printsvc:** service myq_printsvc has a different required attribute,
change from preferredMail to o365PrimaryEmailAddress:mu
* **m365_cloud:** add user_facility isBanned attribute as required
* **du_info_export:** json structure of the VO export has changed to contain resource UUID
* **du_info_export:** resource UUID needs to be set as required attribute of the service
in order for the script to be able to use it

### Features

* **du_info_export:** add UUID to Resource UUID to VO export ([c3708c6](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c3708c6c9acee411214b9c952882bab9fa68a440))
* **m365_cloud:** revoke sessions of banned users ([381572c](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/381572cd3dc4960255490d678d2b70ec1d39e5dc))


### Bug Fixes

* **myq_printsvc:** use O365 e-mail instead of preferredMail ([1dd63a9](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1dd63a9a5adf950caab3fafecac166c277602201))

## [11.3.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v11.2.0...v11.3.0) (2024-03-11)


### Features

* **perun-propagate:** allow changing authz type in Perun API url ([7674d53](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/7674d53d888f07aae4ef25aef616e90128b84974))

## [11.2.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v11.1.0...v11.2.0) (2024-03-01)


### Features

* **perun-propagate:** reworked perun-propagate client package ([253c6ea](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/253c6eab9ccbdf56c5b4c9d65eafd3676caf98c7))


### Bug Fixes

* **generic_json_gen:** inconsistent attributes value ([bae4ccc](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/bae4ccc2b59d272ea60790ae48cdda1411217c2c))

## [11.1.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v11.0.0...v11.1.0) (2024-02-22)


### Features

* **vsup_stag:** support transfering students photos ([dc52091](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/dc52091d18a815ae9b3c0a7824e82e9700eef5f4))


### Bug Fixes

* apply ruff lint suggestions when getting json value ([42a18f8](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/42a18f8309c0dca6abd543c03fb3be5f8127a61f))
* **calpendo_einfra:** fixed undefined values when printing CSV ([126832e](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/126832e4a8576ae1be7855fe4a3290cf5efcf82f))

## [11.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v10.2.1...v11.0.0) (2024-02-16)


### ⚠ BREAKING CHANGES

* **google_groups:** Install python libraries, rewrite config files (see docs)
* Changed structure of generated data, UUIDs attributes signal relationships

### Features

* **calpendo_einfra:** added more attributes to gen script of service calpendo_einfra ([2ee11f6](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/2ee11f6694759f16a4206f496a60b1dab506fd5b))
* generic_json_gen rewrite ([acdded8](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/acdded897759432c284fae36fccd5061282a1aab))
* **google_groups:** removing dependency on java connector ([383b826](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/383b8268af2481292626c94246fd85334e70e54c))


### Bug Fixes

* fixed deb dependency for perun-slave-process-generic-json-gen ([dbee68f](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/dbee68f59f348a5f77e3f69f0e1f34be8f841bea))
* **fs_project:** sort output file for better comparison of changes ([b8cf617](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/b8cf617907e711bd213a5ab38b73b5ec8cab7e4b))
* include kerberos_admin_principals in perun-slave-full ([708632a](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/708632a6d6ea636a7abb689c14380b66f79073e1))
* **kerberos_admin_principal:** bash reference and work dir path ([21e5477](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/21e5477178138d565af03e47b150f0e492a063d5))

## [10.2.1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v10.2.0...v10.2.1) (2024-01-31)


### Bug Fixes

* check_input_fields() now allows 3-4 input args again ([01b3f6b](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/01b3f6b8c36ee722cf06908eed2b4208982899d7))

## [10.2.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v10.1.0...v10.2.0) (2024-01-30)


### ⚠ BREAKING CHANGES

*   * All services using URL destination and standard send script will
    start append basic auth credentials if stored in their config
    at `/etc/perun/services/service_name/service_name.py`
  * Locally modified send scripts need to be checked and updated.
  * Configuration for `pithia_portal` service must be updated to not
    use default properties for authentication to token endpoint
    (username -> tokenUsername, password -> tokenPassword).

### Features

* added ruff rules ([8baf816](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/8baf816d1c8e18efed14a5aa9d3a8fd7f39f58a6))
* **base:** 🎸 Add function to log to err output in base ([c6be12c](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c6be12c9d24472ce90d5aa7c779742d68194c023))
* **bbmri_negotiator:** new service bbmri_negotiator ([8a69003](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/8a69003291d85296992877f81f28869d2ac9a613))
* **drupal_elixir:** 🎸 Print out drupal_elixir invalid user names ([acae27a](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/acae27a8b715855eed55dd09f9f65f249594706f))
* **kerberos_admin_principals:** added kerberos_admin_principals service ([a0ab9eb](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/a0ab9eb65efbc9b8d5442f0125f55198fff32f28))
* optionally append BA credentials to URL destinations ([3d1934e](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/3d1934ea035fc5804b88940641ba675d936ef07a))


### Bug Fixes

* **scs_it4i:** use default python from container ([76f66b2](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/76f66b29d5570e32b2b5155912ecc185e66376fb))
* update version of perun-slave-base package ([0391cf7](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/0391cf743d1ea9834620348abdca0f77a8e44ffb))
* **vsup_stag:** support also non-teaching employees ([4715985](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/4715985f05a13a961d857de2a0bb4999e4bda070))

## [10.1.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v10.0.0...v10.1.0) (2024-01-15)


### ⚠ BREAKING CHANGES

* **m365_cloud:**   * This PR includes changes already set on EINFRA, no need for update there.
  * Beware, that python 3.9 version is used on EINFRA specifically (send_lib).
  * Should the gen script be updated on EINFRA,
    perunDataGenerator needs to be updated to contain finalizeMemberUsersData method.
* vsup_is and vsup_kos service definitions can be removed
* **ldap_it4i:** Add user:virt:login-namespace:einfraid-persistent attribute between required.

### Features

* **calpendo_einfra:** new service calpendo ([164a8d1](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/164a8d10770123e52a0a5b69988776204db69566))
* **generic_json_gen:** added SLAVE script for generic service ([1511fde](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/1511fdedf052428200600dcd23b46421ae8612e7))
* **ldap_it4i:** provide also einfra ID attribute ([a86fb21](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/a86fb21dd0598be8a92d6d4d313334bdfc082637))
* **m365_cloud:** change source login attribute ([15bfe92](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/15bfe9290fd25a65f816981562c66e569d257323))


### Bug Fixes

* **calpendo_einfra:** fixed name in changelog ([55ac9c3](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/55ac9c30ab50dcc10a042c328bc47ee1a10b0e4b))
* **generic_json_gen:** send script correctly finds gen folder ([c269fa3](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/c269fa3076a13987c6b19cbf5bba3d6e1ae6db57))


### Refactoring

* removed unused services vsup_is and vsup_kos ([4d4b3bf](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/4d4b3bfea262805f4ce7414bb7aff856d4861ed2))

## [10.0.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v9.1.0...v10.0.0) (2023-12-04)


### ⚠ BREAKING CHANGES

* **bbmri_rt:** 🧨 rt_bbmri now uses LS IDs and LS usernames
* **bbmri_rt:** Service need to have `urn:perun:user:attribute-def:def:login
-namespace:lifescienceid-persistent-shadow` and `urn:perun:user:attribute-def:
def:login-namespace:lifescienceid-username` attributes assigned as required
in Peurn configuration if they used BBMRI IDs or BBMRI usernames. See changes
to get hint what attribute needs to be assigned for which service. Consents should
be modified to be granted for these attributes, as the ID change is internal
change and does not reall affect users.

### Features

* **gen:** generic_json service ([fdcce27](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/fdcce275f40c70b011cf9a2872fc8cb62a2473f3))
* **sympa_cesnet:** added new version of sympa service ([40bcd4d](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/40bcd4d50d3134c235528c5356d1ac6340c1e040))


### Bug Fixes

* **bbmri_rt:** 🐛 use LS ID in BBMRI_rt gen scripti ([7ed49da](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/7ed49daf8313f90cb47f316a118df47172c3b562))
* **myq_printsvc:** correctly determine group membership ([b0a902a](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/b0a902a32121e05b499e2e980a19f710d36f7fb6))
* **o365_groups_mu:** handle null description from O365 ([cd5e90b](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/cd5e90b64e539a9b7a3723359708f8a4b5716906))

## [9.1.0](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/compare/v9.0.0...v9.1.0) (2023-11-24)


### Features

* **drupal_elixir:** 🎸 Add firstName and lastName to ELIXIR Drupal ([ffc2da7](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/ffc2da7ad7287a3cdf2cea7ad3b619004a58ae84))
* **m365_cloud:** allow change of group name ([83e607b](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/83e607b0053ea11c5b02e247f2d7deb4a84ca7c1))


### Bug Fixes

* empty commit to trigger first GitLab release ([84bb84e](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/84bb84e11bc99c35c25eaa2c5d57c8692a2cf4b0))
* remove version number from pyproject.toml ([30bee7c](https://gitlab.ics.muni.cz/perun/perun-idm/perun-services/commit/30bee7ca7385afb27e0d7356c7dd0a15ee511552))

## [9.0.0](https://github.com/CESNET/perun-services/compare/v8.6.0...v9.0.0) (2023-11-07)


### ⚠ BREAKING CHANGES

* **myq_printsvc:** resource def boolean attribute `myqIncludeWorkplaceInGroups` has to be created on the instance and added to the required attributes of the service
 Group def `inetCispr` and member-group virt `groupStatusIndirect` also have to be added to required attributes
 Scan storage path changed to `\\ha-bay.ics.muni.cz\MyQscan\$login\Scan`
* 🧨 bbmri_networks, bbmri_collections now use LS IDs and LS
usernames
* Services need to have `urn:perun:user:attribute-def:def:login
-namespace:lifescienceid-persistent-shadow` and `urn:perun:user:attribute-def:
def:login-namespace:lifescienceid-username` attributes assigned as required
in Peurn configuration if they used BBMRI IDs or BBMRI usernames. See changes
to get hint what attribute needs to be assigned for which service. Consents should
be modified to be granted for these attributes, as the ID change is internal
change and does not reall affect users.

### Features

* **m365_cloud:** new service for provisioning to m365 ([efac6d8](https://github.com/CESNET/perun-services/commit/efac6d8e2dc074feb9216cdaaed6cc866de59293))
* **myq_printsvc:** include workplace information ([77ae34d](https://github.com/CESNET/perun-services/commit/77ae34defcaecaab56733cf8a0c4ecaeaa6ff57a))


### Bug Fixes

* 🐛 Use LS ID in BBMRI negotiator scripts ([a196c21](https://github.com/CESNET/perun-services/commit/a196c2160080b5dfd4c6dc7e29627fe8a42691ed))
* **docs:** moved service docs to correct folder ([56171a0](https://github.com/CESNET/perun-services/commit/56171a080c0fb9bc5426538d2ba77df9fca76037))
* **vsup_ifis:** include new ids from DC2 ([7531120](https://github.com/CESNET/perun-services/commit/753112082d3d37766f00e92ae7f0b41a3e27cb70))
* **vsup_ifis:** use only relations from stag ([6f73a59](https://github.com/CESNET/perun-services/commit/6f73a593db75209da9849dc1b006e63e30a4648f))
* **vsup_stag:** fixed number of columns when inserting teachers ([8744d55](https://github.com/CESNET/perun-services/commit/8744d558828a3d17addd1bede4cf15d115115e30))

## [8.6.0](https://github.com/CESNET/perun-services/compare/v8.5.0...v8.6.0) (2023-10-10)


### ⚠ BREAKING CHANGES

* **slack:** Requires Slack SDK to be installed
* **hml_json:** Add new required attribute to the service configuration (user:virt:scopedLogin-namespace:mu).

### Features

* **hml_json:** changed hml_json gen script to use scoped mu login ([9be7196](https://github.com/CESNET/perun-services/commit/9be71964dadd0b0ab4ee16057f096ed65e693ae0))
* **slack:** service for propagation to Slack ([2c814e6](https://github.com/CESNET/perun-services/commit/2c814e614e962e8c26dc0c171ea4ea36cd481265))


### Bug Fixes

* **slack:** don't update displayName ([c4af71d](https://github.com/CESNET/perun-services/commit/c4af71d2912e6a53acaca358842e1040c5a251eb))
* **vsup_ifis:** proper utf8 handling and column reference ([7224314](https://github.com/CESNET/perun-services/commit/72243143617a3c1470869f5a62a049258fe65199))
* **vsup_stag:** fix column mapping and sysdate ([43bf239](https://github.com/CESNET/perun-services/commit/43bf239d7d3253e52ab1ddb3e0426baebab5dcf0))
* **vsup_web:** make sure to use utf8 ([02aef0f](https://github.com/CESNET/perun-services/commit/02aef0f8d3b20421a6ca855243c1222bfbe9c9aa))
* **vsup_web:** temporary fix to chomp on input data ([d80c56d](https://github.com/CESNET/perun-services/commit/d80c56d540a71d9f13293e5e3e677908809d0ff3))

## [8.5.0](https://github.com/CESNET/perun-services/compare/v8.4.0...v8.5.0) (2023-09-27)


### ⚠ BREAKING CHANGES

* **atlassian_mu:** script needs to be run once with DEACTIVATED_PREFIX_INIT=1

### Features

* **atlassian_mu:** add 'del_' prefix to inactive users ([71afe61](https://github.com/CESNET/perun-services/commit/71afe61ad9c45659d5d9316ebcab47267fe6f885))
* **o365_mu_ukb_forward_status:** add new service ([1f0fe02](https://github.com/CESNET/perun-services/commit/1f0fe02c28a56eab21273ffa53b0c4e322023fd2))


### Bug Fixes

* **scs_it4i:** use send_lib.py, support v2 API ([63611f4](https://github.com/CESNET/perun-services/commit/63611f4c4625d8c1a172fad54b0ce0f4dc68431f))
* **vsup_stag:** update service for new DB schema ([be6835d](https://github.com/CESNET/perun-services/commit/be6835dfd3b953c54d5bc3a6393b4338c4ef466f))

## [8.4.0](https://github.com/CESNET/perun-services/compare/v8.3.0...v8.4.0) (2023-09-11)


### Features

* extract main generic_sender logic to python send() method ([266497a](https://github.com/CESNET/perun-services/commit/266497a457fb6013f9f70a59143b138a9977898c))
* **pithia_portal:** added authorization token support ([1a98bd0](https://github.com/CESNET/perun-services/commit/1a98bd05104beec8b74ae6c2b8725c13915bfe52))
* **webcentrum_eosc:** new configurable service ([bb268b0](https://github.com/CESNET/perun-services/commit/bb268b08af513f1da2211282b4f1786b5288b54f))


### Bug Fixes

* **vsup_ifis:** fixed column names for stag ([d25baaa](https://github.com/CESNET/perun-services/commit/d25baaa7f523b73ea451932654e38c87c0a282d5))
* **vsup_ifis:** stag will use oracle db ([3538b1b](https://github.com/CESNET/perun-services/commit/3538b1bedb9b7ad29a88d84bca301f9eda1060ed))

## [8.3.0](https://github.com/CESNET/perun-services/compare/v8.2.0...v8.3.0) (2023-09-04)


### ⚠ BREAKING CHANGES

* **o365_groups_mu:** When merged, can remove gen-local-dev and send-local-dev changes including descriptions on idm-prod

* **o365_groups_mu:** new service propagating to Teams via O365 ([2cf5d4f](https://github.com/CESNET/perun-services/commit/2cf5d4fb4db89c30f70d1b11916b1f0aa5edbc09))
* **vsup_k4:** ignore smartmatch experimental warning ([64781a3](https://github.com/CESNET/perun-services/commit/64781a32f7811cf39ebdc816e664838281de7a84))
* **vsup_tritius:** fixed utf8 encoding ([2472cd4](https://github.com/CESNET/perun-services/commit/2472cd4dc94790f04ccc7cada22e00d58208e4cf))

## [8.2.0](https://github.com/CESNET/perun-services/compare/v8.1.0...v8.2.0) (2023-08-15)


### New features and notable changes

* **vsup_ifis:** extend library to support also IS/STAG ([420efe5](https://github.com/CESNET/perun-services/commit/420efe5c157e84f1e765bcd8b8c0035a73217335))
* **vsup_stag:** new service for pushing data to IS/STAG ([84c8e8c](https://github.com/CESNET/perun-services/commit/84c8e8c8ff5e20e8d179e22b1d3b317e5d80d164))

## [8.1.0](https://github.com/CESNET/perun-services/compare/v8.0.0...v8.1.0) (2023-07-20)


### ⚠ BREAKING CHANGES

* **pithia_portal:** Add new required attributes to the service configuration (user:core:displayName, user:virt:eduPersonPrincipalNames, user:def:preferredMail, member:core:status).
* **tinia:** remove gen-local/tinia, it is the same now

### New features and notable changes

* **pithia_portal:** changed data provisioned by this service ([2d31b3f](https://github.com/CESNET/perun-services/commit/2d31b3f00ecf6885aabc3080f6c8dfb719d356d0))
* **tinia:** rename externists and add gotex chips ([0748a60](https://github.com/CESNET/perun-services/commit/0748a60fa1a62329712e125e915f2b70978f5409))

## [8.1.0](https://github.com/CESNET/perun-services/compare/v8.0.0...v8.1.0) (2023-07-20)


### ⚠ BREAKING CHANGES

* **pithia_portal:** Add new required attributes to the service configuration (user:core:displayName, user:virt:eduPersonPrincipalNames, user:def:preferredMail, member:core:status).
* **tinia:** remove gen-local/tinia, it is the same now

### New features and notable changes

* **pithia_portal:** changed data provisioned by this service ([2d31b3f](https://github.com/CESNET/perun-services/commit/2d31b3f00ecf6885aabc3080f6c8dfb719d356d0))
* **tinia:** rename externists and add gotex chips ([0748a60](https://github.com/CESNET/perun-services/commit/0748a60fa1a62329712e125e915f2b70978f5409))
