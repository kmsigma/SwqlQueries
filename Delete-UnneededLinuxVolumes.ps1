<#

Simple script to display and then delete unecessary volumes

#>

$SwqlQuery = @"
SELECT [Volumes].Node.Caption AS [Node], [Volumes].VolumeDescription, [Volumes].VolumePercentUsed, [Volumes].Uri
FROM Orion.Volumes AS [Volumes]
WHERE [Volumes].VolumePercentUsed > 90
  AND [Volumes].VolumeType = 'Other'
  AND [Volumes].VolumeDescription IN ( 'Cached memory', 'Shared memory' )
  AND [Volumes].Node.Vendor IN ( 'Synology', 'Linux' )
"@

if ( -not ( $SwisConnection ) )
{
    $OrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the Orion Server"
    $SwisCredentials = Get-Credential -Message "Enter your Orion credentials for $OrionServer"
    $SwisConnection  = Connect-Swis -Credential $SwisCredentials -Hostname $OrionServer
}

$VolumesToDelete = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery
if ( $VolumesToDelete ) {
    Write-Host "Proposed volumes for deletion:" -ForegroundColor Red
    $VolumesToDelete | ForEach-Object { 
        Write-Host "$( $_.VolumeDescription ) on $( $_.Node ) [$( $_.VolumePercentUsed ) % full]" -ForegroundColor Red
    }
    Write-Host "Total Count: $( $VolumesToDelete.Count )" -ForegroundColor Red

    $DoDelete = Read-Host -Prompt "Would you like to proceed? [Type 'delete' to confirm]"
    if ( $DoDelete.ToLower() -eq 'delete' ){
        # This is key - if you have a bunch of URIs and you want to do the same thing on each of them, 
        # you can pipe the contents to either Remove-SwisObject or Set-SwisObject
        $VolumesToDelete.Uri | Remove-SwisObject -SwisConnection $SwisConnection
    } else {
        Write-Host "'delete' response not received - No deletions were processed" -ForegroundColor Yellow
    }
}