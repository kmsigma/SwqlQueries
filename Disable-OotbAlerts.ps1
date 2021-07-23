<#
Script: Disable-OotbAlerts.ps1

Disables all of the native Out-Of-The-Box alerts.

Original Link: Disabling "Canned" Alerts [https://thwack.solarwinds.com/product-forums/the-orion-platform/f/forum/6986/disabling-canned-alerts]
#>

if ( -not ( $SwisConnection ) ) {
    $OrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the Orion Server"
    $SwisCredentials = Get-Credential -Message "Enter your Orion credentials for $OrionServer"
    $SwisConnection  = Connect-Swis -Credential $SwisCredentials -Hostname $OrionServer
}

$Query = @"
SELECT Name
     , Uri
FROM Orion.AlertConfigurations
WHERE Canned = 'TRUE'
  AND Enabled = 'TRUE'
"@
$Alerts = Get-SwisData -SwisConnection $SwisConnection -Query $Query
ForEach ( $Alert in $Alerts ) {
    Write-Host "Disabling OOTB Alert: $( $Alert.Name )" -ForegroundColor Red
    Set-SwisObject -SwisConnection $SwisConnection `
                   -Uri $Alert.Uri `
                   -Properties @{ Enabled = 'FALSE' }
}
