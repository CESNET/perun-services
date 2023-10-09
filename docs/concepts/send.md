# SEND script

A script that transfers the generated data to the target machine.


Historically the script name and the service name were the same. Nowadays, **it is possible to have multiple services running
one script**.

In a production environment, stored in `[path to engine]/send/`

A portion of services currently run a generic send script that takes care of sending the data to host. The current simplest form of the script is as follows:

```bash
#!/bin/bash
export SERVICE_NAME="[service]"

python3 generic_sender.py "$1" "$2" "$3"
```

Some services (typically AD) may have a completely customized SEND script that handles all the logic, other services
may use [generic_sender.py](../modules/generic_sender.md) to send data to the API or target machine.