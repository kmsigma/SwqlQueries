# Asssumes you have authenticated and stored your info in $SwisConnection
$NodeID = 1009
$Job = Invoke-SwisVerb -SwisConnection $SwisConnection -Entity 'Orion.Nodes' -Verb 'ScheduleListResources' -Arguments $NodeID
$Timer = New-Object -TypeName 'System.Diagnostics.Stopwatch'
# Set an overall timeout
$Timeout = 600 # seconds
if ( $Job ) {
    # We got back job information - extract the JobId
    $JobID = $Job.InnerText
    # Validate that the jobID is in a GUID format
    if ( $JobID -match '[a-f,0-9,A-F]{8}-[a-f,0-9,A-F]{4}-[a-f,0-9,A-F]{4}-[a-f,0-9,A-F]{4}-[a-f,0-9,A-F]{12}' ) {
        # Starting the stopwatch
        $Timer.Restart()
        do {
            # if we go over time, just break out of the loop
            if ( $Timer.Elapsed.TotalSeconds -gt $Timeout ) {
                break
            }
            # Get the Job Status
            $JobStatus = Invoke-SwisVerb -SwisConnection $SwisConnection -Entity 'Orion.Nodes' -Verb 'GetScheduledListResourcesStatus' -Arguments $JobID, $NodeID
            # Pull the status text
            $Status = $JobStatus.InnerText
            
            # if the status text isn't ReadyForImport, sleep for 15 seconds.
            if ( $Status -ne 'ReadyForImport' ) {
                Write-Warning -Message "Current status is: $Status for $JobID / Waiting for 15 seconds and trying again"
                Start-Sleep -Seconds 15
            }
        } while ( $Status -ne 'ReadyForImport' ) 
        # Stop the timer
        $Timer.Stop()
        if ( $Status = 'ReadyToImport' ) {
            # Import the Results
            Write-Host "Ready to import!" -ForegroundColor Green
        }
        else {
            Write-Error -Message "Timed out waiting for a result on on $NodeID / $JobID [Last Status: $Status]"
        }
    }
}
else {
    # Job request failed
    Write-Errors -Message "Unable to create a List Resources job for node with ID: $NodeID"
}

