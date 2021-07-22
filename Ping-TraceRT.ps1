<# File Name: Ping-TraceRT.ps1 #>
$Stopwatch = New-Object -TypeName System.Diagnostics.Stopwatch
$Stopwatch.Start()
# Move to the Proper Folder where these scripts 'live'
Write-Host "Execution Path: $( ( Split-Path -Path $MyInvocation.MyCommand.Path -Parent ) )"
Set-Location -Path ( Split-Path -Path $MyInvocation.MyCommand.Path -Parent )

# Check & Import the Test-PingTrace function


if ( -not ( Get-Command -Name Test-PingTrace -ErrorAction SilentlyContinue) ) {
    . .\func_PingTrace.ps1
}

<# Expected Arguments (in order)
    IP Address (to do the ping and tracert)
    alertDefinitionId (up write the note)
    alertObject (for nodes, this is the Node ID)
    objectType (for nodes, this is 'Node')

    Matching SWIS Variable Definition:
    IP Address       = '${N=SwisEntity;M=IP_Address}'
    alertDefinitonId = '${N=Alerting;M=AlertDefID}'
    alertObject      = '${N=SwisEntity;M=NodeID}'
    objectType       = '${N=Alerting;M=ObjectType}'

#>

$IPAddress = $args[0]
$alertDefinitionId = $args[1]
$alertObject = $args[2]
$objectType = $args[3]



$TestResults = Test-PingTrace -IPAddress $IPAddress

if ( $TestResults ) {
    $SwisConnection = Connect-Swis -Hostname "$env:COMPUTERNAME" -Certificate
    Invoke-SwisVerb -SwisConnection $SwisConnection -EntityName "Orion.AlertStatus" -Verb "AddNote" -Arguments ( $alertDefinitionId, $alertObject, $objectType, $TestResults ) | Out-Null
}
$Stopwatch.Stop()
Write-Host "Complete Execution Time: $( $Stopwatch.Elapsed.TotalMinutes.ToString("0.00") ) minutes"