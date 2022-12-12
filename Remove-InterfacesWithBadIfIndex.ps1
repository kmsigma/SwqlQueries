#region Connect to SolarWinds Information Service
if ( -not $SwisConnection ) {
    $Hostname = "orionserver.domain.local"
    $SwisConnection = Connect-Swis -Hostname $Hostname -Credential ( Get-Credential -Message "Enter your Orion credentials for $Hostname" )
}
#endregion Connect to SolarWinds Information Service

# Query to identify interfaces with bad a bad index
$SwqlQuery = @"
SELECT [Interfaces].Node.Caption AS [Node]
     , [Interfaces].Name AS [Name]
     , [Interfaces].Uri
FROM Orion.NPM.Interfaces AS [Interfaces]
WHERE [Interfaces].Index = -1
ORDER BY [Interfaces].Node.Caption
       , [Interfaces].Name
"@

# Store the interfaces as an array
$IntsToDelete = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery

# Cycle through each, say what's being deleted and then delete it.
ForEach ( $Int in $IntsToDelete ) {
    Write-Host "Removing $( $Int.Name ) from $( $Int.Node )" -ForegroundColor Red
    Remove-SwisObject -SwisConnection $SwisConnection -Uri $Int.Uri
}
