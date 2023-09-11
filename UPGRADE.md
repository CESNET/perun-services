Upgrade notes

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
