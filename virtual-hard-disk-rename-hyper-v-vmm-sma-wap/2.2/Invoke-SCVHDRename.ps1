<#
    .SYNOPSIS
       Renames VM boot disk to match VM name and computer name.
    .DESCRIPTION
       Renames VM boot disk to match VM name and computer name.
       Works with Generation 1 and Generation 2 VMs.
       Custom Property 1 must be empty to invoke the VMs for renaming.
       VMs with Hyper-V Replica enabled will be ignored.

       Prerequisites for SMB 3.0 support:
       On Hyper-V hosts:         Enable-WSManCredSSP -Role Server -Force
       On VMM management server: Enable-WSManCredSSP -Role Client -DelegateComputer "Hyper-V host" -Force
       Grant the SCVMM service account full access on the file share (file share and folder permissions)!
    .NOTES
        File Name : Invoke-SCVHDRename.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    Windows Server 2012 Hyper-V PowerShell Cmdlets
                    System Center 2012 Virtual Machine Manager PowerShell Cmdlets
        Version   : 2.2
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Invoke-SCVHDRename -VMMServer vmmserver.demo.local

       Call with the FQDN of the VMM Management Server.
    .EXAMPLE
       Invoke-SCVHDRename -VMMServer vmmserver

       Call with the name of the VMM Management Server.
#>
function Invoke-SCVHDRename {
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'VMM Server')]
        [String]
        $VMMServer
    )

    #Get-VMs
    $VMs = Get-SCVirtualMachine -VMMServer $VMMServer | Where-Object { $_.CustomProperty.Custom1 -eq $null }
    foreach ($VM in $VMs) {
        $VMStatus = $VM.Status
        #Shutdown-VM
        if ($VMStatus -eq "Running") {
            Stop-SCVirtualMachine -VM $VM -Shutdown
        }
        #Gen1
        if ($VM.Generation -eq 1) {
            #Get Bootdisk
            $Disk = $VM.VirtualDiskDrives | Where-Object { $_.BusType -eq "IDE" -and $_.Bus -eq 0 -and $_.Lun -eq 0 }
            $VHD = $VM.VirtualHardDisks | Where-Object { $_.ID -eq $Disk.VirtualHardDiskId }
            #Check Replica
            $ReplicationEnabled = Invoke-Command -ComputerName $VM.HostName -ScriptBlock {
                param ($VM)
                if (Get-VMReplication -ComputerName $VM.HostName -VMName $VM.Name -ErrorAction SilentlyContinue) {
                    $ReplicationEnabled = "true"
                    $ReplicationEnabled
                }
            } -ArgumentList $VM
            #Skip VM when Hyper-V Replica is enabled
            if ($ReplicationEnabled -eq "true") {
                if ($VMStatus -eq "Running") {
                    $StartVM = Start-SCVirtualMachine -VM $VM
                }
            }
            #VHD Rename SMB 3.0
            if ($VHD.FileShare -ne $null -and $VHD.HostVolume -eq $null) {
                Invoke-Command -ComputerName $VM.HostName -ScriptBlock {
                    param($VM, $VHD)
                    if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                        $NewName = $VM.Name + ".vhdx"
                        $NewPath = $VHD.Directory + "\" + $NewName
                        Rename-Item -Path $VHD.Location -NewName $NewName
                        Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                    }
                    if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhd") {
                        $NewName = $VM.Name + ".vhd"
                        $NewPath = $VHD.Directory + "\" + $NewName
                        Rename-Item -Path $VHD.Location -NewName $NewName
                        Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                    }
                } -ArgumentList $VM, $VHD -Authentication Credssp
                #VM Refresh
                $UpdateVM = Read-SCVirtualMachine -VM $VM
                #VM Update
                $CP1 = Get-SCCustomProperty -Name Custom1
                $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                $SetStopAction = Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                $UpdateVM = Read-SCVirtualMachine -VM $VM
                #Start VM
                if ($VMStatus -eq "Running") {
                    $StartVM = Start-SCVirtualMachine -VM $VM
                }
            }
            #VHD Rename
            else {
                Invoke-Command -ComputerName $VM.HostName -ScriptBlock {
                    param($VM, $VHD)
                    if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                        $NewName = $VM.Name + ".vhdx"
                        $NewPath = $VHD.Directory + "\" + $NewName
                        Rename-Item -Path $VHD.Location -NewName $NewName
                        Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                    }
                    if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhd") {
                        $NewName = $VM.Name + ".vhd"
                        $NewPath = $VHD.Directory + "\" + $NewName
                        Rename-Item -Path $VHD.Location -NewName $NewName
                        Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                    }
                } -ArgumentList $VM, $VHD
                #VM Refresh
                Read-SCVirtualMachine -VM $VM
                #VM Update
                $CP1 = Get-SCCustomProperty -Name Custom1
                Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                Read-SCVirtualMachine -VM $VM
                #Start VM
                if ($VMStatus -eq "Running") {
                    Start-SCVirtualMachine -VM $VM
                }
            }
        }
        #Gen2
        if ($VM.Generation -eq 2) {
            #Get Bootdisk
            $Disk = $VM.VirtualDiskDrives | Where-Object { $_.BusType -eq "SCSI" -and $_.Bus -eq 0 -and $_.Lun -eq 0 }
            $VHD = $VM.VirtualHardDisks | Where-Object { $_.ID -eq $Disk.VirtualHardDiskId }
            #Check Replica
            $ReplicationEnabled = Invoke-Command -ComputerName $VM.HostName -ScriptBlock {
                param ($VM)
                if (Get-VMReplication -ComputerName $VM.HostName -VMName $VM.Name -ErrorAction SilentlyContinue) {
                    $ReplicationEnabled = "true"
                    $ReplicationEnabled
                }
            } -ArgumentList $VM
            #Skip VM when Hyper-V Replica is enabled
            if ($ReplicationEnabled -eq "true") {
                if ($VMStatus -eq "Running") {
                    $StartVM = Start-SCVirtualMachine -VM $VM
                }
            }
            #VHD Rename SMB 3.0
            if ($VHD.FileShare -ne $null -and $VHD.HostVolume -eq $null) {
                Invoke-Command -ComputerName $VM.HostName -ScriptBlock {
                    param($VM, $VHD)
                    if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                        $NewName = $VM.Name + ".vhdx"
                        $NewPath = $VHD.Directory + "\" + $NewName
                        Rename-Item -Path $VHD.Location -NewName $NewName
                        Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType SCSI -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                    }
                } -ArgumentList $VM, $VHD -Authentication Credssp
                #VM Refresh
                $UpdateVM = Read-SCVirtualMachine -VM $VM
                #VM Update
                $CP1 = Get-SCCustomProperty -Name Custom1
                $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                $SetStopAction = Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                $UpdateVM = Read-SCVirtualMachine -VM $VM
                #Start VM
                if ($VMStatus -eq "Running") {
                    $StartVM = Start-SCVirtualMachine -VM $VM
                }
            }
            #VHD Rename
            else {
                Invoke-Command -ComputerName $VM.HostName -ScriptBlock {
                    param($VM, $VHD)
                    if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                        $NewName = $VM.Name + ".vhdx"
                        $NewPath = $VHD.Directory + "\" + $NewName
                        Rename-Item -Path $VHD.Location -NewName $NewName
                        Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType SCSI -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                    }
                } -ArgumentList $VM, $VHD
                #VM Refresh
                Read-SCVirtualMachine -VM $VM
                #VM Update
                $CP1 = Get-SCCustomProperty -Name Custom1
                Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                Read-SCVirtualMachine -VM $VM
                #Start VM
                if ($VMStatus -eq "Running") {
                    Start-SCVirtualMachine -VM $VM
                }
            }
        }
    }
}