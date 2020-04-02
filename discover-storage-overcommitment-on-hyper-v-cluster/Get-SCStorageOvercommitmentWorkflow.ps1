<#
    .SYNOPSIS
       Discover CSV & File Share Overcommitment.
    .DESCRIPTION
       Discover a CSV & File Share Overcommitment in the specified Cluster.
       Based on all CSV Volumes that are visible to the Cluster and File Shares that are assigned to the Cluster.
       Standard-based LUNs are not covered.
    .NOTES
        File Name : Get-SCStorageOvercommitment.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 SP1 Virtual Machine Manager PowerShell Cmdlets
                    System Center 2012 R2 Service Management Automation or Microsoft Azure Automation
        Version   : 4.0
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       You have to import this PowerShell script into your Service Management Automation environment or Microsoft Azure Automation account to use it.
       For further details visit https://www.danielstechblog.io/scvmm-storage-overcommitment-powershell-script-version-4-0
#>
workflow Get-SCStorageOvercommitmentWorkflow {
    $VMMServer = Get-AutomationVariable -Name 'VMM Server'
    $Credential = Get-AutomationPSCredential -Name 'VMM Server Credential'

    $SMTPServer = Get-AutomationVariable -Name 'SMTP Server'
    $EmailTo = Get-AutomationVariable -Name 'Email To'
    $EmailFrom = Get-AutomationVariable -Name 'Email From'

    InlineScript {
        #Getting information about the Hyper-V failover cluster and its CSVs and SMB 3.0 file shares for checkup
        $null = Get-SCVMMServer -ComputerName $USING:VMMServer -Credential $USING:Credential
        $CSVFSArray = @()
        $Clusters = Get-SCVMHostCluster

        foreach ($Cluster in $Clusters) {
            $CSVs = @()
            $FileShares = @()
            $Hosts = Get-SCVMHostCluster -Name $Cluster | Get-SCVMHost

            #CSV checkup
            foreach ($Hoster in $Hosts) {
                $CSVTemp = Get-SCStorageDisk -VMHost $Hoster | Where-Object { $_.DiskVolumes -like "C:\ClusterStorage\*" -and $_.ClusterDisk.OwnerNode -eq $_.VMHost }
                $CSVs += $CSVTemp
            }
            foreach ($CSV in $CSVs) {
                $CSVInfo = $CSV
                $OvercommitSpace = 0
                $Overcommited = "false"
                $VHDs = Get-SCVirtualHardDisk -All | Sort-Object -Property Location -Unique
                foreach ($VHD in $VHDs) {
                    $Volume = $CSVInfo.DiskVolumes.Name + "\*"
                    $VHD = $VHD | Where-Object { $_.Location -like $Volume -and $Hosts -contains $_.VMHost }
                    if ($VHD -ne $null) {
                        $Validation = Invoke-Command -ComputerName $VHD.VMHost -Credential $USING:Credential -ScriptBlock {
                            param($VHD)
                            Test-Path -Path $VHD.Location
                        } -ArgumentList $VHD
                        if ($Validation -eq $true) {
                            $OvercommitSpace = $OvercommitSpace + $VHD.MaximumSize
                        }

                    }
                }
                if ($CSVInfo.Capacity -le $OvercommitSpace) {
                    $Overcommited = "true"
                }
                $Info = New-Object PSObject -Property @{
                    Cluster                = $Cluster.Name
                    Type                   = 'Cluster Shared Volume'
                    Name                   = $CSV.ClusterDisk
                    Path                   = $CSVInfo.DiskVolumes.Name
                    Size                   = $CSVInfo.Capacity
                    FreeSpace              = $CSVInfo.AvailableCapacity
                    UsedSpace              = $CSVInfo.Capacity - $CSVInfo.AvailableCapacity
                    Overcommited           = $Overcommited
                    Overcommitment         = $OvercommitSpace
                    OvercommitedPercentage = ((($OvercommitSpace/1GB)/($CSVInfo.Capacity/1GB))*100) - 100
                }
                $CSVFSArray += $Info
            }

            $FileShares = Get-SCStorageFileShare -VMHostCluster $Cluster
            foreach ($FileShare in $FileShares) {
                $FSInfo = $FileShare
                $OvercommitSpace = 0
                $Overcommited = "false"
                $VHDs = Get-SCVirtualHardDisk -All | Sort-Object -Property Location -Unique
                foreach ($VHD in $VHDs) {
                    $Volume = $FSInfo.SharePath + "\*"
                    $VHD = $VHD | Where-Object { $_.Location -like $Volume -and $Hosts -contains $_.VMHost }
                    if ($VHD -ne $null) {
                        $Validation = Test-Path -Path $VHD.Location
                        if ($Validation -eq $true) {
                            $OvercommitSpace = $OvercommitSpace + $VHD.MaximumSize
                        }
                    }
                }
                if ($FSInfo.Capacity -le $OvercommitSpace) {
                    $Overcommited = "true"
                }
                $Info = New-Object PSObject -Property @{
                    Cluster                = $Cluster.Name
                    Type                   = "SMB 3.0 File Share"
                    Name                   = $FileShare.Name
                    Path                   = $FSInfo.SharePath
                    Size                   = $FSInfo.Capacity
                    FreeSpace              = $FSInfo.FreeSpace
                    UsedSpace              = $FSInfo.Capacity - $FSInfo.FreeSpace
                    Overcommited           = $Overcommited
                    Overcommitment         = $OvercommitSpace
                    OvercommitedPercentage = ((($OvercommitSpace/1GB)/($FSInfo.Capacity/1GB))*100) - 100
                }
                $CSVFSArray += $Info
            }
        }
        #Output
        $Date = Get-Date
        $Day = $Date.Day
        $Month = $Date.Month
        $Year = $Date.Year
        if (!(Test-Path -Path "C:\SCVMMStorageOvercommitmentReport")) {
            $null = New-Item -Path "C:\SCVMMStorageOvercommitmentReport" -ItemType Directory -Force
        }
        $CSVFSArray | Select-Object -Property Cluster, Type, Name, Path, @{Label = "Size(GB)"; Expression = { "{0:N2}" -f ($_.Size/1GB) } }, @{Label = "Free(GB)"; Expression = { "{0:N2}" -f ($_.FreeSpace/1GB) } }, @{Label = "Used(GB)"; Expression = { "{0:N2}" -f ($_.UsedSpace/1GB) } }, Overcommited, @{Label = "Effective Used(GB)"; Expression = { "{0:N2}" -f ($_.Overcommitment/1GB) } }, @{Label = "Overcommited %"; Expression = { "{0:N2}" -f ($_.OvercommitedPercentage) } } | Export-CSV -Path "C:\SCVMMStorageOvercommitmentReport\$Month-$Day-$Year.csv" -NoTypeInformation -Delimiter ";" -Force
        $Attachment = "C:\SCVMMStorageOvercommitmentReport\$Month-$Day-$Year.csv"
        Send-MailMessage -Attachments $Attachment -From $USING:EmailFrom -SmtpServer $USING:SMTPServer -Subject 'SCVMM Storage Overcommitment Report' -To $USING:EmailTo
        if (Test-Path -Path $Attachment) {
            Write-Output 'SCVMM Storage Overcommitment Report was processed successfully!'
        }
    }
}