# SMA Runbook - Convert WAP VM Role OS Differencing Disk

This SMA Runbook converts the differencing Virtual Hard Disk of a WAP VM Role into a dynamic Virtual Hard Disk. The runbook works with both VM generations Gen 1 and Gen 2. **It converts only the WAP VM Role boot disk.** PowerShell 3.0, SC2012 SP1 VMM cmdlets or higher, a Windows Azure Pack and Service Management Automation installation are required.

**Prerequisites for SMB 3.0 support:**

- On Hyper-V hosts: Enable-WSManCredSSP -Role Server -Force
- On VMM management server: Enable-WSManCredSSP -Role Client -DelegateComputer "Hyper-V host" -Force
- Grant the SCVMM service account full access on the file share (file share and folder permissions)!

For further information in German about this script have a look at my blog (Bing Translator Widget is available at the sidebar):

-> [https://www.danielstechblog.io/sma-runbook-convert-wap-vm-role-os-differencing-disk](https://www.danielstechblog.io/sma-runbook-convert-wap-vm-role-os-differencing-disk)

## History

- Version 2.0
  - Support for SMB 3.0 file shares

- Version 1.0
  - Initial release
