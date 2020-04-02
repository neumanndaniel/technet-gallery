<#
    .SYNOPSIS
       Create your network configuration in VMM.
    .DESCRIPTION
       Create your network configuration in VMM. The script covers the scenarios of No isolation, VLAN isolation and NVGRE isolation.
       It creates the Logical Network with corresponding Network Site, VLAN & Subnet and the VM Network.
       Not to forget the Static IP Address Pool with reservations, Gateway and DNS server is also created by this script.
    .NOTES
        File Name : New-SCNetworkConfig.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 R2 Virtual Machine Manager PowerShell Cmdlets
        Version   : 2.1
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io
    .EXAMPLE
       New-SCNetworkConfig

       Call the VMM network configuration script.
#>
function New-SCNetworkConfig {
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    $VMMServer = [Microsoft.VisualBasic.Interaction]::InputBox("Enter VMM Server Name", "VMM Server", "$env:COMPUTERNAME.$env:USERDNSDOMAIN")
    Do {
        $Install = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Setup Option:
        1=No Isolation
        2=VLAN
        3=NVGRE
        E=Exit", "Setup Option", "1")
        #No Isolation
        if ($Install -eq "1") {
            $Hostgroup = @()
            $Name = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Logical Network Name", "Logical Network Name", "Management")
            $Subnet = [Microsoft.VisualBasic.Interaction]::InputBox("Enter IP Subnet", "IP Subnet", "10.0.0.0/24")
            $Site = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Network Site Name", "Network Site Name", "Seattle")
            $VMNetworkName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter VM Network Name", "VM Network Name", "Management")
            $LogicalNetwork = New-SCLogicalNetwork -VMMServer $VMMServer -Name $Name -EnableNetworkVirtualization $false -UseGRE $false -LogicalNetworkDefinitionIsolation $false
            $SubnetVLAN = New-SCSubnetVLan -VMMServer $VMMServer -VLanID 0 -Subnet $Subnet -SupportsDHCP $true
            $Hostgroups = Get-SCVMHostgroup -VMMServer $VMMServer | Select-Object -Property Name | Out-GridView -PassThru -Title "Host Groups"
            foreach ($Item in $Hostgroups) {
                $Hostgroup += Get-SCVMHostgroup | Where-Object { $_.Name -eq $Item.Name }
            }
            $LogicalNetworkDefinition = New-SCLogicalNetworkDefinition -VMMServer $VMMServer -Name $Site -LogicalNetwork $LogicalNetwork -SubnetVLan $SubnetVLAN -VMHostGroup $Hostgroup
            New-SCVMNetwork -VMMServer $VMMServer -Name $VMNetworkName -LogicalNetwork $LogicalNetwork -IsolationType NoIsolation
            $StaticIPPool = [Microsoft.VisualBasic.Interaction]::InputBox("Do you want to configure a Static IP address pool?
            1=Yes
            0=No", "Static IP address pool", "1")
            if ($StaticIPPool -eq "1") {
                $Gateway = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Default Gateway", "Default Gateway", "10.0.0.254")
                $DNS1 = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Primary DNS Server", "Primary DNS Server", "10.0.0.1")
                $DNS2 = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Secondary DNS Server", "Secondary DNS Server", "10.0.0.2")
                $DNS = $DNS1, $DNS2
                $Gateway = New-SCDefaultGateway -VMMServer $VMMServer -IPAddress $Gateway -Automatic
                $Reserved = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Reservation:
                10.0.0.1
                10.0.0.1, 10.0.0.2
                10.0.0.1-10.0.0.20", "Reservation", "")
                if ($Reserved -eq "") {
                    New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -DefaultGateway $Gateway -DNSServer $DNS -Subnet $Subnet -DNSSuffix $env:USERDNSDOMAIN
                }
                else {
                    New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -DefaultGateway $Gateway -DNSServer $DNS -Subnet $Subnet -DNSSuffix $env:USERDNSDOMAIN -IPAddressReservedSet $Reserved
                }
            }
        }
        #VLAN Isolation
        if ($Install -eq "2") {
            $Hostgroup = @()
            $Name = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Logical Network Name", "Logical Network Name", "Management")
            $Subnet = [Microsoft.VisualBasic.Interaction]::InputBox("Enter IP Subnet", "IP Subnet", "10.0.0.0/24")
            $VLANID = [System.Convert]::ToInt32([Microsoft.VisualBasic.Interaction]::InputBox("Enter VLAN ID", "VLAN ID", "0"))
            $Site = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Network Site Name", "Network Site Name", "Seattle")
            $VMNetworkName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter VM Network Name", "VM Network Name", "Management")
            $LogicalNetwork = New-SCLogicalNetwork -VMMServer $VMMServer -Name $Name -EnableNetworkVirtualization $false -UseGRE $false -LogicalNetworkDefinitionIsolation $true
            $SubnetVLAN = New-SCSubnetVLan -VMMServer $VMMServer -VLanID $VLANID -Subnet $Subnet -SupportsDHCP $true
            $Hostgroups = Get-SCVMHostgroup -VMMServer $VMMServer | Select-Object -Property Name | Out-GridView -PassThru -Title "Host Groups"
            foreach ($Item in $Hostgroups) {
                $Hostgroup += Get-SCVMHostgroup | Where-Object { $_.Name -eq $Item.Name }
            }
            $LogicalNetworkDefinition = New-SCLogicalNetworkDefinition -VMMServer $VMMServer -Name $Site -LogicalNetwork $LogicalNetwork -SubnetVLan $SubnetVLAN -VMHostGroup $Hostgroup
            $VMNetwork = New-SCVMNetwork -VMMServer $VMMServer -Name $VMNetworkName -LogicalNetwork $LogicalNetwork -IsolationType VLANNetwork
            New-SCVMSubnet -VMMServer $VMMServer -LogicalNetworkDefinition $LogicalNetworkDefinition -Name $LogicalNetwork.Name -SubnetVLan $SubnetVLAN -VMNetwork $VMNetwork
            $StaticIPPool = [Microsoft.VisualBasic.Interaction]::InputBox("Do you want to configure a Static IP address pool?
            1=Yes
            0=No", "Static IP address pool", "1")
            if ($StaticIPPool -eq "1") {
                $Reserved = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Reservation:
                10.0.0.1
                10.0.0.1, 10.0.0.2
                10.0.0.1-10.0.0.20", "Reservation", "")
                if ($Reserved -eq "") {
                    $IPPool = New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -Subnet $Subnet
                }
                else {
                    $IPPool = New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -Subnet $Subnet -IPAddressReservedSet $Reserved
                }
                $SetIP = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Setup IP Option|0=No Gateway & DNS|1=Gateway & DNS", "Setup IP Option", "1")
                if ($SetIP -eq "0") {

                }
                if ($SetIP -eq "1") {
                    $Gateway = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Default Gateway", "Default Gateway", "10.0.0.254")
                    $DNS1 = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Primary DNS Server", "Primary DNS Server", "10.0.0.1")
                    $DNS2 = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Secondary DNS Server", "Secondary DNS Server", "10.0.0.2")
                    $DNS = $DNS1, $DNS2
                    $Gateway = New-SCDefaultGateway -VMMServer $VMMServer -IPAddress $Gateway -Automatic
                    Set-SCStaticIPAddressPool -VMMServer $VMMServer -StaticIPAddressPool $IPPool -DefaultGateway $Gateway -DNSServer $DNS -DNSSuffix $env:USERDNSDOMAIN
                }
            }
        }
        #NVGRE Isolation
        if ($Install -eq "3") {
            $Name = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Logical Network Name for PAS", "Logical Network Name", "NVGRE Provider Address Space")
            $Subnet = [Microsoft.VisualBasic.Interaction]::InputBox("Enter IP Subnet for PAS", "IP Subnet", "10.0.0.0/24")
            $VLANID = [System.Convert]::ToInt32([Microsoft.VisualBasic.Interaction]::InputBox("Enter VLAN ID for PAS", "VLAN ID", "0"))
            $Site = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Network Site Name", "Network Site Name", "Seattle")
            $LogicalNetwork = New-SCLogicalNetwork -VMMServer $VMMServer -Name $Name -EnableNetworkVirtualization $true -UseGRE $true -LogicalNetworkDefinitionIsolation $false
            $SubnetVLAN = New-SCSubnetVLan -VMMServer $VMMServer -VLanID $VLANID -Subnet $Subnet -SupportsDHCP $true
            $Hostgroups = Get-SCVMHostgroup -VMMServer $VMMServer | Select-Object -Property Name | Out-GridView -PassThru -Title "Host Groups"
            foreach ($Item in $Hostgroups) {
                $Hostgroup += Get-SCVMHostgroup | Where-Object { $_.Name -eq $Item.Name }
            }
            $LogicalNetworkDefinition = New-SCLogicalNetworkDefinition -VMMServer $VMMServer -Name $Site -LogicalNetwork $LogicalNetwork -SubnetVLan $SubnetVLAN -VMHostGroup $Hostgroup
            New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $Site -LogicalNetworkDefinition $LogicalNetworkDefinition -Subnet $Subnet
            $VMNetworkName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter VM Network Name for CAS", "VM Network Name", "NVGRE Customer Address Space")
            $NVGRESubnet = [Microsoft.VisualBasic.Interaction]::InputBox("Enter VM Network IP Subnet for CAS", "IP Subnet", "10.0.0.0/24")
            $VMNetwork = New-SCVMNetwork -VMMServer $VMMServer -Name $VMNetworkName -LogicalNetwork $LogicalNetwork -IsolationType WindowsNetworkVirtualization -PAIPAddressPoolType IPV4 -CAIPAddressPoolType IPV4
            $NVGREVLAN = New-SCSubnetVLan -VMMServer $VMMServer -Subnet $NVGRESubnet -SupportsDHCP $true
            $VMSubnet = New-SCVMSubnet -VMMServer $VMMServer -Name $VMNetworkName -VMNetwork $VMNetwork -SubnetVLan $NVGREVLAN
            $DNS1 = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Primary DNS Server for VM Network for CAS", "Primary DNS Server", "10.0.0.1")
            $DNS2 = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Secondary DNS Server for VM Network for CAS", "Secondary DNS Server", "10.0.0.2")
            $DNS = $DNS1, $DNS2
            New-SCStaticIPAddressPool -VMMServer $VMMServer -Name $VMNetworkName -VMSubnet $VMSubnet -DNSServer $DNS -Subnet $NVGRESubnet
        }
    } While ($Install -ne "E")
}