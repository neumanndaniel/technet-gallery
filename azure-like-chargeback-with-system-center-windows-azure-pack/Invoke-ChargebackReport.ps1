<#
    .SYNOPSIS
     Example for querying the DW of Service Reporting.
    .DESCRIPTION
     Example for querying the DW of Service Reporting and getting the usage metering information for a chargeback report.
     This runbook is part of the Azure like chargeback with System Center & Windows Azure Pack solution.
    .NOTES
        File Name : Invoke-ChargebackReport.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 R2 Virtual Machine Manager PowerShell Cmdlets
                    System Center 2012 R2 Service Management Automation
        Version   : 1.0
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io/azure-like-chargeback-with-system-center-windows-azure-pack-part-2
#>
workflow Invoke-ChargebackReport {
    $Connection = Get-AutomationConnection -Name 'SCVMM Connect'
    $VMMServer = $Connection.ComputerName
    $Password = ConvertTo-SecureString $Connection.Password -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Connection.UserName, $Password

    #Variables for SQL Server Analysis Services, Costs, Factor
    $DataSource = Get-AutomationVariable -Name 'Service Reporting Analysis Services'
    $Database = Get-AutomationVariable -Name 'Service Reporting Analysis Services Database'
    [Double]$ComputeCost = Get-AutomationVariable -Name 'Compute Cost'
    [Double]$ComputeCostFactor = Get-AutomationVariable -Name 'Compute Cost Factor'
    [Double]$StorageCost = Get-AutomationVariable -Name 'Storage Cost'
    [Double]$TransactionCost = Get-AutomationVariable -Name 'Storage Transaction Cost'

    InlineScript {
        #Getting Tenants
        $ConnectVMMServer = Get-SCVMMServer -ComputerName $USING:VMMServer -Credential $USING:Credential
        $Tenants = Get-SCUserRole

        foreach ($Tenant in $Tenants) {
            $Username = $Tenant.Name
            $Year =
            if ((Get-Date).Month -eq 1) {
                "CY" + (Get-Date).AddYears(-1).Year
            }
            else {
                "CY" + (Get-Date).Year
            }
            $Month = (Get-Date).AddMonths(-1).Month
            $query = "SELECT NON EMPTY { [Measures].[MemoryUsage-Monthly], [Measures].[DiskIOPS-Monthly], [Measures].[CoreAllocated-Monthly], [Measures].[DiskSpaceUsage-Monthly], [Measures].[TotalVMRunTime-Monthly] } ON COLUMNS, NON EMPTY { ([DateDim].[CalendarMonth].[CalendarMonth].ALLMEMBERS * [VirtualMachineDim].[DisplayName].[DisplayName].ALLMEMBERS ) } DIMENSION PROPERTIES MEMBER_CAPTION, MEMBER_UNIQUE_NAME ON ROWS FROM ( SELECT ( { [DateDim].[CalendarMonth].&[$Year]&[$Month] } ) ON COLUMNS FROM ( SELECT ( { [UserRoleDim].[DisplayName].&[$Username] } ) ON COLUMNS FROM [SRUsageCube])) WHERE ( [UserRoleDim].[DisplayName].&[$Username] ) CELL PROPERTIES VALUE, BACK_COLOR, FORE_COLOR, FORMATTED_VALUE, FORMAT_STRING, FONT_NAME, FONT_SIZE, FONT_FLAGS"

            switch ($Month) {
                1 { $TotalDate = $Year + "-Jan" }
                2 { $TotalDate = $Year + "-Feb" }
                3 { $TotalDate = $Year + "-Mar" }
                4 { $TotalDate = $Year + "-Apr" }
                5 { $TotalDate = $Year + "-May" }
                6 { $TotalDate = $Year + "-Jun" }
                7 { $TotalDate = $Year + "-Jul" }
                8 { $TotalDate = $Year + "-Aug" }
                9 { $TotalDate = $Year + "-Sep" }
                10 { $TotalDate = $Year + "-Oct" }
                11 { $TotalDate = $Year + "-Nov" }
                12 { $TotalDate = $Year + "-Dec" }
            }

            [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.AdomdClient") | Out-Null
            $connectionString = "Data Source=$USING:DataSource;Catalog=$USING:Database"
            [Microsoft.AnalysisServices.AdomdClient.AdomdConnection]$connection = $connectionString
            $connection.Open()
            $Command = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdCommand($query, $connection)
            $dataAdapter = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdDataAdapter($command)
            $ds = New-Object System.Data.DataSet
            $dataAdapter.Fill($ds) | Out-Null
            $connection.Close();

            $i = 0
            $ChargebackReport = @()
            foreach ($entry in $ds.Tables[0]) {
                #Ratio CPU:RAM calculation
                $Ratio = 1
                if ($entry."[Measures].[TotalVMRunTime-Monthly]" -eq 0) {

                }
                else {
                    [Int32]$CPUCores = "{0:N0}" -f ($entry."[Measures].[CoreAllocated-Monthly]"/$entry."[Measures].[TotalVMRunTime-Monthly]")
                    [Int32]$RAM = "{0:N0}" -f (($entry."[Measures].[MemoryUsage-Monthly]"/$entry."[Measures].[TotalVMRunTime-Monthly]")/1024)
                    if (($CPUCores/$RAM) -eq 1) {
                        $Ratio = $CPUCores
                    }
                    else {
                        $Ratio = $CPUCores*$USING:ComputeCostFactor
                    }
                }

                $Info = New-Object PSObject -Property @{
                    Month               = $entry."[DateDim].[CalendarMonth].[CalendarMonth].[MEMBER_CAPTION]"
                    VM                  = $entry."[VirtualMachineDim].[DisplayName].[DisplayName].[MEMBER_CAPTION]"
                    Runtime             = $entry."[Measures].[TotalVMRunTime-Monthly]"/4
                    Storage             =
                    if ($entry."[Measures].[TotalVMRunTime-Monthly]" -eq 0) {
                        $entry."[Measures].[DiskSpaceUsage-Monthly]"/30
                    }
                    else {
                        $entry."[Measures].[DiskSpaceUsage-Monthly]"/$entry."[Measures].[TotalVMRunTime-Monthly]"
                    }
                    Transactions        = $entry."[Measures].[DiskIOPS-Monthly]"
                    Cores               =
                    if ($entry."[Measures].[TotalVMRunTime-Monthly]" -eq 0) {
                        0
                    }
                    else {
                        $entry."[Measures].[CoreAllocated-Monthly]"/$entry."[Measures].[TotalVMRunTime-Monthly]"
                    }
                    RAM                 =
                    if ($entry."[Measures].[TotalVMRunTime-Monthly]" -eq 0) {
                        0
                    }
                    else {
                        $entry."[Measures].[MemoryUsage-Monthly]"/$entry."[Measures].[TotalVMRunTime-Monthly]"
                    }
                    PricingCompute      = ($entry."[Measures].[TotalVMRunTime-Monthly]"/4)*$USING:ComputeCost*$Ratio
                    PricingStorage      =
                    if ($entry."[Measures].[TotalVMRunTime-Monthly]" -eq 0) {
                        ($entry."[Measures].[DiskSpaceUsage-Monthly]"/30)*$USING:StorageCost
                    }
                    else {
                        ($entry."[Measures].[DiskSpaceUsage-Monthly]"/$entry."[Measures].[TotalVMRunTime-Monthly]")*$USING:StorageCost
                    }
                    PricingTransactions = ($entry."[Measures].[DiskIOPS-Monthly]"/100000)*$USING:TransactionCost
                    TotalCosts          = ""
                }
                $ChargebackReport += $Info
                $i += $Info.PricingCompute + $Info.PricingStorage + $Info.PricingTransactions
            }

            $Info = New-Object PSObject -Property @{
                Month               = $TotalDate
                VM                  = "Total VM Costs in EUR:"
                Runtime             = ""
                Storage             = ""
                Transactions        = ""
                Cores               = ""
                RAM                 = ""
                PricingRuntime      = ""
                PricingStorage      = ""
                PricingTransactions = ""
                TotalCosts          = $i
            }
            $ChargebackReport += $Info
            $ChargebackReport | Select-Object -Property Month, VM, @{Label = "Runtime in hours"; Expression = { "{0:N2}" -f ($_.Runtime) } }, @{Label = "Disk Space Usage in GB"; Expression = { "{0:N2}" -f ($_.Storage) } }, @{Label = "Storage Transactions"; Expression = { "{0:N2}" -f ($_.Transactions) } }, @{Label = "Compute Costs in EUR"; Expression = { "{0:N2}" -f ($_.PricingCompute) } }, @{Label = "Storage Costs in EUR"; Expression = { "{0:N2}" -f ($_.PricingStorage) } }, @{Label = "Transactions Costs in EUR"; Expression = { "{0:N2}" -f ($_.PricingTransactions) } }, @{Label = "Final Costs in EUR"; Expression = { "{0:N2}" -f ($_.PricingCompute + $_.PricingStorage + $_.PricingTransactions) } }, @{Label = "Total Costs in EUR"; Expression = { "{0:N2}" -f ($_.TotalCosts) } } | Export-CSV -Path "C:\Chargeback\$Username.$Month.$Year.csv" -NoTypeInformation -Delimiter ";"
            $Output = $TotalDate + ' chargeback processed for Tenant: ' + $Username
            Write-Output $Output
        }
    }
    Send-ChargebackReport
}