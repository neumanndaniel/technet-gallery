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
        Version   : 3.4
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Get-SCStorageOvercommitment -VMMServer vmmserver.demo.local

       Call with the FQDN of the VMM Management Server.
    .EXAMPLE
       Get-SCStorageOvercommitment -VMMServer vmmserver.demo.local -Testing

       Call with the FQDN of the VMM Management Server and testing switch
#>
function Get-SCStorageOvercommitment {
    #Buildin a Switch parameter if checking for VHD disk existing should be set. Default is disabled.
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'VMM Server')]
        [String]
        $VMMServer,
        [Parameter(Mandatory = $false, HelpMessage = 'Tests if VHD exist on storage')]
        [Switch]
        $Testing
    )
    #Getting information about the Hyper-V failover cluster and its CSVs and SMB 3.0 file shares for checkup
    $CSVFSArray = @()
    $Clusters = Get-SCVMHostCluster -VMMServer $VMMServer | Out-GridView -PassThru -Title "Select Cluster for CSV / FS Overcommitment Analyzing"
    $i = 0
    foreach ($Cluster in $Clusters) {
        $CSVs = @()
        $FileShares = @()
        $Hosts = Get-SCVMHostCluster -VMMServer $VMMServer -Name $Cluster | Get-SCVMHost

        #CSV checkup
        foreach ($Hoster in $Hosts) {
            $CSVTemp = Get-SCStorageDisk -VMHost $Hoster | Where-Object { $_.DiskVolumes -like "C:\ClusterStorage\*" -and $_.ClusterDisk.OwnerNode -eq $_.VMHost }
            $CSVs += $CSVTemp
        }

        foreach ($CSV in $CSVs) {
            Write-Progress -Activity "In Progress" -PercentComplete $i
            $CSVInfo = $CSV
            $OvercommitSpace = 0
            $Overcommited = "false"
            $VHDs = Get-SCVirtualHardDisk -All -VMMServer $VMMServer | Sort-Object -Property Location -Unique
            foreach ($VHD in $VHDs) {
                $Volume = $CSVInfo.DiskVolumes.Name + "\*"
                $VHD = $VHD | Where-Object { $_.Location -like $Volume -and $Hosts -contains $_.VMHost }
                if ($VHD -ne $null) {
                    if ($Testing -eq $true) {
                        $Validation = Invoke-Command -ComputerName $VHD.VMHost -ScriptBlock {
                            param($VHD)
                            Test-Path -Path $VHD.Location
                        } -ArgumentList $VHD
                        if ($Validation -eq $true) {
                            $OvercommitSpace = $OvercommitSpace + $VHD.MaximumSize
                        }
                    }
                    else {
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
                TestingEnabled         = $Testing
            }
            $CSVFSArray += $Info
        }

        $FileShares = Get-SCStorageFileShare -VMHostCluster $Cluster

        foreach ($FileShare in $FileShares) {
            Write-Progress -Activity "In Progress" -PercentComplete $i
            $FSInfo = $FileShare
            $OvercommitSpace = 0
            $Overcommited = "false"
            $VHDs = Get-SCVirtualHardDisk -All -VMMServer $VMMServer | Sort-Object -Property Location -Unique
            foreach ($VHD in $VHDs) {
                $Volume = $FSInfo.SharePath + "\*"
                $VHD = $VHD | Where-Object { $_.Location -like $Volume -and $Hosts -contains $_.VMHost }
                if ($VHD -ne $null) {
                    if ($Testing -eq $true) {
                        $Validation = Test-Path -Path $VHD.Location
                        if ($Validation -eq $true) {
                            $OvercommitSpace = $OvercommitSpace + $VHD.MaximumSize
                        }
                    }
                    else {
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
                TestingEnabled         = $Testing
            }
            $CSVFSArray += $Info
        }
        $i = $i + (100/$Clusters.Length)
    }
    #Output
    $CSVFSArray | Select-Object -Property Cluster, Type, Name, Path, @{Label = "Size(GB)"; Expression = { "{0:N2}" -f ($_.Size/1GB) } }, @{Label = "Free(GB)"; Expression = { "{0:N2}" -f ($_.FreeSpace/1GB) } }, @{Label = "Used(GB)"; Expression = { "{0:N2}" -f ($_.UsedSpace/1GB) } }, Overcommited, @{Label = "Effective Used(GB)"; Expression = { "{0:N2}" -f ($_.Overcommitment/1GB) } }, @{Label = "Overcommited %"; Expression = { "{0:N2}" -f ($_.OvercommitedPercentage) } }, @{Label = "Testing enabled"; Expression = { $_.TestingEnabled } } | Out-GridView -Title "CSV-FS-Overcommitment-Status"
}