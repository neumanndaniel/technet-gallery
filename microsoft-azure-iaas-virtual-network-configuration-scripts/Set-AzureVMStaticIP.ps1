<#
    .SYNOPSIS
       Sets the current IP as static IP address for an Azure VM in an Azure Virtual Network.
    .DESCRIPTION
       Sets the current IP as static IP address for an Azure VM in an Azure Virtual Network.
    .NOTES
        File Name : Set-AzureVMStaticIP.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    Microsoft Azure PowerShell Cmdlets
                    Microsoft Azure ARM PowerShell Cmdlets
        Version   : 2.1
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Set-AzureVMStaticIP

       Set the Azure VM Static IP address.
#>
function Set-AzureVMStaticIP {
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
        Set-AzureStaticVNetIP -IPAddress $VM.IpAddress -VM $VM.VM | Update-AzureVM -ServiceName $VM.ServiceName -Name $VM.VM.RoleName
    }
    if ($AzureResourceManager -eq $true) {
        $Temp = Get-AzureRmVM | Select-Object Name, ResourceGroupName | Out-GridView -PassThru -Title "Azure Virtual Machines"
        $VM = Get-AzureRmVM -Name $Temp.Name -ResourceGroupName $Temp.ResourceGroupName
        $NICName = $VM.NetworkInterfaceIDs | Out-GridView -PassThru -Title "Azure VM NICs"
        $NICName = $NICName -split "/"
        $NIC = Get-AzureRmNetworkInterface -Name $NICName[$NICName.Length - 1] -ResourceGroupName $VM.ResourceGroupName
        $NIC.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
        Set-AzureRmNetworkInterface -NetworkInterface $NIC
    }
    if ($AzureServiceManagement -eq $false -and $AzureResourceManager -eq $false) {
        Write-Output "Set-AzureVMStaticIP -AzureServiceManagement"
        Write-Output "Set-AzureVMStaticIP -AzureResourceManager"
    }
}