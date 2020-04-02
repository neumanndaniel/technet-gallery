<#
    .SYNOPSIS
       Check your Azure storage accounts performance health state.
    .DESCRIPTION
       Check your Azure storage accounts performance health state.
       The Power Shell script checks the current storage performance and
       usage of all Azure storage accounts in one Azure subscription.

       For more details visit the following blog article to get more insights about this script.
       -> https://www.danielstechblog.io/azure-storage-performance-health-check-script/
    .NOTES
        File Name : Get-AzureRmStoragePerformanceHealth.ps1
        Author    : Daniel Neumann
        Requires  : AzureRm PowerShell Cmdlets
        Version   : 1.5
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Get-AzureRmStoragePerformanceHealth

       Runs the script.
#>
#Azure login
$azureEnvironment = Get-AzureRmEnvironment | Out-GridView -Title "Select the Azure environment" -PassThru

$null = Login-AzureRmAccount -EnvironmentName $azureEnvironment.Name

$subscription = Get-AzureRmSubscription | Out-GridView -Title "Select the Azure subscription" -PassThru
$null = Select-AzureRmSubscription -SubscriptionId $subscription.Id -Verbose

#Variables
$P10 = 0
$P20 = 0
$P30 = 0
$P40 = 0
$P50 = 0
$PremiumStorageMaxGbps = 0
$StandardDisks = 0
$P10Size = 128
$P20Size = 512
$P30Size = 1024
$P40Size = 2048
$P50Size = 4095
$PremiumStorageLimitGB = 35840
$PremiumStorageLimitGbps = 50
$StandardStorageLimitIOPS = 20000
$StandardStorageLimitDisks = 40
$StandardOutputArray = @()
$PremiumOutputArray = @()

$VMs = @{
    Standard_B1s     = 10;
    Standard_B1ms    = 10;
    Standard_B2s     = 15;
    Standard_B2ms    = 23;
    Standard_B4ms    = 35;
    Standard_B8ms    = 50;
    Standard_DS1     = 32;
    Standard_DS2     = 64;
    Standard_DS3     = 128;
    Standard_DS4     = 256;
    Standard_DS11    = 64;
    Standard_DS12    = 128;
    Standard_DS13    = 256;
    Standard_DS14    = 512;
    Standard_DS1_v2  = 48;
    Standard_DS2_v2  = 96;
    Standard_DS3_v2  = 192;
    Standard_DS4_v2  = 384;
    Standard_DS5_v2  = 768;
    Standard_DS11_v2 = 96;
    Standard_DS12_v2 = 192;
    Standard_DS13_v2 = 384;
    Standard_DS14_v2 = 768;
    Standard_DS15_v2 = 960;
    Standard_D2s_v3  = 48;
    Standard_D4s_v3  = 96;
    Standard_D8s_v3  = 192;
    Standard_D16s_v3 = 384;
    Standard_D32s_v3 = 768;
    Standard_D64s_v3 = 1200;
    Standard_E2s_v3  = 48;
    Standard_E4s_v3  = 96;
    Standard_E8s_v3  = 192;
    Standard_E16s_v3 = 384;
    Standard_E32s_v3 = 768;
    Standard_E64s_v3 = 1200;
    Standard_F1s     = 48;
    Standard_F2s     = 96;
    Standard_F4s     = 192;
    Standard_F8s     = 384;
    Standard_F16s    = 768;
    Standard_GS1     = 125;
    Standard_GS2     = 250;
    Standard_GS3     = 500;
    Standard_GS4     = 1000;
    Standard_GS5     = 2000;
    Standard_L4s     = 125;
    Standard_L8s     = 250;
    Standard_L16s    = 500;
    Standard_L32s    = 1000;
    Standard_M64s    = 1000;
    Standard_M64ms   = 1000;
    Standard_M128s   = 2000;
}

#Standard Storage Accounts
$StandardStorageAccounts = Get-AzureRmStorageAccount | Where-Object { $_.Sku.Tier -eq "Standard" }
foreach ($StandardStorageAccount in $StandardStorageAccounts) {
    $StandardVHDs = Get-AzureStorageBlob -Context $StandardStorageAccount.Context -Container vhds -ErrorAction SilentlyContinue | Where-Object { $_.BlobType -eq "PageBlob" }
    $StandardDisks = 0
    foreach ($StandardVHD in $StandardVHDs) {
        $StandardDisks += 1
    }
    $Info = New-Object PSObject -Property @{
        Name                 = $StandardStorageAccount.StorageAccountName
        Type                 = $StandardStorageAccount.Sku.Tier
        CurrentNumberOfDisks = $StandardDisks
        MaxNumberOfDisks     = $StandardStorageLimitDisks
        NumberOfDisksStatus  = if (($StandardDisks) -gt $StandardStorageLimitDisks) { "WARNING" }else { "OK" }
        CurrentIOPS          = 500*$StandardDisks
        MaxIOPS              = $StandardStorageLimitIOPS
        PerformanceStatus    = if ((500*$StandardDisks) -gt $StandardStorageLimitIOPS) { "WARNING" }else { "OK" }
    }
    $StandardOutputArray += $Info
}
$StandardOutputArray | Select-Object -Property Name, Type, @{Label = "Current number of disks"; Expression = { "{0:N0}" -f ($_.CurrentNumberOfDisks) } }, @{Label = "Disk limit"; Expression = { "{0:N0}" -f ($_.MaxNumberOfDisks) } }, @{Label = "Disk status"; Expression = { "{0:N2}" -f ($_.NumberOfDisksStatus) } }, @{Label = "Current IOPS usage"; Expression = { "{0:N0}" -f ($_.CurrentIOPS) } }, @{Label = "IOPS limit"; Expression = { "{0:N0}" -f ($_.MaxIOPS) } }, @{Label = "IOPS status"; Expression = { "{0:N2}" -f ($_.PerformanceStatus) } } | Out-GridView -Title "Standard storage performance status"

#Premium Storage Accounts
$PremiumStorageAccounts = Get-AzureRmStorageAccount | Where-Object { $_.Sku.Tier -eq "Premium" }
foreach ($PremiumStorageAccount in $PremiumStorageAccounts) {
    $PremiumVHDs = Get-AzureStorageBlob -Context $PremiumStorageAccount.Context -Container vhds -ErrorAction SilentlyContinue | Where-Object { $_.BlobType -eq "PageBlob" }
    $P10 = 0
    $P20 = 0
    $P30 = 0
    $P40 = 0
    $P50 = 0
    $PremiumStorageMaxGbps = 0
    $PremiumVMs = Get-AzureRmVM -WarningAction SilentlyContinue | Where-Object { $VMs.keys -ccontains $_.HardwareProfile.VmSize }
    foreach ($PremiumVHD in $PremiumVHDs) {
        $PDisk = 0
        #Checking for DataDisks integration pending
        foreach ($PremiumVM in $PremiumVMs) {
            if ($PremiumVHD.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri -eq $PremiumVM.StorageProfile.OsDisk.Vhd.Uri) {
                $VMsize = $PremiumVM.HardwareProfile.VMsize
                $PremiumStorageMaxGbps += $VMs.$VMsize
            }
            if ($PremiumVM.StorageProfile.DataDisks.Count -ne 0) {
                $DataDisks = $PremiumVM.StorageProfile.DataDisks
                foreach ($DataDisk in $DataDisks) {
                    if ($PremiumVHD.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri -eq $DataDisk.Vhd.Uri -and ($PremiumVM.StorageProfile.OsDisk.vhd.Uri -split "/")[2] -ne ($DataDisk.Vhd.Uri -split "/")[2]) {
                        $VMsize = $PremiumVM.HardwareProfile.VMsize
                        $PremiumStorageMaxGbps += $VMs.$VMsize
                    }
                }
            }
        }

        $PDisk = [math]::Round($PremiumVHD.Length/1GB)

        if ($PDisk -le 128) {
            $P10 += 1
        }
        elseif ($PDisk -gt 128 -and $PDisk -le 512) {
            $P20 += 1
        }
        elseif ($PDisk -gt 512 -and $PDisk -le 1024) {
            $P30 += 1
        }
        elseif ($PDisk -gt 1024 -and $PDisk -le 2048) {
            $P40 += 1
        }
        else {
            $P50 += 1
        }
    }
    $Info = New-Object PSObject -Property @{
        Name                        = $PremiumStorageAccount.StorageAccountName
        Type                        = $PremiumStorageAccount.Sku.Tier
        EstimateThroughput          = ($PremiumStorageMaxGbps*8)/1000
        MaxThroughput               = $PremiumStorageLimitGbps
        PerformanceStatusThroughput = if ((($PremiumStorageMaxGbps*8)/1000) -gt $PremiumStorageLimitGbps) { "WARNING" }else { "OK" }
        EstimateStorageUsage        = ($P10*$P10Size) + ($P20*$P20Size) + ($P30*$P30Size) + ($P40*$P40Size) + ($P50*$P50Size)
        MaxStorageUsage             = $PremiumStorageLimitGB
        PerformanceStatusUsage      = if ((($P10*$P10Size) + ($P20*$P20Size) + ($P30*$P30Size) + ($P40*$P40Size) + ($P50*$P50Size)) -gt $PremiumStorageLimitGB) { "WARNING" }else { "OK" }
    }
    $PremiumOutputArray += $Info
}
$PremiumOutputArray | Select-Object -Property Name, Type, @{Label = "Current throughput estimate in Gbps"; Expression = { "{0:N2}" -f ($_.EstimateThroughput) } }, @{Label = "Throughput limit in Gbps"; Expression = { "{0:N0}" -f ($_.MaxThroughput) } }, @{Label = "Throughput status"; Expression = { "{0:N2}" -f ($_.PerformanceStatusThroughput) } }, @{Label = "Current storage estimate in GB"; Expression = { "{0:N0}" -f ($_.EstimateStorageUsage) } }, @{Label = "Storage limit in GB"; Expression = { "{0:N0}" -f ($_.MaxStorageUsage) } }, @{Label = "Storage status"; Expression = { "{0:N2}" -f ($_.PerformanceStatusUsage) } } | Out-GridView -Title "Premium storage performance status"