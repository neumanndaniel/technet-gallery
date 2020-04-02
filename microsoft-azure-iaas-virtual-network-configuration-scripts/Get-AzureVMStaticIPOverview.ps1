<#
    .SYNOPSIS
       Shows the IP address information used by the Azure VMs in an Azure Virtual Network.
    .DESCRIPTION
       Shows the IP addresses information used by the Azure VMs in an Azure Virtual Network.
    .NOTES
        File Name : Get-AzureVMStaticIPOverview.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    Microsoft Azure PowerShell Cmdlets
                    Microsoft Azure ARM PowerShell Cmdlets
        Version   : 2.1
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Get-AzureVMStaticIPOverview

       Call the Azure VM Static IP Overview.
#>
function Get-AzureVMStaticIPOverview {
    #Buildin a Switch parameter for Azure Mode.
    param
    (
        [Parameter(Mandatory = $false)]
        [Switch]
        $AzureServiceManagement,
        [Parameter(Mandatory = $false)]
        [Switch]
        $AzureResourceManager
    )
    if ($AzureServiceManagement -eq $true) {
        $Array = @()
        $VMs = Get-AzureVM
        foreach ($VM in $VMs) {
            $IP = Get-AzureStaticVNetIP -VM $VM
            if (!($IP -eq $null)) {
                $temp = New-Object PSObject -Property @{
                    ServiceName      = $VM.ServiceName
                    VMName           = $VM.Name
                    StaticIPAddress  = $IP.IPAddress
                    DynamicIPAddress = ""
                    Subnet           = Get-AzureSubnet -VM $VM
                    VNET             = $VM.VirtualNetworkName
                }
                $Array += $temp
            }
            if ($IP -eq $null) {
                $temp = New-Object PSObject -Property @{
                    ServiceName      = $VM.ServiceName
                    VMName           = $VM.Name
                    StaticIPAddress  = ""
                    DynamicIPAddress = $VM.IpAddress
                    Subnet           = Get-AzureSubnet -VM $VM
                    VNET             = $VM.VirtualNetworkName
                }
                $Array += $temp
            }
        }
        $Array | Select-Object -Property ServiceName, VMName, DynamicIPAddress, StaticIPAddress, Subnet, VNET | Out-GridView -Title "Azure VM Static IP Address Overview"
    }
    if ($AzureResourceManager -eq $true) {
        $Array = @()
        $VMs = Get-AzureRmVM
        $VNETs = Get-AzureRmVirtualNetwork
        foreach ($VM in $VMs) {
            $NICs = $VM.NetworkInterfaceIDs
            foreach ($NIC in $NICs) {
                $NICName = $NIC -split "/"
                $NIC = Get-AzureRmNetworkInterface -Name $NICName[$NICName.Length - 1] -ResourceGroupName $VM.ResourceGroupName
                $IP = $NIC.IpConfigurations
                foreach ($VNET in $VNETs) {
                    $Subnets = $VNET.Subnets
                    foreach ($Subnet in $Subnets) {
                        if ($IP.Subnet.Id -eq $Subnet.ID) {
                            $TempSubnet = $Subnet.Name
                            $TempVNET = $VNET.Name
                            if (!($IP.PrivateIpAddress -eq $null)) {
                                $temp = New-Object PSObject -Property @{
                                    ResourceGroup = $VM.ResourceGroupName
                                    VMName        = $VM.Name
                                    NICName       = $NICName[$NICName.Length - 1]
                                    IPAddress     = $IP.PrivateIpAddress
                                    IPType        = $IP.PrivateIpAllocationMethod
                                    Subnet        = $TempSubnet
                                    VNET          = $TempVNET
                                }
                                $Array += $temp
                            }
                        }
                    }
                }
            }
        }
        $Array | Select-Object -Property ResourceGroup, VMName, NICName, IPAddress, IPType, Subnet, VNET | Out-GridView -Title "Azure VM IP Address Overview"
    }
    if ($AzureServiceManagement -eq $false -and $AzureResourceManager -eq $false) {
        Write-Output "Get-AzureVMStaticIPOverview -AzureServiceManagement"
        Write-Output "Get-AzureVMStaticIPOverview -AzureResourceManager"
    }
}