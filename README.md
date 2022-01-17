<a href="https://perun-aai.org"><img style="float: left; position: relative;" src="https://raw.githubusercontent.com/CESNET/perun/master/perun-web-gui/src/main/webapp/img/logo.png"></a>
## Perun services ##

This repository contains all scripts, which are used by [Perun](https://perun-aai.org/) for provisioning and deprovisioning users to your services (managing access rights to them). Perun can manage any kind of a service, which has either accessible API or has accessible config files. We will be happy to help you with writing your own scripts for managing your service.

### Related projects ###

* [Perun](https://github.com/CESNET/perun) - main Perun repository
* [Perun Web Apps](https://github.com/CESNET/perun-web-apps) - new web user interface for Perun using Angular
* [Perun WUI](https://github.com/CESNET/perun-wui) - current web user interface for Perun
* [Google Group connector](https://github.com/CESNET/google-group-connector) - allow provisioning of Google groups on your domain

### Sources structure ###

* **gen/** - These perl scripts fetch data from Perun and generate new configuration files for each service and destination.
* **send/** - Scripts ensures transfer of configuration files to destination using SSH.
* **slave/** - These (mainly bash) scripts process new files on destination machine and perform change itself.
* **other/perun-propagate/** - New packaging of perun-propagate to force service propagation from client side.
* **other/perun-slave-metacentrum/** - Meta package to install all perun services used by MetaCentrum.
* **scripts/** - Server side of perun-propagate service located on Perun instance.

Gen and send scripts are located on your Perun instance and are used by _perun-engine_ component. Slave scripts are then located on destination machines.

### Build ###

* Install required dependencies:

```
apt-get install dh-make rpm equivs devscripts
```

* Go to _slave/_ folder and run:

```
make all
```

To build only specific service you can use ``make process-passwd`` for _passwd_ service etc. To build a metapackage, which will install all slave scripts you can use ``make meta``.

### Deployment on destinations ###

Perun uses _push model_, so when configuration change occur in a Perun, new config files are generated for affected services and sent to the destinations, where they are processed. Result of such operation is then reported back to the Perun.

* Slave scripts for each service can be automatically installed on destination machines as .deb or .rpm packages.
* You must allow access to destination from your Perun instance by SSH key as user with all necessary privileges (usually root).
* You can specify different user in Perun and it's good practice to restrict access on destination to run only command ``/opt/perun/bin/perun``.
* You can override default behavior of services on each destination by creating file ``/etc/perunv3.conf`` and put own config data here. As example, you can define white/black list of services, which you allow to configure on your destination. You can also set expected destination and facility names, so nobody can push own data to your destination from same Perun instance.

```
# syntax: (item1 item2 item3)
SERVICE_BLACKLIST=()
SERVICE_WHITELIST=()
DNS_ALIAS_WHITELIST=( `hostname -f` )
FACILITY_WHITELIST=()
```

### Service behavior and configuration ###

You can also configure each service on destination machine using _pre_ and _post_ scripts. Simply create folder ``/etc/perun/[service_name.d]/`` (if not exists yet) and put your scripts into it. Name of the scripts are expected to be ``[pre/post]_[number]_filename``. Scripts are processed in an alphabetical order.

Pre scripts are processed before slave script and post scripts are processed after. Pre scripts are usually used to configure the service. You can check example pre script for ldap service in ``slave/process-ldap/conf/`` folder.

### Contributing ###

* Indent all sources by tabs, not spaces.
* For perl sources:
  * Use ``use strict`` and ``use warnings``.
  * Use own global variables with caution (key word ``our``).
  * For defined global variables (e.g. formatting ones $, $",...) always use ``local``.
  * Brackets for function calls are not necessary, if it doesn't hurt code readability.
  * Code commenting - the more, the better. For each function we comment input, output a how does it modify global variables (if used).
  * ``man perlstyle``

### License ###

> Our work is FreeBSD license, yet we sometimes use components under different licenses (e.g. Apache, GNU, CC).

&copy; 2010-2022 [CESNET](https://www.cesnet.cz/?lang=en), [CERIT-SC](https://www.cerit-sc.cz/en/index.html) and [Masaryk University](https://www.muni.cz/en), all rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

### Acknowledgement ###

This work is co-funded by the EOSC-hub project (Horizon 2020) under Grant number 777536.
