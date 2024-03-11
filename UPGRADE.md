Upgrade notes

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
