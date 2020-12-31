<# Export-Configs.ps1

#>
#Requires -Version 5
#Requires -Module @{ ModuleName = 'SwisPowerShell'; ModuleVersion = '2.1.0.0' }

# By default we will export the configs to a folder on the desktop - change this to your prefered folder
$ExportPath = Join-Path -Path ( [System.Environment]::GetFolderPath("Desktop") ) -ChildPath "Configs"

# Set up the hostname, username, and password for the source system
if ( -not ( $SwisConnection ) )
{
    $OrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the Orion Server"
    $SwisCredentials = Get-Credential -Message "Enter your Orion credentials for OrionServer"
    $SwisConnection  = Connect-Swis -Credential $SwisCredentials -Hostname $OrionServer
}

# This SWQL Query will collect the information we need for the configs.
$SwqlQuery = @"
SELECT [Configs].DownloadTime
     , [Configs].NodeProperties.Nodes.Caption
     , [Configs].ConfigType
     , [Configs].Baseline
     , [Configs].Config
FROM NCM.ConfigArchive AS [Configs]
WHERE IsBinary = 'False'
ORDER BY DownloadTime ASC
"@

# Build the initial export folder if necessary
if ( -not ( Test-Path -Path $ExportPath -ErrorAction SilentlyContinue ) ) {
    Write-Host "Creating folder at [$ExportPath]" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ExportPath | Out-Null
}

# Note: The config files themselves can be tens of thousands of characters, so this query may take a little to run
$ConfigList = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery


if ( $ConfigList ) {
    # The following calculated properties are added to our object to allow for consistent naming and folder structure.
    # It's not strictly necessary in this way - it's all on preference.
    # This example is for: [Current User's Desktop Folder]\Configs\[Caption]\[Caption]_[DateString]_[ConfigType](_Baseline).txt
    # The word "Baseline" will be added to the end if it's tagged as a baseline, otherwise, it's omitted

    
    # Manipulate the date to be a better match for sorting
    $ConfigList | Add-Member -MemberType ScriptProperty -Name "DateString" -Value { $this.DownloadTime.ToString("yyyy-MM-dd") } -Force
    # Calculate the directory name for the  of the export file
    $ConfigList | Add-Member -MemberType ScriptProperty -Name "DirectoryName" -Value { Join-Path -Path $ExportPath -ChildPath ( $this.Caption ) } -Force
    # Calculate the file name
    $ConfigList | Add-Member -MemberType ScriptProperty -Name "FileName" -Value { "$( $this.Caption )_$( $this.DateString )_$( $this.ConfigType )$( if ( $this.Baseline ) { "_Baseline" } ).txt" } -Force
    # Figure out the full file name for export
    $ConfigList | Add-Member -MemberType ScriptProperty -Name "FullName" -Value { Join-Path -Path $this.DirectoryName -ChildPath $this.FileName } -Force

    # Not to cycle through each one
    ForEach ( $Config in $ConfigList ) {
        # We need to see if the folder already exists, and if not create it
        if ( -not ( Test-Path -Path $Config.DirectoryName -ErrorAction SilentlyContinue ) ) {
            Write-Host "Creating folder at [$( $Config.DirectoryName )]" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $Config.DirectoryName | Out-Null
        }
        Write-Host "`tWriting out $( $Config.FileName )"
        $Config.Config | Out-File -FilePath $Config.FullName -Encoding ASCII -Force
    }
}
else {
    Write-Host "No Configurations Found" -ForegroundColor Red
}
