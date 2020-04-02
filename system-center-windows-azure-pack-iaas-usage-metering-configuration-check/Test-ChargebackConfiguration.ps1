<#
    .SYNOPSIS
     Testing the System Center & Windows Azure Pack usage metering configuration.
    .DESCRIPTION
     Testing the System Center & Windows Azure Pack usage metering configuration or verfiy it.
    .NOTES
        File Name : Test-ChargebackConfiguration.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 R2 Virtual Machine Manager PowerShell Cmdlets
                    System Center 2012 R2 Operations Manager PowerShell Cmdlets
        Version   : 1.0
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io/system-center-windows-azure-pack-iaas-usage-metering-configuration-check
#>

#Variables

$VMMServer = 'srv-1.neumanndaniel.local'
$SPFServer = 'srv-2.neumanndaniel.local'
$SPFLBName = 'srv-2.neumanndaniel.local'
$WAPackUsageServer = 'srv-5.neumanndaniel.local'
$SRServer = 'srv-5.neumanndaniel.local'
$OperationsManagerSQLServer = 'SRV-2\SCOM'
$OperationsManagerDWSQLServer = 'SRV-2\SCOM'
$OperationsManagerDBName = 'OperationsManager'
$OperationsManagerDWDBName = 'OperationsManagerDW'
$SRSQLServer = 'SRV-5\SR'
$SRSQLAnalysisServer = 'SRV-5\SR'
$SRSQLAnalysisDBName = 'UsageAnalysisDB'
$SPFSQLServer = 'SRV-2\SPF'
$WAPackSQLServer = 'SRV-5\WAP'
$SPFUsageUser = 'NEUMANNDANIEL\spf'
$SRSQLUser = 'NEUMANNDANIEL\spf'
$SRSQLAgentUser = 'NEUMANNDANIEL\spfagent'
$SRPathWD = 'C:\Program Files\Microsoft System Center 2012 R2\Service Reporting\WorkDir'
$SRPathSP = 'C:\Program Files\Microsoft System Center 2012 R2\Service Reporting\SSISPackages'

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.AnalysisServices') | Out-Null

#VMM SCOM Connection Status

Import-Module virtualmachinemanager
$VMMSCOMConnection = Get-SCOpsMgrConnection -VMMServer $VMMServer
if ($VMMSCOMConnection.ConnectionStatus -eq 'OK') {
    Write-Host 'VMM SCOM Connection Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
if ($VMMSCOMConnection.ConnectionStatus -eq 'Warning') {
    Write-Host 'VMM SCOM Connection Status: ' -NoNewline
    Write-Host -ForegroundColor Yellow 'Unhealthy'
}
if ($VMMSCOMConnection.ConnectionStatus -eq 'Error') {
    Write-Host 'VMM SCOM Connection Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Broken'
}

#SPF SCOM Connection Status

Import-Module operationsmanager
$SCOMMgmtServers = Get-SCOMManagementServer -ComputerName $VMMSCOMConnection.OpsMgrServerName
foreach ($SCOMMgmtServer in $SCOMMgmtServers) {
    if ($SCOMMgmtServer.IsRootManagementServer -eq $true) {
        $SCOMServer = $SCOMMgmtServer
    }
}

Invoke-Command -ComputerName $SPFServer -ScriptBlock {
    param($OperationsManagerDWSQLServer, $OperationsManagerDWDBName, $SCOMServer)
    Import-Module spfadmin
    Import-Module WebAdministration
    $SCSPFServer = Get-SCSPFServer -ServerType OMDW
    $SCSPFSetting = Get-SCSPFSetting -Name $SCSPFServer.SpfSettings
    $BestPracticeValueCheck = "Data Source=$OperationsManagerDWSQLServer;Initial Catalog=$OperationsManagerDWDBName;Integrated Security=True"
    if ($SCSPFServer.Name -eq $SCOMServer.Name) {
        Write-Host 'SPF Get-SCSPFServer: SCOM Management Server Name: ' -NoNewline
        Write-Host -ForegroundColor Green 'Match'
    }
    else {
        Write-Host 'SPF Get-SCSPFServer: SCOM Management Server Name: ' -NoNewline
        Write-Host -ForegroundColor Red 'Mismatch'
    }
    if ($SCSPFSetting.SettingString -eq $BestPracticeValueCheck) {
        Write-Host 'SPF Get-SCSPFSetting: SCOM DW SQL: ' -NoNewline
        Write-Host -ForegroundColor Green 'Match'
    }
    else {
        Write-Host 'SPF Get-SCSPFSetting: SCOM DW SQL: ' -NoNewline
        Write-Host -ForegroundColor Red 'Mismatch'
    }
    if ($SCSPFSetting.Server.Name -eq $SCOMServer.Name) {
        Write-Host 'SPF Get-SCSPFSetting: SCOM Management Server Name: ' -NoNewline
        Write-Host -ForegroundColor Green 'Match'
    }
    else {
        Write-Host 'SPF Get-SCSPFSetting: SCOM Management Server Name: ' -NoNewline
        Write-Host -ForegroundColor Red 'Mismatch'
    }

    $SPFWebsite = Get-WebSite -Name SPF
    if ($SPFWebsite.state -eq 'Started') {
        Write-Host 'SPF Website Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
    }
    else {
        Write-Host 'SPF Website Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Broken'
    }
    $SPFUsageApplicationPool = Get-WebAppPoolState -Name Usage
    if ($SPFUsageApplicationPool.Value -eq 'Started') {
        Write-Host 'SPF Usage Application Pool Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
    }
    else {
        Write-Host 'SPF Usage Application Pool Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Broken'
    }
} -ArgumentList $OperationsManagerDWSQLServer, $OperationsManagerDWDBName, $SCOMServer

$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $OperationsManagerDWSQLServer
$Database = $Server.Databases | Where-Object { $_.Name -eq $OperationsManagerDWDBName }
$DBUserCheck = $Database.Users.Contains($SPFUsageUser)
$Role = $Database.Roles | Where-Object { $_.Name -eq 'OpsMgrReader' }
$RoleMember = $Role.EnumMembers()
$DBRoleCheck = $RoleMember.Contains($SPFUsageUser)
if ($DBUserCheck -eq $true) {
    Write-Host 'SPF Usage Account OpsMgr DW DB User Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'SPF Usage Account OpsMgr DW DB User Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Missing'
}
if ($DBRoleCheck -eq $true) {
    Write-Host 'SPF Usage Account OpsMgrReader Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'SPF Usage Account OpsMgrReader Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Missing'
}

#WAPack Status

Invoke-Command -ComputerName $WAPackUsageServer -ScriptBlock {
    param($SPFServer, $SPFLBName, $SPFUsageUser)
    Import-Module MgmtSvcConfig
    Import-Module WebAdministration
    $UsageRPIaaS = Get-MgmtSvcResourceProviderConfiguration -Name systemcenter
    if ($UsageRPIaaS.UsageEndpoint.AuthenticationUsername -eq $SPFUsageUser) {
        Write-Host 'WAPack Service Provider Usage: SPF Usage Account: ' -NoNewline
        Write-Host -ForegroundColor Green 'Match'
    }
    else {
        Write-Host 'WAPack Service Provider Usage: SPF Usage Account: ' -NoNewline
        Write-Host -ForegroundColor Red 'Mismatch'
    }
    $WAPackSPFFQDN = "https://" + $SPFServer + ":8090/Usage/"
    $SPFNetBIOSName = $SPFServer.Split(".")[0]
    $WAPackSPFNetBIOS = "https://" + $SPFNetBIOSName + ":8090/Usage/"
    $WAPACKSPFLBFQDN = "https://" + $SPFLBName + ":8090/Usage/"
    if ($UsageRPIaaS.UsageEndpoint.ForwardingAddress.OriginalString -eq $WAPackSPFFQDN -or $UsageRPIaaS.UsageEndpoint.ForwardingAddress.OriginalString -eq $WAPackSPFNetBIOS -or $UsageRPIaaS.UsageEndpoint.ForwardingAddress.OriginalString -eq $WAPackSPFLBFQDN) {
        Write-Host 'WAPack Service Provider Usage: Forwarding Address: ' -NoNewline
        Write-Host -ForegroundColor Green 'Match'
    }
    else {
        Write-Host 'WAPack Service Provider Usage: Forwarding Address: ' -NoNewline
        Write-Host -ForegroundColor Red 'Mismatch'
    }


    $WAPackUsageWebsite = Get-WebSite -Name MgmtSvc-Usage
    if ($WAPackUsageWebsite.state -eq 'Started') {
        Write-Host 'WAPack Usage Website Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
    }
    else {
        Write-Host 'WAPack Usage Website Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Broken'
    }
    $WAPackUsageCollectorWebsite = Get-WebSite -Name MgmtSvc-UsageCollector
    if ($WAPackUsageCollectorWebsite.state -eq 'Started') {
        Write-Host 'WAPack Usage Collector Website Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
    }
    else {
        Write-Host 'WAPack Usage Collector Website Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Broken'
    }
    $WAPackUsageApplicationPool = Get-WebAppPoolState -Name MgmtSvc-Usage
    if ($WAPackUsageApplicationPool.Value -eq 'Started') {
        Write-Host 'WAPack Usage Application Pool Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
    }
    else {
        Write-Host 'WAPack Usage Application Pool Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Broken'
    }
    $WAPackUsageCollectorApplicationPool = Get-WebAppPoolState -Name MgmtSvc-UsageCollector
    if ($WAPackUsageCollectorApplicationPool.Value -eq 'Started') {
        Write-Host 'WAPack Usage Collector Application Pool Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
    }
    else {
        Write-Host 'WAPack Usage Collector Application Pool Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Broken'
    }
} -ArgumentList $SPFServer, $SPFLBName, $SPFUsageUser

$DataSource = $SPFSQLServer
$Database = "SCSPFDB"
$connectionString = "Server=$DataSource;Database=$Database;Integrated Security=True"
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$query = "SELECT * FROM scspf.SpfUsageRecord"
$command = New-Object System.Data.SqlClient.SqlCommand
$command.CommandText = $query
$command.Connection = $connection
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter
$adapter.SelectCommand = $command
$Data = New-Object System.Data.DataSet
$adapter.Fill($Data) | Out-Null
$connection.Close()
$Entries = $Data.Tables
$Number = $Entries.RecordIndex.Count

$SPFUsageRecordIndex = $Entries.RecordIndex[$Number - 1]

$DataSource = $WAPackSQLServer
$Database = "Microsoft.MgmtSvc.Usage"
$connectionString = "Server=$DataSource;Database=$Database;Integrated Security=True"
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$query = "SELECT * FROM Usage.Records"
$command = New-Object System.Data.SqlClient.SqlCommand
$command.CommandText = $query
$command.Connection = $connection
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter
$adapter.SelectCommand = $command
$Data = New-Object System.Data.DataSet
$adapter.Fill($Data) | Out-Null
$connection.Close()
$Entries = $Data.Tables
$Number = $Entries.ExternalRecordId.Count

$WAPackUsageRecordIndex = $Entries.ExternalRecordId[$Number - 1]

$DataSource = $WAPackSQLServer
$Database = "Microsoft.MgmtSvc.Usage"
$connectionString = "Server=$DataSource;Database=$Database;Integrated Security=True"
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$query = "SELECT * FROM Usage.ProvidersConfiguration"
$command = New-Object System.Data.SqlClient.SqlCommand
$command.CommandText = $query
$command.Connection = $connection
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter
$adapter.SelectCommand = $command
$Data = New-Object System.Data.DataSet
$adapter.Fill($Data) | Out-Null
$connection.Close()
$Entries = $Data.Tables
foreach ($Entry in $Entries[0]) {
    if ($Entry.ProviderName -eq 'systemcenter') {
        $Temp = $Entry.LastUsageEventId
    }
}

$WAPackUsageProviderConfigurationRecordIndex = $Temp

if ($SPFUsageRecordIndex -eq $WAPackUsageRecordIndex) {
    Write-Host 'WAPack Last Usage Record Index and SPF Last Usage Record Index Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'Match'
}
else {
    Write-Host 'WAPack Last Usage Record Index and SPF Last Usage Record Index Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Mismatch'
}
if ($SPFUsageRecordIndex -eq $WAPackUsageProviderConfigurationRecordIndex) {
    Write-Host 'WAPack Provider Configuration Usage Record Index and SPF Last Usage Record Index Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'Match'
}
else {
    Write-Host 'WAPack Provider Configuration Usage Record Index and SPF Last Usage Record Index Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Mismatch'
}

Invoke-Command -ComputerName $WAPackUsageServer -ScriptBlock {
    param($WAPackSQLServer)
    Import-Module MgmtSvcConfig
    Import-Module WebAdministration
    $UsageRPIaaS = Get-MgmtSvcResourceProviderConfiguration -Name systemcenter
    $DataSource = $WAPackSQLServer
    $Database = "Microsoft.MgmtSvc.Usage"
    $connectionString = "Server=$DataSource;Database=$Database;Integrated Security=True"
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $query = "SELECT * FROM UsageDiagnostics.ProviderCollectionCycles"
    $command = New-Object System.Data.SqlClient.SqlCommand
    $command.CommandText = $query
    $command.Connection = $connection
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $adapter.SelectCommand = $command
    $Data = New-Object System.Data.DataSet
    $adapter.Fill($Data) | Out-Null
    $connection.Close()
    $Entries = $Data.Tables
    $Number = $Entries.ResourceProviderStatus.Count
    $i = 1
    Do {
        $WAPackUsageProviderCollectionCycle = $Entries.ResourceProviderHostName[$Number - $i]
        $WAPackUsageProviderCollectionCycleDLStatus = $Entries.DownloadStatus[$Number - $i]
        if ($WAPackUsageProviderCollectionCycle -eq $UsageRPIaaS.UsageEndpoint.ForwardingAddress.OriginalString) {
            if ($WAPackUsageProviderCollectionCycleDLStatus -eq 1) {
                Write-Host 'WAPack Usage Provider Collection Cycle Download Status: ' -NoNewline
                Write-Host -ForegroundColor Green 'OK'
            }
            else {
                Write-Host 'WAPack Usage Provider Collection Cycle Download Status: ' -NoNewline
                Write-Host -ForegroundColor Red 'Error'
            }
        }
        $i++
    }While ($WAPackUsageProviderCollectionCycle -ne $UsageRPIaaS.UsageEndpoint.ForwardingAddress.OriginalString)
} -ArgumentList $WAPackSQLServer

#Service Reporting Status

$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $OperationsManagerSQLServer
$Database = $Server.Databases | Where-Object { $_.Name -eq $OperationsManagerDBName }
$DBUserCheck = $Database.Users.Contains($SRSQLAgentUser)
$Role = $Database.Roles | Where-Object { $_.Name -eq 'db_datareader' }
$RoleMember = $Role.EnumMembers()
$DBRoleCheck = $RoleMember.Contains($SRSQLAgentUser)
if ($DBUserCheck -eq $true) {
    Write-Host 'Service Reporting SQL Agent Account OpsMgr DB User Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'Service Reporting SQL Agent Account OpsMgr DB User Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Missing'
}
if ($DBRoleCheck -eq $true) {
    Write-Host 'Service Reporting SQL Agent Account db_datareader Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'Service Reporting SQL Agent Account db_datareader Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Missing'
}

$Server = New-Object ('Microsoft.AnalysisServices.Server')
$Server.connect($SRSQLAnalysisServer)
$Database = $Server.Databases | Where-Object { $_.Name -eq $SRSQLAnalysisDBName }
$Role = $Database.Roles | Where-Object { $_.Name -eq 'SR_Administrator' }
$RoleMember = $Role.Members.Name
$DBRoleCheckSRSQL = $RoleMember.Contains($SRSQLUser)
$DBRoleCheckSRSQLAgent = $RoleMember.Contains($SRSQLAgentUser)
$Server.disconnect()
if ($DBRoleCheckSRSQL -eq $true) {
    Write-Host 'Service Reporting SQL Account SQL Analysis DB SR_Administrator Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'Service Reporting SQL Account SQL Analysis DB SR_Administrator Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Missing'
}
if ($DBRoleCheckSRSQLAgent -eq $true) {
    Write-Host 'Service Reporting SQL Agent Account SQL Analysis DB SR_Administrator Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'Service Reporting SQL Agent Account SQL Analysis DB SR_Administrator Membership Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Missing'
}

$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SRSQLServer
$SRSQLJobs = $Server.JobServer.Jobs | Where-Object { $_.Name -eq 'Service Reporting DW System Job' }
$LastRun = $SRSQLJobs.LastRunOutcome
if ($LastRun -eq 'Succeeded') {
    Write-Host 'Service Reporting DW System Job Last Run Status: ' -NoNewline
    Write-Host -ForegroundColor Green 'OK'
}
else {
    Write-Host 'Service Reporting DW System Job Last Run Status: ' -NoNewline
    Write-Host -ForegroundColor Red 'Failed'
}

Invoke-Command -ComputerName $SRServer -ScriptBlock {
    param($SRPathWD, $SRPathSP)
    $ACL = Get-Acl -Path $SRPathSP
    $ACL = $ACL.Access | Where-Object { $_.IdentityReference -eq 'NEUMANNDANIEL\spfagent' }
    if ($ACL -eq $null) {
        Write-Host 'Service Reporting SQL Agent Account SSISPackages Directory Security Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Missing'
    }
    else {
        Write-Host 'Service Reporting SQL Agent Account SSISPackages Directory Security Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
        if ($ACL.FileSystemRights -eq 'FullControl') {
            Write-Host 'Service Reporting SQL Agent Account SSISPackages Directory Permission Status: ' -NoNewline
            Write-Host -ForegroundColor Green 'OK'
        }
        else {
            Write-Host 'Service Reporting SQL Agent Account SSISPackages Directory Permission Status: ' -NoNewline
            Write-Host -ForegroundColor Red 'Denied'
        }
    }
    $ACL = Get-Acl -Path $SRPathWD
    $ACL = $ACL.Access | Where-Object { $_.IdentityReference -eq 'NEUMANNDANIEL\spfagent' }
    if ($ACL -eq $null) {
        Write-Host 'Service Reporting SQL Agent Account WorkDir Directory Security Status: ' -NoNewline
        Write-Host -ForegroundColor Red 'Missing'
    }
    else {
        Write-Host 'Service Reporting SQL Agent Account WorkDir Directory Security Status: ' -NoNewline
        Write-Host -ForegroundColor Green 'OK'
        if ($ACL.FileSystemRights -eq 'FullControl') {
            Write-Host 'Service Reporting SQL Agent Account WorkDir Directory Permission Status: ' -NoNewline
            Write-Host -ForegroundColor Green 'OK'
        }
        else {
            Write-Host 'Service Reporting SQL Agent Account WorkDir Directory Permission Status: ' -NoNewline
            Write-Host -ForegroundColor Red 'Denied'
        }
    }
} -ArgumentList $SRPathWD, $SRPathSP