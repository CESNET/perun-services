Upgrade notes

## [8.1.0](https://github.com/CESNET/perun-services/compare/v8.0.0...v8.1.0) (2023-07-20)


### ⚠ BREAKING CHANGES

* **pithia_portal:** Add new required attributes to the service configuration (user:core:displayName, user:virt:eduPersonPrincipalNames, user:def:preferredMail, member:core:status).
* **tinia:** remove gen-local/tinia, it is the same now

### New features and notable changes

* **pithia_portal:** changed data provisioned by this service ([2d31b3f](https://github.com/CESNET/perun-services/commit/2d31b3f00ecf6885aabc3080f6c8dfb719d356d0))
* **tinia:** rename externists and add gotex chips ([0748a60](https://github.com/CESNET/perun-services/commit/0748a60fa1a62329712e125e915f2b70978f5409))
