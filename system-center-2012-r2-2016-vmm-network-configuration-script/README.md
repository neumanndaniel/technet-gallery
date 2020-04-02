# System Center 2012 R2 / 2016 VMM – Network Configuration Script

This PowerShell script creates the network configuration in VMM. The script covers the scenarios of No isolation, VLAN isolation and NVGRE isolation. It creates the Logical Network with corresponding Network Site, VLAN & Subnet and the VM Network. Not to forget the Static IP Address Pool with reservations, Gateway and DNS server is also created by this script.

For further information in German about this script have a look at my blog (Bing Translator Widget is available at the sidebar):

-> [https://www.danielstechblog.io/system-center-2012-r2-vmm-powershell-vmm-network-configuration-script/](https://www.danielstechblog.io/system-center-2012-r2-vmm-powershell-vmm-network-configuration-script/)

If you would like to do an import via an XML file that contains the configuration parameter use the `Import-SCNetworkConfig.ps1`.

## `New-SCNetworkConfig.ps1` history

- Version 2.1
  - Network Site name will be used for the Static IP Pool name.

- Version 2.0
  - Define VM Network name for No isolation and VLAN based Logical Networks
  - Host group selection
  - Define primary and secondary DNS server for IP pools.

- Version 1.0
  - Initial release

## `Import-SCNetworkConfig.ps1` history

- Version 2.1
  - Small fixes

- Version 2.0
  - Define VM Network name for No isolation and VLAN based Logical Networks
  - Host group selection
  - Define primary and secondary DNS server for IP pools.

- Version 1.0
  - Initial release
