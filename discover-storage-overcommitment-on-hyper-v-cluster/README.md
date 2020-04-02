# Discover storage overcommitment on Hyper-V Cluster

This PowerShell script discovers a CSV / SMB 3.0 file share overcommitment in the specified Hyper-V cluster. It calculates it for all CSV volumes that are visible to the Hyper-V cluster and for all SMB 3.0 file shares that are assigned to the Hyper-V cluster. PowerShell 3.0 and SC2012 SP1 VMM cmdlets or higher are required.

The script output is as the following:

```txt
Type: Storage type

Name: Name of CSV volume

Path: Path to CSV volume on Hyper-V host.

Size(GB): Capacity of the CSV volume

Free(GB): Free diskspace on the CSV volume

Used(GB): Used diskspace on the CSV volume

Overcommited: true or false

Effective Used(GB): If you are using dynamic VHD/VHDX disks this value differs from Used(GB) and has a higher value. If you are only using fixed VHD/VHDX disks this value equals the value from Used(GB).

Overcommited %: A negative value e.g. -40,00 indicates that you have 40% diskspace left before your CSV volume runs into a overcommitment. A positive value e.g. 20,00 indicates that your CSV volume has a overcommitment of 20%.

Testing enabled: true or false
```

For more details on version 4.0 visit [https://www.danielstechblog.io/scvmm-storage-overcommitment-powershell-script-version-4-0](https://www.danielstechblog.io/scvmm-storage-overcommitment-powershell-script-version-4-0)

## History

- Version 4.0 (Get-SCStorageOvercommitmentWorkflow.ps1)
  - Multiple Hyper-V cluster support
  - SMA PowerShell workflow version
  - Azure Automation PowerShell workflow version

- Version 3.4 (Get-SCStorageOvercommitment.ps1)
  - Multiple Hyper-V cluster support

- Version 3.3
  - Fixed duplicated SMB 3.0 file share output

- Version 3.2
  - Added support for SMB 3.0 file shares managed by VMM
  - Added advanced testing mode for a better accuracy
  - Minor output changes

- Version 3.1
  - Added support for multiple Hyper-V clusters with the same CSV names

- Version 3.0
  - Added support for Shared VHDX
  - Performance improvements

- Version 2.0
  - Support for CSV paths from C:\ClusterStorage\Volume10 and up
  - Support for VMs whose VHDs resides on different CSVs
  - Completely based on the VMM PowerShell Cmdlets

- Version 1.0
  - Initial release
