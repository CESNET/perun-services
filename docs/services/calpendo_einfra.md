# calpendo_einfra

### [GEN](../concepts/gen.md)

This script generates a CSV file with the following columns: LOGIN, EMAIL, FIRSTNAME, LASTNAME, PHONE, ORG_UNIT, USER_POSITION, UKCO, UK_LOGIN.

It uses the [Text::CSV](https://metacpan.org/pod/Text::CSV) library to generate the CSV format, with suppressed quotation marks, 
because the receiving application is unable to parse them.

The Text:CSV library can be installed on Debian Linux from the package [libtext-csv-perl](https://packages.debian.org/sid/libtext-csv-perl).

### [SEND](../concepts/send.md)

The script uses [generic_sender.py](../modules/generic_sender.md) to send data to the target machine.

### [SLAVE](../concepts/slave.md)

Calls external script, which location needs to be set in a [PRE](../concepts/pre-mid-post.md#pre-script) script. Also expects configuration file to be prepared on
the target machine.
