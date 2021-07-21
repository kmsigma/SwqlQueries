<# File Name: Ping-TraceRT.ps1 #>

# Move to the Proper Folder where these scripts 'live'
Write-Host "Execution Path: $( ( Split-Path -Path $MyInvocation.MyCommand.Path -Parent ) )"
Set-Location -Path ( Split-Path -Path $MyInvocation.MyCommand.Path -Parent )

# Check & Import the Test-PingTrace function


if ( -not ( Get-Command -Name Test-PingTrace -ErrorAction SilentlyContinue) ) {
    . .\func_PingTrace.ps1
}

<# Expected Arguments
    First argument: IP Address
    Second argument: AlertObjectID
#>

if ( $args[0] ) {
    $IPAddress = $args[0]

}
if ( $args[1]) {
    $AlertObectID = $args[1]
    $UpdateNote   = $true
} else {
    $UpdateNote   = $false
}


Test-PingTrace -IPAddress $IPAddress -AlertObjectID $AlertObectID -AddNote:$UpdateNote