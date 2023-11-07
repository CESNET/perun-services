
# PRE/MID/POST scripts
The scripts are located in` /etc/perun/[service_name].d/`

The expected filename is `[pre/mid/post]_[number]_filename.`

There can be multiple scripts, they are run in alphabetical order, the `[number]` part, which typically starts with 10, is
used to determine priority.

#### Example
These three scripts will be run in the order dictated by the priority number in the filename:
- `pre_10_unset_old_variables.sh`
- `pre_20_set_new_variables.sh`
- `pre_30_ready_variables.sh`

## PRE script

Runs `before` SLAVE script on the destination machine.
A PRE script is primarily used to define variables (e.g. for names/passwords/paths) and to make changes specific to a
particular target machine.

## MID script

Runs `during` SLAVE script on the destination machine.
A MID script is primarily used to make various modifications to the behavior of the script that differs from the
standard
use of the service by other service managers.

## POST script

Runs `after` SLAVE script on the destination machine.
A POST script is primarily used for specific 'housekeeping', i.e. checking that everything is set as it should be,
passing data to
another script, etc.

