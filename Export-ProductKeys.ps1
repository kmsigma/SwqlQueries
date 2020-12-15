<#

Export-ProductKeys.ps1

This script exports the product keys from your SolarWinds Orion instance to a CSV on your current desktop

This is useful if you plan on migrating to new hardware.

Tested with Core 2020.2.1 HF1

#>

if ( -not ( $SwisCreds ) )
{
    $SwisCreds = Get-Credential -Message "Enter your Orion credentials"
}
$SwisConnection = Connect-Swis -Hostname "<Hostname or IP Address>" -Credential $SwisCreds

# Get the EngineIDs for your Orion Servers"

$SwqlOrionServerLicenses = @"
SELECT [Licenses].OrionServer.Hostname
     , [Licenses].OrionServer.ServerType
     , CASE [Licenses].ProductName
        WHEN 'SAM' THEN 'Server & Application Monitor'
        WHEN 'WPM' THEN 'Web Performance Monitor'
        WHEN 'VNQM' THEN 'Voice & Network Quality Monitor'
        WHEN 'VM' THEN 'Virtualization Manager'
        WHEN 'UDT' THEN 'User Device Tracker'
        WHEN 'STM' THEN 'Storage Resource Monitor'
        WHEN 'SCM' THEN 'Server Configuration Monitor'
        WHEN 'NCM' THEN 'Network Configuration Monitor'
        WHEN 'IPAM' THEN 'IP Address Manager'
        WHEN 'NPM' THEN 'Network Performance Monitor'
        WHEN 'Orion NetFlow Traffic Analyzer' THEN 'NetFlow Traffic Analyzer'
        WHEN 'LM' THEN 'Log Analyzer'
        WHEN 'WebToolset' THEN 'Enterprise Toolset'
       END AS [Product]
     , [Licenses].LicenseKey
FROM Orion.Licensing.LicenseAssignments AS [Licenses]
ORDER BY [Product]

"@

$LicenseData = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlOrionServerLicenses
$LicenseData | Export-Csv -Path ( Join-Path -Path ( [System.Environment]::GetFolderPath("Desktop") ) -ChildPath "OrionLicenses.csv" ) -Force -NoTypeInformation
