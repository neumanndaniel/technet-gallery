<#
    .SYNOPSIS
     Install the Azure like chargeback with System Center & Windows Azure Pack solution.
    .DESCRIPTION
     Install the Azure like chargeback with System Center & Windows Azure Pack solution.
    .NOTES
        File Name : Install-ChargebackReport.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 R2 Service Management Automation PowerShell Cmdlets
        Version   : 1.0
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io/azure-like-chargeback-with-system-center-windows-azure-pack-part-2
#>
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$WebServiceEndPoint = [Microsoft.VisualBasic.Interaction]::InputBox("Enter SMA Web Service Endpoint", "SMA Web Service Endpoint", "https://" + "$env:COMPUTERNAME.$env:USERDNSDOMAIN")
$Port = [Microsoft.VisualBasic.Interaction]::InputBox("Enter SMA Web Endpoint Port", "SMA Web Endpoint Port", "9090")
$DataSource = "SRV-5.neumanndaniel.local\SR"
$Database = "UsageAnalysisDB"
$VMMServer = "SRV-1.neumanndaniel.local"
[String]$ComputeCost = 0.050275
[String]$ComputeCostFactor = 1.333167578319244
[String]$StorageCost = 0.0373
[String]$TransactionCost = 0.0027
Set-SmaVariable -Name 'Service Reporting Analysis Services' -Value $DataSource -WebServiceEndpoint $WebServiceEndPoint -Port $Port
Set-SmaVariable -Name 'Service Reporting Analysis Services Database' -Value $Database -WebServiceEndpoint $WebServiceEndPoint -Port $Port

Set-SmaVariable -Name 'Compute Cost' -Value $ComputeCost -WebServiceEndpoint $WebServiceEndPoint -Port $Port
Set-SmaVariable -Name 'Compute Cost Factor' -Value $ComputeCostFactor -WebServiceEndpoint $WebServiceEndPoint -Port $Port
Set-SmaVariable -Name 'Storage Cost' -Value $StorageCost -WebServiceEndpoint $WebServiceEndPoint -Port $Port
Set-SmaVariable -Name 'Storage Transaction Cost' -Value $TransactionCost -WebServiceEndpoint $WebServiceEndPoint -Port $Port

Set-SmaVariable -Name 'Chargeback Email From' -Value 'wapack@neumanndaniel.de' -WebServiceEndpoint $WebServiceEndPoint -Port $Port
Set-SmaVariable -Name 'Chargeback Email Server' -Value 'srv-5.neumanndaniel.local' -WebServiceEndpoint $WebServiceEndPoint -Port $Port

Import-SmaRunbook -Path .\Invoke-ChargebackReport.ps1 -Tags 'ServiceReporting' -WebServiceEndpoint $WebServiceEndPoint -Port $Port
Import-SmaRunbook -Path .\Send-ChargebackReport.ps1 -Tags 'ServiceReporting' -WebServiceEndpoint $WebServiceEndPoint -Port $Port