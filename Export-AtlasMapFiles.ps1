#Requires -Version 5.1
#Requires -Module @{ ModuleName = 'SwisPowerShell'; ModuleVersion = '2.4.0.176' }

<#
Name:            Export-OrionMaps.ps1
Author:          KMSigma [https://thwack.solarwinds.com/people/KMSigma]
Purpose:         Export the files needed for Network Atlas Maps - useful for when you want to re-use the graphics (Prod <--> Test <--> Dev migrations)
Version History: 1.0 (2018-07-17)
                 - Initial build for THWACKcamp 2018
                 1.1 (2018-10-17)
                 - Updated with progress bars to make it more useful for a large count of files.
                 1.2 (2020-12-02)
                 - Updated with some logic so that converting this to a function will be easier
Requires:
    SolarWinds PowerShell Module (SwisPowerShell) which is documented with the SolarWinds Orion SDK [https://github.com/solarwinds/OrionSDK]
    If you do not have it installed, you can install it in one of two ways:
    1) Install-Module -Name SwisPowerShell
       Installs to the default user's profile
    2) Install-Module -Name SwisPowerShell -Scope AllUsers
       Installs to the computer's profile (available to all users) <-- this is my preferred method
#>
# This should no longer be necessary because of the Requires statment at the beginning
#Import-Module -Name SwisPowerShell -ErrorAction SilentlyContinue
$SwiHost = "nockmsmpe01v.demo.lab"

# Let's collect the credentials to connect to Orion
$SwiCreds = Get-Credential -Message "Enter your Orion Credentials to connect to $SwiHost"

# Where would you like to save the files
$SaveLocation = "D:\Data"

# Do we want to include the SWI Host information in the path?
# This is useful if you run with multiple Orion servers to separate the exports into different folders
$IncludeSwiHostInPath = $true

# Do we want to show the progress bars?
# This is ok in many places, but is especially ugly in VS Code, so let's see if we can detect that
$ShowProgress = ( -not ( $env:TERM_PROGRAM -eq 'vscode' ) )

if ( $IncludeSwiHostInPath ) {
  # Update the save path to include the SWI Host Name
  $SaveLocation = Join-Path -Path $SaveLocation -ChildPath $SwiHost
}

# There are multiple ways to connect to the SolarWinds Information Service
# This example uses the "Orion" credentials.
# Other examples are:
#   Connect-Siws -HostName $SwiHost -Trusted [Logs is as the currently logged in Windows User]
#   Connect-Swis -HostName $SwiHost -Username "admin" -Password "KeepItSecretKeepItSafe" [same as below, but with the username & password in plain text]
$SwisConnection = Connect-Swis -Hostname $SwiHost -Credential $SwiCreds

# This SWQL Query will export all non-deleted files
$SwqlQuery = @"
SELECT FileName, FileData
FROM Orion.MapStudioFiles
WHERE IsDeleted = False
ORDER BY FileName
"@
<#
Notes:
  There is a chance that the FileName value, which is used as the export path, may be duplicated.  This is an exceedingly rare and edge case I'm not taking it into account at this stage.

  The FileTypes stored in the table are integers and appear to be base 2.  These are the ones I know and the associated extensions/types:
    0    - OrionMap
    2    - 'flat' images (backgrounds and things)
    128  - icon images (gif or wmf) as defined on https://documentation.solarwinds.com/en/success_center/orionplatform/Content/Core-Adding-Custom-Icons-from-Graphics-Files-sw3350.htm
    1024 - 'flat' image thumbnails
#>


# Query SWIS for the file information
$SwiFiles = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery

# Cycle through each file and display a counter
For ( $i = 0; $i -lt $SwiFiles.Count; $i++ )
{
    
    if ( $ShowProgress ) {
      # Progress bar showing the how we're progressing
      Write-Progress -Activity "Exporting Map Files" -Status "Exporting $( $SwiFiles[$i].FileName )" -PercentComplete ( ( $i / $SwiFiles.Count ) * 100 )
    }
    
    # Build the output path for the file by combining the save location defined above and the file name
    $ExportFullPath = Join-Path -Path $SaveLocation -ChildPath $SwiFiles[$i].FileName
    # Check to see if the full path exists - it might not.  Let's build it.
    if ( -not ( Test-Path -Path ( Split-Path -Path $ExportFullPath ) -ErrorAction SilentlyContinue ) ) 
    { 
        Write-Verbose -Message "Creating [$( ( Split-Path -Path $ExportFullPath -Parent ) )] Folder"
        New-Item -Path ( Split-Path -Path $ExportFullPath -Parent ) -ItemType Directory | Out-Null
    } 
    
    # We need to see if the file already exists
    if ( ( Test-Path -Path $ExportFullPath -ErrorAction SilentlyContinue ) -and ( -not ( $Force ) ) ) {
      # The file already exists and we are not Forcing an overwrite, we skip the export
      Write-Warning -Message "The file $ExportFullPath already exists, skipping.  To overwrite this file change `$Force to `$true"
    } else {
      # All other scenarios (we are Forcing or the file does not exist), we export
      $SwiFiles[$i].FileData | Set-Content -Path $ExportFullPath -Encoding Byte
      # I'm outputting the results of the "Get-Item" details here in preparation of moving to a function to have a return value
      Get-Item -Path $ExportFullPath
    }
    
}

if ( $ShowProgress ) {
  # Close the progress bar
  Write-Progress -Activity "Exporting Map Files" -Completed
}
# Cleanup - get rid of the SolarWinds-specific variables
#Get-Variable -Name Swi* | Remove-Variable