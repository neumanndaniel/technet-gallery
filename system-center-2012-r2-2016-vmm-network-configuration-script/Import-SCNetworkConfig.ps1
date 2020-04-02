<#
    .SYNOPSIS
       Create your network configuration in VMM based on a XML file.
    .DESCRIPTION
       Create your network configuration in VMM based on a XML file. The script covers the scenarios of No isolation, VLAN isolation and NVGRE isolation.
       It creates the Logical Network with corresponding Network Site, VLAN & Subnet and the VM Network.
       Not to forget the Static IP Address Pool with reservations, Gateway and DNS server is also created by this script.
    .NOTES
        File Name : Import-SCNetworkConfig.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 R2 Virtual Machine Manager PowerShell Cmdlets
        Version   : 2.1
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       Import-SCNetworkConfig -VMMServer vmmserver.demo.local -Path C:\ConfigFiles\VMMNetworkConfig.xml

       Import the VMM network configuration.
#>
function Import-SCNetworkConfig {
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'VMM Server')]
        [String]
        $VMMServer,
        [Parameter(Mandatory = $true, HelpMessage = 'Path to XML file')]
        [String]
        $Path
    )
    [XML]$XMLImport = Get-Content -Path $Path
    foreach ($Network in $XMLImport.VMMNetworkConfig.NetworkConfig) {
        #No Isolation
        if ($Network.NetworkType -eq "No Isolation") {
            $Hostgroup = @()
            $Name = $Network.LogicalNetworkName
            $Subnet = $Network.IPSubnet
            $Site = $Network.NetworkSiteName
            $VMNetworkName = $Network.VMNetworkName
            $LogicalNetwork = New-SCLogicalNetwork -VMMServer $VMMServer -Name $Name -EnableNetworkVirtualization $false -UseGRE $false -LogicalNetworkDefinitionIsolation $false
            $SubnetVLAN = New-SCSubnetVLan -VMMServer $VMMServer -VLanID 0 -Subnet $Subnet -SupportsDHCP $true
            $Hostgroups = $Network.Hostgroup -split ","
            foreach ($Item in $Hostgroups) {
                $Hostgroup += Get-SCVMHostgroup | Where-Object { $_.Name -eq $Item }
            }
            $LogicalNetworkDefinition = New-SCLogicalNetworkDefinition -VMMServer $VMMServer -Name $Site -LogicalNetwork $LogicalNetwork -SubnetVLan $SubnetVLAN -VMHostGroup $Hostgroup
            New-SCVMNetwork -VMMServer $VMMServer -Name $VMNetworkName -LogicalNetwork $LogicalNetwork -IsolationType NoIsolation
            $StaticIPPool = $Network.StaticIPPool
            if ($StaticIPPool -eq "Yes") {
                $Gateway = $Network.Gateway
                $DNS = $Network.DNSServer -split ","
                $DNSSuffix = $Network.DNSSuffix
                $Gateway = New-SCDefaultGateway -VMMServer $VMMServer -IPAddress $Gateway -Automatic
                $Reserved = $Network.Reservation
                if ($Reserved -eq $null) {
                    New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -DefaultGateway $Gateway -DNSServer $DNS -Subnet $Subnet -DNSSuffix $DNSSuffix
                }
                else {
                    New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -DefaultGateway $Gateway -DNSServer $DNS -Subnet $Subnet -DNSSuffix $DNSSuffix -IPAddressReservedSet $Reserved
                }
            }
        }

        #VLAN
        if ($Network.NetworkType -eq "VLAN") {
            $Hostgroup = @()
            $Name = $Network.LogicalNetworkName
            $Subnet = $Network.IPSubnet
            $VLANID = [System.Convert]::ToInt32($Network.VLANID)
            $Site = $Network.NetworkSiteName
            $VMNetworkName = $Network.VMNetworkName
            $LogicalNetwork = New-SCLogicalNetwork -VMMServer $VMMServer -Name $Name -EnableNetworkVirtualization $false -UseGRE $false -LogicalNetworkDefinitionIsolation $true
            $SubnetVLAN = New-SCSubnetVLan -VMMServer $VMMServer -VLanID $VLANID -Subnet $Subnet -SupportsDHCP $true
            $Hostgroups = $Network.Hostgroup -split ","
            foreach ($Item in $Hostgroups) {
                $Hostgroup += Get-SCVMHostgroup | Where-Object { $_.Name -eq $Item }
            }
            $LogicalNetworkDefinition = New-SCLogicalNetworkDefinition -VMMServer $VMMServer -Name $Site -LogicalNetwork $LogicalNetwork -SubnetVLan $SubnetVLAN -VMHostGroup $Hostgroup
            $VMNetwork = New-SCVMNetwork -VMMServer $VMMServer -Name $VMNetworkName -LogicalNetwork $LogicalNetwork -IsolationType VLANNetwork
            New-SCVMSubnet -VMMServer $VMMServer -LogicalNetworkDefinition $LogicalNetworkDefinition -Name $LogicalNetwork.Name -SubnetVLan $SubnetVLAN -VMNetwork $VMNetwork
            $StaticIPPool = $Network.StaticIPPool
            if ($StaticIPPool -eq "Yes") {
                $Reserved = $Network.Reservation
                if ($Reserved -eq $null) {
                    $IPPool = New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -Subnet $Subnet
                }
                else {
                    $IPPool = New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -Subnet $Subnet -IPAddressReservedSet $Reserved
                }
                $SetIP = $Network.GatewayDNS
                if ($SetIP -eq "No") {

                }
                if ($SetIP -eq "Yes") {
                    $Gateway = $Network.Gateway
                    $DNS = $Network.DNSServer -split ","
                    $DNSSuffix = $Network.DNSSuffix
                    $Gateway = New-SCDefaultGateway -VMMServer $VMMServer -IPAddress $Gateway -Automatic
                    Set-SCStaticIPAddressPool -VMMServer $VMMServer -StaticIPAddressPool $IPPool -DefaultGateway $Gateway -DNSServer $DNS -DNSSuffix $DNSSuffix
                }
            }
        }

        #NVGRE
        if ($Network.NetworkType -eq "NVGRE") {
            $Hostgroup = @()
            $Name = $Network.LogicalNetworkName
            $Subnet = $Network.IPSubnet
            $VLANID = [System.Convert]::ToInt32($Network.VLANID)
            if ($VLANID -eq $null) {
                $VLANID = 0
            }
            $Site = $Network.NetworkSiteName
            $LogicalNetwork = New-SCLogicalNetwork -VMMServer $VMMServer -Name $Name -EnableNetworkVirtualization $true -UseGRE $true -LogicalNetworkDefinitionIsolation $false
            $SubnetVLAN = New-SCSubnetVLan -VMMServer $VMMServer -VLanID $VLANID -Subnet $Subnet -SupportsDHCP $true
            $Hostgroups = $Network.Hostgroup -split ","
            foreach ($Item in $Hostgroups) {
                $Hostgroup += Get-SCVMHostgroup | Where-Object { $_.Name -eq $Item }
            }
            $LogicalNetworkDefinition = New-SCLogicalNetworkDefinition -VMMServer $VMMServer -Name $Site -LogicalNetwork $LogicalNetwork -SubnetVLan $SubnetVLAN -VMHostGroup $Hostgroup
            New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -Subnet $Subnet
            $Name = $Network.VMNetworkName
            $NVGRESubnet = $Network.VMNetworkIPSubnet
            $VMNetwork = New-SCVMNetwork -VMMServer $VMMServer -Name $Name -LogicalNetwork $LogicalNetwork -IsolationType WindowsNetworkVirtualization -PAIPAddressPoolType IPV4 -CAIPAddressPoolType IPV4
            $NVGREVLAN = New-SCSubnetVLan -VMMServer $VMMServer -Subnet $NVGRESubnet -SupportsDHCP $true
            $VMSubnet = New-SCVMSubnet -VMMServer $VMMServer -Name $Name -VMNetwork $VMNetwork -SubnetVLan $NVGREVLAN
            $DNS = $Network.VMNetworkDNSServer -split ","
            New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Name -VMSubnet $VMSubnet -DNSServer $DNS -Subnet $NVGRESubnet
        }
    }
}