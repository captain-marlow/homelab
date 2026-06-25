Firewall settings are all over the place. Almost everything has a firewall section. Where should you put them?

Don't enable the firewall without first creating rules or else you will be locked out. An example of a rule could be:

```
Direction: in

Action: ACCEPT

Interface: vmbr0 (or another network interface)

Enable: checked

Source: optional

Protocol: tcp

Dest. port: 8006
```

This will allow access to the web GUI after the firewall is enabled. 

Macros are useful for creating firewall rules. 

If you want to apply a firewall rule to everything, you must put the rule in the Datacenter. For all other objects (pve1, VMs, LXCs, etc.), firewall rules only apply at that level.