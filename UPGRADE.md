Upgrade notes

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
