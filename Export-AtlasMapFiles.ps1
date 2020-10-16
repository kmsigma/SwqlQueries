<#
------------------------------------------------------------------------------------------------------
File Name:   Export-AtlasMapFiles.ps1
Author:      Kevin M.  Sparenberg (https://thwack.solarwinds.com/people/KMSigma)
------------------------------------------------------------------------------------------------------
Purpose:
  This script will export the Network Atlas Maps (and associated files) from an active Orion System.  By default this script will export ALL maps and associated files  (including images).  To change it to only export hte AtlasMap files comment out or remove the "Exports only the Maps" region.
  Export Path is to the current user's desktop.  This can be modified within the "Setup Variables & Connect to the SolarWinds Information Service (SWIS)" region.
IMPORTANT NOTE:
  This exports the files used by Network Atlas and not Orion Maps.
Prerequisites:
  You must have OrionSDK Installed (Link:  https://thwack.solarwinds.com/community/labs_tht/orion-sdk)
  (tested with version 1.10)
Version History: [P = Past, C = Current]
  (P) 1.0.0 - Initial Release (2015-07-22)
  (C) 1.0.1 - Update the path check for custom icons (2015-08-10)
Tested against:
  Orion Platform  2015.1.2
  SAM 6.2.1
  DPA 9.2.0
  QoE 2.0
  IPAM 4.3
  NCM 7.4
  NPM 11.5.2
  NTA 4.1.1
  OGS 1.0.10
  WPM 2.2.0
  SRM 6.1.11
  Toolset 11.0.1
  UDT 3.2.2
  IVIM 2.1.0
  VNQM 4.2.2
------------------------------------------------------------------------------------------------------
#>
# Set up the hostname, username, and password for the source system
if ( -not ( SwisConnection ) )
{
    $OrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the Orion Server"
    $SwisCredentials = Get-Credential -Message "Enter your Orion credentials for OrionServer"
    $SwisConnection  = Connect-Swis -Credential $SwisCredentials -Hostname $OrionServer
}
# Export Path for the Files
$ExportPath = "$env:userprofile\Desktop\AtlasMapFiles"
#endregion

#region Exports the Maps Only‌
$SwqlQuery = @"
SELECT FileName
     , FileData
FROM Orion.MapStudioFiles
WHERE FileType = 0 AND IsDeleted = False
ORDER BY FileName
"@
#endregion

#region Exports the Maps and any associated files
$SwqlQuery = @"
SELECT FileName
     , FileData
FROM Orion.MapStudioFiles
WHERE IsDeleted = False
ORDER BY FileName
"@
#endregion

#region Collect the files to a local object
$AtlasMapFiles = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery
Remove-Variable -Name SwisConnection -Force -Confirm:$false -ErrorAction SilentlyContinue
$TotalMapFiles = $AtlasMapFiles.Count
#endregion

#region Check for Path Existence.  If the path doesn't exist, then it's created.
if ( -not ( Test-Path -Path $ExportPath -ErrorAction SilentlyContinue ) )
{
    Write-Host "Path: '$ExportPath' does not  exist.`nCreating Export  Folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ExportPath | Out-Null
}
#endregion

#region Cycle through each file and export to the file system
For ( $i = 0; $i -lt $TotalMapFiles; $i++ )
{
    Write-Progress -Activity "Exporting Network Atlas Map Files" -CurrentOperation "Exporting $( $AtlasMapFiles[$i].FileName )" -Status "Exporting $( $AtlasMapFiles[$i].FileData.Length ) bytes" -PercentComplete ( ( $i / $TotalMapFiles ) * 100 )
    #region Added for verison 1.0.1 for Custom Icons
    # Check for  the "Full Path" and create it, if it doesn't exist.
    $ExportFullPath = ( Join-Path -Path $ExportPath -ChildPath $AtlasMapFiles[$i].FileName )
    $ExportDirectory = Split-Path -Path $ExportFullPath -Parent
    if ( -not ( Test-Path -Path $ExportDirectory -ErrorAction SilentlyContinue ) )
    {
        Write-Warning "Creating [$( $ExportDirectory )] Folder"
        New-Item -Path $ExportDirectory -ItemType Directory | Out-Null
    }
    #endregion
    # This was the trickiest bit - but was made easier when I realized I could encode as bytes.
    $AtlasMapFiles[$i].FileData | Set-Content -Path ( Join-Path -Path $ExportPath -ChildPath $AtlasMapFiles[$i].FileName ) -Encoding Byte -Force
}
Remove-Variable AtlasMapFiles
Write-Progress -Activity "Exporting Network Atlas Map Files" -Completed
#endregion
