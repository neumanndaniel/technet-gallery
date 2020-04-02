<#
    .SYNOPSIS
       Sets another VM Subnet for an Azure VM in an Azure Virtual Network.
    .DESCRIPTION
       Sets another VM Subnet for an Azure VM in an Azure Virtual Network.
    .NOTES
        File Name : Set-AzureVMSubnet.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    Microsoft Azure PowerShell Cmdlets
                    Microsoft Azure ARM PowerShell Cmdlets
        Version   : 2.1
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Set-AzureVMSubnet.ps1

       Set the Azure VM Subnet.
#>
function Set-AzureVMSubnet {
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
        $VM = Get-AzureVM | Out-GridView -PassThru -Title "Azure Virtual Machines"
        $VirtualSubnetVM = Get-AzureSubnet -VM $VM
        $Temp = Get-AzureVNetSite | Select-Object Name, AddressSpacePrefixes, Subnets | Out-GridView -PassThru -Title "Azure Virtual Networks"
        $VirtualNetwork = Get-AzureVNetSite -VNetName $Temp.Name
        if (($VirtualNetwork.Subnets | Where-Object { $_.Name -eq $VirtualSubnetVM }) -ne $null) {
            $VirtualSubnet = $VirtualNetwork.Subnets | Out-GridView -PassThru -Title "Virtual Network Subnets"
            $IP = Get-AzureStaticVNetIP -VM $VM
            if (!($IP -eq $null)) {
                Remove-AzureStaticVNetIP -VM $VM
            }
            Set-AzureSubnet -SubnetNames $VirtualSubnet.Name -VM $VM.VM | Update-AzureVM -ServiceName $VM.ServiceName -Name $VM.VM.RoleName
            $VM = Get-AzureVM -Name $VM.VM.RoleName -ServiceName $VM.ServiceName
            Set-AzureStaticVNetIP -IPAddress $VM.IpAddress -VM $VM.VM | Update-AzureVM -ServiceName $VM.ServiceName -Name $VM.VM.RoleName
        }
    }
    if ($AzureResourceManager -eq $true) {
        $VNETs = Get-AzureRmVirtualNetwork
        $Temp = Get-AzureRmVM | Select-Object Name, ResourceGroupName | Out-GridView -PassThru -Title "Azure Virtual Machines"
        $VM = Get-AzureRmVM -Name $Temp.Name -ResourceGroupName $Temp.ResourceGroupName
        $NICName = $VM.NetworkInterfaceIDs | Out-GridView -PassThru -Title "Azure VM NICs"
        $NICName = $NICName -split "/"
        $NIC = Get-AzureRmNetworkInterface -Name $NICName[$NICName.Length - 1] -ResourceGroupName $VM.ResourceGroupName
        $IP = $NIC.IpConfigurations
        foreach ($VNET in $VNETs) {
            $Subnets = $VNET.Subnets
            foreach ($Subnet in $Subnets) {
                if ($IP.Subnet.Id -eq $Subnet.ID) {
                    $SelectSubnet = $Subnets | Select-Object Name, AddressPrefix, Id | Out-GridView -PassThru -Title "Azure Virtual Network Subnets"
                }
            }
        }
        if ($NIC.IpConfigurations.PrivateIpAllocationMethod -eq "Static") {
            $NIC.IpConfigurations[0].PrivateIpAllocationMethod = "Dynamic"
            Set-AzureRmNetworkInterface -NetworkInterface $NIC
            $temp = "Static"
        }
        $IP.Subnet.Id = $SelectSubnet.Id
        Set-AzureRmNetworkInterface -NetworkInterface $NIC
        if ($temp -eq "Static") {
            $NIC = Get-AzureRmNetworkInterface -Name $NICName[$NICName.Length - 1] -ResourceGroupName $VM.ResourceGroupName
            $NIC.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
            Set-AzureRmNetworkInterface -NetworkInterface $NIC
        }
    }
    if ($AzureServiceManagement -eq $false -and $AzureResourceManager -eq $false) {
        Write-Output "Set-AzureVMSubnet -AzureServiceManagement"
        Write-Output "Set-AzureVMSubnet -AzureResourceManager"
    }
}