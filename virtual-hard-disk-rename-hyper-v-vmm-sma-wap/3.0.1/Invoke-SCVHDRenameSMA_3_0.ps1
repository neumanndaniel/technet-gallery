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
        File Name : Invoke-SCVHDRenameSMA.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    Windows Server 2012 Hyper-V PowerShell Cmdlets
                    System Center 2012 Virtual Machine Manager PowerShell Cmdlets
                    System Center 2012 R2 Service Management Automation
        Version   : 3.0.1
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
        You have to import this PowerShell script into your Service Management Automation environment to use it.
        For further details visit http://www.danielstechblog.de/sma-powershell-workflow-vhd-rename
#>
workflow Invoke-SCVHDRenameSMA {
    $Connection = Get-AutomationConnection -Name 'SCVMM Connect'
    $VMMServer = $Connection.ComputerName
    $Password = ConvertTo-SecureString $Connection.Password -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Connection.UserName, $Password

    #Get-VMs
    $VMs = InlineScript {
        $VMs = Get-SCVirtualMachine -VMMServer $Using:VMMServer | Where-Object { $_.CustomProperty.Custom1 -eq $null }
        Return $VMs
    } -PSComputerName $VMMServer -PSCredential $Credential



    foreach ($VM in $VMs) {
        InlineScript {
            $VM = Get-SCVirtualMachine -Name $Using:VM.Name
            $VMStatus = $VM.Status
            #Shutdown-VM
            if ($VMStatus -eq "Running") {
                $StopVM = Stop-SCVirtualMachine -VM $VM -Shutdown
            }
            #Gen1
            if ($VM.Generation -eq 1) {
                #Get Bootdisk
                $Disk = $VM.VirtualDiskDrives | Where-Object { $_.BusType -eq "IDE" -and $_.Bus -eq 0 -and $_.Lun -eq 0 }
                $VHD = $VM.VirtualHardDisks | Where-Object { $_.ID -eq $Disk.VirtualHardDiskId }
                #Check Replica & Credentials
                $ReplicationEnabled = Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
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
                    $VM.Name + ' OS Disk was not renamed! (Gen 1)'
                }
                #VHD Rename SMB 3.0
                if ($VHD.FileShare -ne $null -and $VHD.HostVolume -eq $null) {
                    Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
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
                    $VM.Name + ' OS Disk was renamed! (Gen 1)'
                }
                #VHD Rename
                else {
                    #Credentials
                    Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
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
                    $VM.Name + ' OS Disk was renamed! (Gen 1)'
                }
            }
            #Gen2
            if ($VM.Generation -eq 2) {
                #Get Bootdisk
                $Disk = $VM.VirtualDiskDrives | Where-Object { $_.BusType -eq "SCSI" -and $_.Bus -eq 0 -and $_.Lun -eq 0 }
                $VHD = $VM.VirtualHardDisks | Where-Object { $_.ID -eq $Disk.VirtualHardDiskId }
                #Check Replica
                $ReplicationEnabled = Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
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
                    $VM.Name + ' OS Disk was not renamed! (Gen 2)'
                }
                #VHD Rename SMB 3.0
                if ($VHD.FileShare -ne $null -and $VHD.HostVolume -eq $null) {
                    Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
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
                    $VM.Name + ' OS Disk was renamed! (Gen 2)'
                }
                #VHD Rename
                else {
                    Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
                        param($VM, $VHD)
                        if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                            $NewName = $VM.Name + ".vhdx"
                            $NewPath = $VHD.Directory + "\" + $NewName
                            Rename-Item -Path $VHD.Location -NewName $NewName
                            Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType SCSI -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                        }
                    } -ArgumentList $VM, $VHD
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
                    $VM.Name + ' OS Disk was renamed! (Gen 2)'
                }
            }
        } -PSComputerName $VMMServer -PSCredential $Credential
    }
}