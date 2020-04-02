<#
    .SYNOPSIS
       Converts the VM differencing boot disk to a VM dynamic boot disk.
    .DESCRIPTION
       Converts the VM differencing boot disk to a VM dynamic boot disk.
       Works with Generation 1 and Generation 2 VMs.
       VMs with Hyper-V Replica enabled will be ignored.

       Prerequisites for SMB 3.0 support:
       On Hyper-V hosts:         Enable-WSManCredSSP -Role Server -Force
       On VMM management server: Enable-WSManCredSSP -Role Client -DelegateComputer "Hyper-V host" -Force
       Grant the SCVMM service account full access on the file share (file share and folder permissions)!
    .NOTES
        File Name : Invoke-SCVHDDiffConvert.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    Windows Server 2012 Hyper-V PowerShell Cmdlets
                    System Center 2012 Virtual Machine Manager PowerShell Cmdlets
                    System Center 2012 R2 Service Management Automation
        Version   : 2.0
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
        You have to import this PowerShell script into your Service Management Automation environment to use it.
        For further details visit http://www.danielstechblog.de/sma-runbook-convert-wap-vm-role-os-differencing-disk
#>
workflow Invoke-SCVHDDiffConvert {
    $Connection = Get-AutomationConnection -Name 'SCVMM Connect'
    $VMMServer = $Connection.ComputerName
    $Password = ConvertTo-SecureString $Connection.Password -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Connection.UserName, $Password

    $VMMJobId = $PSPrivateMetaData.VMMJobId

    $Result = InlineScript {
        Get-SCVMMServer -ComputerName $USING:VMMServer -Credential $USING:Credential
        While ((Get-SCJob -ID $USING:VMMJobId).Status -eq 'Running') {
            $Progress = (Get-SCJob -ID $USING:VMMJobId).ProgressValue
            Start-Sleep -Seconds 3
        }

        $Result = (Get-SCJob -ID $USING:VMMJobId).Status
        Return $Result
    }

    if ($Result.Value -eq 'Completed') {
        $VMName = $PSPrivateMetaData.params
        $PSPMDName = $PSPrivateMetaData.Name
        $VMName = InlineScript {
            if ($Using:PSPMDName -eq 'MicrosoftCompute.VMRole') {
                $SCJob = Get-SCJob -ID $Using:VMMJobId
                $CloudResource = Get-CloudResource -Id $SCJob.ResultObjectID
                $CloudVM = $CloudResource.VMs | Where-Object { $_.CustomProperty.Custom2 -eq $null }
                $VMName = $CloudVM
                Return $VMName
            }
            if ($Using:PSPMDName -eq 'VMM.VirtualMachine') {
                $VMName = $Using:VMName -split (',') -replace ('"', '') -replace ('{', '') -replace ('}', '')
                $VMName = $VMName | Where-object { $_ -like "Name*" } | Where-Object { $_ -ne "Name:null" }
                $VMName = ($VMName -split (':'))[1]
                Return $VMName
            }
        }

        InlineScript {
            $ConnectVMMServer = Get-SCVMMServer -ComputerName $USING:VMMServer -Credential $USING:Credential
            foreach ($VM in $Using:VMName) {
                $VM = Get-SCVirtualMachine -Name $VM
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
                        $VM.Name + ' Differencing OS Disk was not converted! (Gen 1)'
                    }
                    #VHD Convert SMB 3.0
                    if ($VHD.FileShare -ne $null -and $VHD.HostVolume -eq $null) {
                        if ($VHD.VHDType -eq "Differencing") {
                            $SCJob = New-SCExternalJob -VMMServer $USING:VMMServer -Name 'Converting differencing virtual hard disk' -ResultObject $VM
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -ProgressValue 50
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Credentials
                            Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
                                param($VM, $VHD)
                                if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                                    $NewName = $VM.Name + ".vhdx"
                                    $NewPath = $VHD.Directory + "\" + $NewName
                                    $Convert = Convert-VHD -Path $VHD.Location -DestinationPath $NewPath -VHDType Dynamic -DeleteSource
                                    $Set = Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                                }
                                if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhd") {
                                    $NewName = $VM.Name + ".vhd"
                                    $NewPath = $VHD.Directory + "\" + $NewName
                                    $Convert = Convert-VHD -Path $VHD.Location -DestinationPath $NewPath -VHDType Dynamic -DeleteSource
                                    $Set = Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                                }
                            } -ArgumentList $VM, $VHD -Authentication Credssp
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -Completed
                            #VM Refresh
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #VM Update
                            $CP1 = Get-SCCustomProperty -Name Custom1
                            $CP2 = Get-SCCustomProperty -Name Custom2
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP2 -Value "Differencing boot disk was converted" -InputObject $VM
                            $SetStopAction = Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Start VM
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was converted and renamed! (Gen 1)'
                        }
                        else {
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was not converted! (Gen 1)'
                        }
                    }
                    #VHD Convert
                    else {
                        if ($VHD.VHDType -eq "Differencing") {
                            $SCJob = New-SCExternalJob -VMMServer $USING:VMMServer -Name 'Converting differencing virtual hard disk' -ResultObject $VM
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -ProgressValue 50
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Credentials
                            Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
                                param($VM, $VHD)
                                if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                                    $NewName = $VM.Name + ".vhdx"
                                    $NewPath = $VHD.Directory + "\" + $NewName
                                    $Convert = Convert-VHD -Path $VHD.Location -DestinationPath $NewPath -VHDType Dynamic -DeleteSource
                                    $Set = Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                                }
                                if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhd") {
                                    $NewName = $VM.Name + ".vhd"
                                    $NewPath = $VHD.Directory + "\" + $NewName
                                    $Convert = Convert-VHD -Path $VHD.Location -DestinationPath $NewPath -VHDType Dynamic -DeleteSource
                                    $Set = Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType IDE -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                                }
                            } -ArgumentList $VM, $VHD
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -Completed
                            #VM Refresh
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #VM Update
                            $CP1 = Get-SCCustomProperty -Name Custom1
                            $CP2 = Get-SCCustomProperty -Name Custom2
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP2 -Value "Differencing boot disk was converted" -InputObject $VM
                            $SetStopAction = Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Start VM
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was converted and renamed! (Gen 1)'
                        }
                        else {
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was not converted! (Gen 1)'
                        }
                    }
                }
                #Gen2
                if ($VM.Generation -eq 2) {
                    #Get Bootdisk
                    $Disk = $VM.VirtualDiskDrives | Where-Object { $_.BusType -eq "SCSI" -and $_.Bus -eq 0 -and $_.Lun -eq 0 }
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
                        $VM.Name + ' Differencing OS Disk was not converted! (Gen 2)'
                    }
                    #VHD Convert SMB 3.0
                    if ($VHD.FileShare -ne $null -and $VHD.HostVolume -eq $null) {
                        if ($VHD.VHDType -eq "Differencing") {
                            $SCJob = New-SCExternalJob -VMMServer $USING:VMMServer -Name 'Converting differencing virtual hard disk' -ResultObject $VM
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -ProgressValue 50
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Credentials
                            Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
                                param($VM, $VHD)
                                if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                                    $NewName = $VM.Name + ".vhdx"
                                    $NewPath = $VHD.Directory + "\" + $NewName
                                    $Convert = Convert-VHD -Path $VHD.Location -DestinationPath $NewPath -VHDType Dynamic -DeleteSource
                                    $Set = Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType SCSI -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                                }
                            } -ArgumentList $VM, $VHD -Authentication Credssp
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -Completed
                            #VM Refresh
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #VM Update
                            $CP1 = Get-SCCustomProperty -Name Custom1
                            $CP2 = Get-SCCustomProperty -Name Custom2
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP2 -Value "Differencing boot disk was converted" -InputObject $VM
                            $SetStopAction = Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Start VM
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was converted and renamed! (Gen 2)'
                        }
                        else {
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was not converted! (Gen 2)'
                        }
                    }
                    #VHD Convert
                    else {
                        if ($VHD.VHDType -eq "Differencing") {
                            $SCJob = New-SCExternalJob -VMMServer $USING:VMMServer -Name 'Converting differencing virtual hard disk' -ResultObject $VM
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -ProgressValue 50
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Credentials
                            Invoke-Command -ComputerName $VM.HostName -Credential $Using:Credential -ScriptBlock {
                                param($VM, $VHD)
                                if ((Test-Path -Path $VHD.Location) -and $VHD.Location -like "*.vhdx") {
                                    $NewName = $VM.Name + ".vhdx"
                                    $NewPath = $VHD.Directory + "\" + $NewName
                                    $Convert = Convert-VHD -Path $VHD.Location -DestinationPath $NewPath -VHDType Dynamic -DeleteSource
                                    $Set = Set-VMHardDiskDrive -ComputerName $VM.HostName  -VMName $VM.Name -ControllerType SCSI -Path $NewPath -ControllerNumber 0 -ControllerLocation 0 -AllowUnverifiedPaths -ErrorAction SilentlyContinue
                                }
                            } -ArgumentList $VM, $VHD
                            $SCJobUpdate = Set-SCExternalJob -Job $SCJob -Completed
                            #VM Refresh
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #VM Update
                            $CP1 = Get-SCCustomProperty -Name Custom1
                            $CP2 = Get-SCCustomProperty -Name Custom2
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP1 -Value "Boot disk was renamed" -InputObject $VM
                            $SetCP = Set-SCCustomPropertyValue -CustomProperty $CP2 -Value "Differencing boot disk was converted" -InputObject $VM
                            $SetStopAction = Set-SCVirtualMachine -StopAction ShutdownGuestOS -VM $VM
                            $UpdateVM = Read-SCVirtualMachine -VM $VM
                            #Start VM
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was converted and renamed! (Gen 2)'
                        }
                        else {
                            if ($VMStatus -eq "Running") {
                                $StartVM = Start-SCVirtualMachine -VM $VM
                            }
                            $VM.Name + ' Differencing OS Disk was not converted! (Gen 2)'
                        }
                    }
                }
            }
        }
    }
}