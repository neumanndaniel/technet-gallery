<#
    .SYNOPSIS
     Sending the chargeback report to the tenant.
    .DESCRIPTION
     This runbook is part of the Azure like chargeback with System Center & Windows Azure Pack solution.
    .NOTES
        File Name : Send-ChargebackReport.ps1
        Author    : Daniel Neumann
        Requires  : PowerShell Version 3.0
                    System Center 2012 R2 Virtual Machine Manager PowerShell Cmdlets
                    System Center 2012 R2 Service Management Automation
        Version   : 1.0
    .LINK
        To provide feedback or for further assistance visit:
        https://www.danielstechblog.io/azure-like-chargeback-with-system-center-windows-azure-pack-part-2
#>
workflow Send-ChargebackReport {
    $Connection = Get-AutomationConnection -Name 'SCVMM Connect'
    $VMMServer = $Connection.ComputerName
    $Password = ConvertTo-SecureString $Connection.Password -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Connection.UserName, $Password

    $ChargebackEmailFrom = Get-AutomationVariable -Name 'Chargeback Email From'
    $ChargebackEmailServer = Get-AutomationVariable -Name 'Chargeback Email Server'

    InlineScript {
        #Getting Tenants
        $ConnectVMMServer = Get-SCVMMServer -ComputerName $USING:VMMServer -Credential $USING:Credential
        $Tenants = Get-SCUserRole

        foreach ($Tenant in $Tenants) {
            $Username = $Tenant.Name
            $TenantName = $Username.Split("@")[0]
            $ChargebackEmailTo = $Username.Split("@")[0] + "@neumanndaniel.de"
            $Year =
            if ((Get-Date).Month -eq 1) {
                "CY" + (Get-Date).AddYears(-1).Year
            }
            else {
                "CY" + (Get-Date).Year
            }
            $Month = (Get-Date).AddMonths(-1).Month

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
            $Attachment = "C:\Chargeback\$Username.$Month.$Year.csv"
            $SMTPSubject = 'Your invoice for the period ' + $TotalDate
            $SMTPBody = '<p style="font-size: 12pt; font-family: arial">Dear ' + $TenantName + ',</p>
            <p style="font-size: 12pt; font-family: arial">you find your invoice and chargeback report attached.</p>
            <p style="font-size: 12pt; font-family: arial">Best regards,<br>
            Your WAPack solutions team</p>
            <p style="font-size: 8pt; font-family: arial">Email: <font color="#0000ff">' + $USING:ChargebackEmailFrom + '</font></p>'
            Send-MailMessage -To $ChargebackEmailTo -From $USING:ChargebackEmailFrom -SmtpServer $USING:ChargebackEmailServer -Subject $SMTPSubject -Body $SMTPBody -BodyAsHtml -Attachments $Attachment
        }
    }
}