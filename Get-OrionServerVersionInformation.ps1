<#

Get-OrionServerVersionInformation.ps1

Gets the installed product versions of SolarWinds products installed in your infrastructure


Results appear like this:

Hostname     ServerType Product                          Version     
--------     ---------- -------                          -------     
NOCKMSMPE01V MainPoller IP Address Manager               2020.2.1    
NOCKMSMPE01V MainPoller Log Analyzer                     2020.2.1    
NOCKMSMPE01V MainPoller NetFlow Traffic Analyzer         2020.2.1 HF2
NOCKMSMPE01V MainPoller Network Configuration Manager    2020.2.1 HF1
NOCKMSMPE01V MainPoller Network Performance Monitor      2020.2.1    
NOCKMSMPE01V MainPoller Orion Platform                   2020.2.1 HF1
NOCKMSMPE01V MainPoller Server & Application Monitor     2020.2.1 HF1
NOCKMSMPE01V MainPoller Server Configuration Monitor     2020.2.1    
NOCKMSMPE01V MainPoller Storage Resource Monitor         2020.2.1    
NOCKMSMPE01V MainPoller User Device Tracker              2020.2.1 HF1
NOCKMSMPE01V MainPoller VoIP and Network Quality Manager 2020.2.1    
NOCKMSMPE01V MainPoller Web Performance Monitor          2020.2.1    

#>


if ( -not ( $SwisCreds ) )
{
    $SwisCreds = Get-Credential -Message "Enter your Orion credentials"
}
$SwisConnection = Connect-Swis -Hostname "<Orion Server IP or HostName>" -Credential $SwisCreds

# Get the details for your Orion Servers

$SwqlOrionServerData = @"
SELECT HostName,
       ServerType,
       Details 
FROM  Orion.OrionServers 
"@

# Build an empty report for the version information
$VersionReport = @()

# List of actual product names (ignoring "features" that appear like products
$ProductNames = "IP Address Manager", "Log Analyzer", "NetFlow Traffic Analyzer", "Network Configuration Manager", "Network Performance Monitor", "Orion Platform", "Server & Application Monitor", "Server Configuration Monitor", "Storage Resource Monitor", "User Device Tracker", "VoIP and Network Quality Manager", "Web Performance Monitor"


$ServerData = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlOrionServerData

# Cycle through each server found
ForEach ( $Server in $ServerData )
{
    # Get the information from the JSON blob
    ForEach ( $Product in ( $Server.Details | ConvertFrom-Json ) | Select-Object -Property Name, Version, HotfixVersionNumber | Sort-Object -Property Name, Version, HotfixVersionNumber )
    {
        # Here's where we ignore the "features" that are listed like a product
        if ( $Product.Name -in $ProductNames )
        {
            if ( $Product.HotfixVersionNumber )
            {
                # if a hotfix exists, add that at the end of the the version number
                $VersionReport += New-Object -TypeName PSObject -Property ( [ordered]@{ Hostname = $Server.Hostname; ServerType = $Server.ServerType; Product = $Product.Name; Version = "$( $Product.Version ) HF$( $Product.HotfixVersionNumber )" } )
            }
            else
            {
                # if it doesn't exist, just show the version number
                $VersionReport += New-Object -TypeName PSObject -Property ( [ordered]@{ Hostname = $Server.Hostname; ServerType = $Server.ServerType; Product = $Product.Name; Version = $Product.Version } )
            }
        }
    }
}
# Output the report
$VersionReport

