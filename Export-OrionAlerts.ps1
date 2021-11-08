<# 
Export all the alerts from Orion.  Overwrites existing XML files by default.

Tested on Orion Platform 2020.2.5
#>

$Swql = @"
SELECT AlertID
     , Name
FROM Orion.AlertConfigurations
ORDER BY AlertID
"@

if ( -not ( $SwisConnection ) ) {
    $SwisHost = Read-Host -Prompt "Provide the IP or FQDN of your Orion server"

    if ( -not ( $SwisCreds ) ) {
        $SwisCreds = Get-Credential -Message "Enter your Orion credentials for $SwisHost"
    }

    if ( $SwisHost -and $SwisCreds ) {
        $SwisConnection = Connect-Swis -Hostname $SwisHost -Credential $SwisCreds
    }
}
$ExportPath = ".\AlertExports\"

$SwisConnection = Connect-Swis -Hostname $SwisHost -Credential $SwisCreds
$AlertList = Get-SwisData -SwisConnection $SwisConnection -Query $Swql

# Check to see if the Export Path exists.  If not, then create it.
if ( -not ( Test-Path -Path $ExportPath -ErrorAction SilentlyContinue ) ) {
    $ExportRoot = New-Item -ItemType Directory -Path $ExportPath
}
else {
    $ExportRoot = Get-Item -Path $ExportPath
}

For ( $i = 0; $i -lt $AlertList.Count; $i++ ) {
    Write-Progress -Activity "Export Alerts from $SwisHost" -CurrentOperation "Processing $( $AlertList[$i].Name )" -PercentComplete ( ( $i / $AlertList.Count ) * 100 )
    # Arguments for the Orion.AlertConfigurations / Export verb:
    # [int]AlertId (mandatory)
    # [bool]StripSensitiveData (optional)
    # [string]ProtectionPassword (optional)
    $ExportArguments = $AlertList[$i].AlertID #, $false, "strongPassword"

    $FileName = [System.Web.HttpUtility]::UrlEncode($AlertList[$i].Name) + '.xml'

    # Build the full path name to the file (needed for the export)
    $FilePath = Join-Path -Path $ExportRoot -ChildPath $FileName
    
    try {
        # Pull the alert definition and then just select the actual XML
        $Export = Invoke-SwisVerb -SwisConnection $SwisConnection -EntityName "Orion.AlertConfigurations" -Verb "Export" -Arguments $ExportArguments -ErrorAction SilentlyContinue
        if ( $Export ) {
            $RawXml = $Export.InnerText
            ( [xml]$RawXml ).Save($FilePath)
        }
    }
    catch { 
        Write-Error -Message "Processing Error on $( $AlertList[$i].Name ) / [$( $AlertList[$i].AlertId )]"
    }
}
Write-Progress -Activity "Export Alerts from $SwisHost" -Completed
