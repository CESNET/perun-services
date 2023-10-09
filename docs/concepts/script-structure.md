# Script Structure

The scripts are usually packaged as a group of [GEN](gen.md)/[SEND](send.md)/[SLAVE](slave.md).
They are used to export data from PERUN to destination systems.


```
Basic structure of a service
┌───┐  
│GEN│  
└┬──┘  
┌▽───┐ 
│SEND│ 
└┬───┘ 
┌▽────┐
│SLAVE│
└─────┘
```

The [GEN](../concepts/gen.md) script generates data from Perun, the [SEND](../concepts/send.md) script sends the data to
the target machine, and the [SLAVE](../concepts/slave.md) script processes the data on the target machine.

During the execution of the SLAVE script there are PRE/MID/POST hooks available. The PRE script is executed before the
SLAVE script, the MID script can be during the execution of the SLAVE script, and the POST script is executed after
the execution (usually used as a cleanup script). 

```
Basic structure of a SLAVE script
┌───┐
│PRE│
└┬──┘
┌▽────┐
│SLAVE│
└┬─┬──┘
 │┌▽──┐
 ││MID│
 │└┬──┘
┌▽─▽─┐
│POST│
└────┘
```
More information [here](../concepts/pre-mid-post.md).