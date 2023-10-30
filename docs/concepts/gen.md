# GEN script

Perl scripts that read and process data from Perun into data files for the services (or SLAVE scripts for
further processing). These scripts are run by the Engine.

Historically the script name and the service name were the same. Nowadays, **it is possible to have multiple services running
one script**.

In a production environment, the scripts are located in the engine folder: `[path to engine]/gen/`

The script expects the input parameter ID of the facility for which you want to generate data `-f [facId] |
--facilityId [facId]`.

- Alternatively, it is possible to read the data from a file` [-d FILE | --data FILE ]` together with the facility name
  specification `[-F FACILITY_NAME | --facilityName FACILITY_NAME]`. The facility name will be used to name the output
  directory.

## Consent Evaluation

By default, the script does not evaluate consents. If you want to evaluate consents, you need to specify the
`--consentEvaluation|c` parameter. If the parameter is set to `1`, the script will evaluate consents.
