#Requires -Module @{ ModuleName = 'SwisPowerShell'; ModuleVersion = '3.0.309' }

<#
.Synopsis
    Export Modern Dashboards from SolarWinds Orion system
.DESCRIPTION
    Connects to SolarWinds Information Service, extracts the JSON content of a Modern Dashboard and exports it to the file system
.EXAMPLE
    $SwisConnection = Connect-Swis -SwisHost "192.168.11.165" -Username "admin" -Password "MyComplexPassword"
    PS C:\> Set-Location -Path "C:\Exports"
    PS C:\Exports> Export-ModernDashboard -SwisConnection $SwisConnection

    This exports all of the Modern Dashboards to the 'C:\Exports' folder
.EXAMPLE
    $SwisConnection = Connect-Swis -SwisHost "192.168.11.165" -Username "admin" -Password "MyComplexPassword"
    PS C:\> Export-ModernDashboard -SwisConnection $SwisConnection -DashboardId 9  -OutputFolder "D:\OrionServer\Modern Dashboards\"

    This exports the Modern Dashboard with ID 9 to the 'D:\OrionServer\Modern Dashboards\' folder
.EXAMPLE
    $SwisConnection = Connect-Swis -SwisHost "192.168.11.165" -Username "admin" -Password "MyComplexPassword"
    PS C:\> Export-ModernDashboard -SwisConnection $SwisConnection -DashboardId 9 -IncludeId

    This exports the Modern Dashboard with ID 9 to the current folder with the naming format "9_<Dashboard Name>.json"
.NOTES
    Author:  Kevin M. Sparenberg
    Version: 1.5.1
    Last Updated: August 8, 2016

    TBD List:
        * Add/incoporate the check for valid/invalid file names from Utilities
        * -PassThru [switch]
            Mimic a -PassThru parameter that just returns the JSON data to the pipeline
            -AsPsObject [switch] (child of -PassThru)
                Allows for the raw Json to be returned as a PowerShell object
        * Determine a way to filter out "system" dashboards
            Current best guess is that if the unique_key is a GUID, it's a user dashboard

#>
function Export-ModernDashboard {
    [CmdletBinding(
        DefaultParameterSetName = 'Normal', 
        SupportsShouldProcess = $true, 
        PositionalBinding = $false,
        HelpUri = 'https://documentation.solarwinds.com/en/success_center/orionplatform/content/core-fusion-dashboard-import-export.htm',
        ConfirmImpact = 'Medium')]
    [Alias()]
    [OutputType([String])]
    Param
    (
        # The connection to the SolarWinds Information Service
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            ValueFromRemainingArguments = $false, 
            Position = 0,
            ParameterSetName = 'Normal')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("Swis")] 
        [SolarWinds.InformationService.Contract2.InfoServiceProxy]$SwisConnection,

        # The dashboard Id we'll export
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1,
            ParameterSetName = 'Normal')]
        [AllowNull()]
        [int32[]]$DashboardId,

        # Specifies the path to the output file.
        [Parameter(ParameterSetName = 'Normal')]
        [AllowNull()]
        [string]$OutputFolder = ( Get-Location ),

        # Should we include the Dashboard ID number in the name.
        [Parameter(ParameterSetName = 'Normal')]
        [AllowNull()]
        [switch]$IncludeId,

        # Omits white space and indented formatting in the output string.
        [Parameter(ParameterSetName = 'Normal')]
        [AllowNull()]
        [switch]$Compress,

        # Overrides the read-only attribute and overwrites an existing read-only file. The Force parameter does not override security restrictions.
        [Parameter(ParameterSetName = 'Normal')]
        [AllowNull()]
        [switch]$Force

    )

    Begin {
        # if no dashboard ids are provided, assume we export the all, so get the list
        if ( -not $DashboardId ) {
            Write-Verbose -Message "EXPORT ALL: No DashboardIds Provided - exporting all"
            $Swql = "SELECT DashboardID FROM Orion.Dashboards.Instances WHERE ParentID IS NULL"
            $DashboardId = Get-SwisData -SwisConnection $SwisConnection -Query $Swql
        }

        # How deep does the Json go?  From initial testing it looks like 25 is sufficient, this gives flexibility
        $JsonDepth = 25
    }
    Process {
        ForEach ( $d in $DashboardId ) {
            $DashboardText = Invoke-SwisVerb -SwisConnection $SwisConnection -EntityName Orion.Dashboards.Instances -Verb Export -Arguments $d
            
            # The name is stored within the Json file, so we need to load it as Json and interpret it.
            $DashboardObject = $DashboardText.'#text' | ConvertFrom-Json
            $DashboardName = $DashboardObject.dashboards.name

            if ( $IncludeId ) {
                $ExportFilePath = Join-Path -Path $OutputFolder -ChildPath "$( $d )_$( $DashboardName ).json"
            }
            else {
                $ExportFilePath = Join-Path -Path $OutputFolder -ChildPath "$( $DashboardName ).json"
            }
            
            # Check to see if the export file already exists and we are not forcing overwrite
            if ( ( -not ( Test-Path -Path $ExportFilePath -ErrorAction SilentlyContinue ) ) -or ( $Force ) ) {
                # Ask if we want to export
                if ( $pscmdlet.ShouldProcess("to '$OutputFolder'", "Export '$DashboardName'") ) {
                    # Actually do the export
                    Write-Verbose -Message "Exporting '$DashboardName'"
                    $DashboardObject | ConvertTo-Json -Depth $JsonDepth -Compress:$Compress | Out-File -FilePath $ExportFilePath -Force:$Force
                }
            }
            else {
                Write-Warning -Message "Skipping export of '$DashboardName' because '$ExportFilePath' already exists.  If you wish to overwrite, use the '-Force' parameter."
            }
        }
    }
    End {
        # nothing to do here
    }
}


<#
##################################################
Import-ModernDashboard function still to be done
##################################################

function Import-ModernDashboard {
    [CmdletBinding(DefaultParameterSetName = 'Normal', 
        SupportsShouldProcess = $true, 
        PositionalBinding = $false,
        HelpUri = 'https://documentation.solarwinds.com/en/success_center/orionplatform/content/core-fusion-dashboard-import-export.htm',
        ConfirmImpact = 'Hight')]
    [Alias()]
    [OutputType([String])]
    Param
    (
        # The connection to the SolarWinds Information Service
        [Parameter(Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            ValueFromRemainingArguments = $false, 
            Position = 0,
            ParameterSetName = 'Normal')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("Swis")] 
        [SolarWinds.InformationService.Contract2.InfoServiceProxy]$SwisConnection,

        # If a pre-existing dashboard name matches, use a different name
        [Parameter(ParameterSetName = 'Normal')]
        [AllowNull()]
        [switch]$RenameOnConflict,

        [Parameter(ParameterSetName = 'Normal')]        
        [AllowNull()]
        [switch]$Force



    )

    Begin {
    }
    Process {
        if ( $pscmdlet.ShouldProcess("to '$OutputFolder'", "Import '$DashboardName'") ) {
        }
    }
    End {
    }
}
#>