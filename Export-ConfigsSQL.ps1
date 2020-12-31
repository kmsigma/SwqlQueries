<# Export-Configs.ps1

#>
#Requires -Version 5
#Requires -Module @{ ModuleName = 'SqlServer'; ModuleVersion = '21.0.0.0' }

# By default we will export the configs to a folder on the desktop - change this to your prefered folder
$ExportPath = Join-Path -Path ( [System.Environment]::GetFolderPath("Desktop") ) -ChildPath "Configs"

# Set up the hostname, username, and password for the source SQL server
$SqlServerInstance = "SqlServer.Domain.Local" # or "SqlServer.Domain.Local\InstanceName"
$SqlDatabase       = "SolarWindsOrion"
$SqlUsername       = "SolarWindsOrionDatabaseUser"
$SqlPassword       = "ThisIsNotMyPassword"


$SqlQuery = @"
SELECT [Nodes].[NodeCaption] AS [Caption]
     , [Configs].[DownloadTime]
     , [Configs].[ConfigType]
     , [Configs].[Config]
     , [Configs].[Baseline]
  FROM [NCM_ConfigArchive] AS [Configs]
  INNER JOIN NCM_Nodes AS [Nodes]
    ON [Configs].NodeID = [Nodes].NodeID
WHERE [Configs].IsBinary = 0
ORDER BY DownloadTime ASC
"@

# Build the initial export folder if necessary
if ( -not ( Test-Path -Path $ExportPath -ErrorAction SilentlyContinue ) ) {
    Write-Host "Creating folder at [$ExportPath]" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ExportPath | Out-Null
}

$ConfigList = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $SqlServerInstance -Database $SqlDatabase -Username $SqlUsername -Password $SqlPassword

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
