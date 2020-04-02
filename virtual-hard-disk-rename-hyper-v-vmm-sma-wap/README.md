# Virtual Hard Disk Rename - Hyper-V / Virtual Machine Manager / SMA / WAP

This PowerShell script renames the Virtual Hard Disk of a VM. It's a common problem that the VHD name isn't changed during VM deployment by VMM. So to match the VHD name with the VM name and the computer name for consistency you've to run this script. The script works with both VM generations Gen 1 and Gen 2. **It renames only the VM boot disk.** PowerShell 3.0 and SC2012 SP1 VMM cmdlets or higher are required. For the SMA version you need additionally a Windows Azure Pack and Service Management Automation installation.

**Prerequisites for SMB 3.0 support:**

- On Hyper-V hosts: Enable-WSManCredSSP -Role Server -Force
- On VMM management server: Enable-WSManCredSSP -Role Client -DelegateComputer "Hyper-V host" -Force
- Grant the SCVMM service account full access on the file share (file share and folder permissions)!

For further information in German about this script have a look at my blog (Bing Translator Widget is available at the sidebar):

-> [https://www.danielstechblog.io/vhd-rename-powershell-script-version-3-1/](https://www.danielstechblog.io/vhd-rename-powershell-script-version-3-1/)

-> [https://www.danielstechblog.io/sma-powershell-workflow-vhd-rename/](https://www.danielstechblog.io/sma-powershell-workflow-vhd-rename/)

-> [https://www.danielstechblog.io/powershell-script-vhd-rename/](https://www.danielstechblog.io/powershell-script-vhd-rename/)

-> [https://www.danielstechblog.io/orchestrator-runbook-vhd-rename/](https://www.danielstechblog.io/orchestrator-runbook-vhd-rename/)

## History

- Version 4.0 (`Invoke-SCVHDRenameSMA.ps1`)
  - Support for SMB 3.0 file shares

- Version 3.1 (`Invoke-SCVHDRenameSMA.ps1`)
  - SMA PowerShell workflow version for WAP VM Cloud Automation Action

- Version 3.0.1 (`Invoke-SCVHDRenameSMA_3_0.ps1`)
  - Support for SMB 3.0 file shares

- Version 3.0 (`Invoke-SCVHDRenameSMA_3_0.ps1`)
  - SMA PowerShell workflow version

- Version 2.2 (`Invoke-SCVHDRename.ps1`)
  - Support for SMB 3.0 file shares

- Version 2.1 (`Invoke-SCVHDRename.ps1`)
  - Fixed an issue with differencing disks
  - Performance improvements

- Version 2.0
  - Removed support for Hyper-V Replica enabled VMs. Version 2.0 checks if Hyper-V Replica is enabled and will ignore the VM. Only VMs without Hyper-V Replica will be renamed.

- Version 1.0
  - Initial release
