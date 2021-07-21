<#
.Synopsis
   Function that runs a 'PowerShell' ping and trace route - optionally adds it to an alert note
.NOTES
   To help with https://thwack.solarwinds.com/product-forums/the-orion-platform/f/alert-lab/91386/embedding-output-into-an-alert-email-action

#>
function Test-PingTrace {
    [CmdletBinding(
        HelpUri = 'https://thwack.solarwinds.com/product-forums/the-orion-platform/f/alert-lab/91386/embedding-output-into-an-alert-email-action/',
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low')]
    [Alias()]
    [OutputType([String])]
    Param
    (
        # The IP Address of the thing on which to operate
        [Parameter(Mandatory = $true)]
        [Alias("IP")] 
        [string]$IPAddress,

        # The Alert Object ID - required by the appendNote verb
        [Parameter(Mandatory = $false)]
        [int]$AlertObjectID,

        # Do you want us to update the note or just do the thing?
        [switch]$AddNote,

        # Number of times to try and ping (default to 4)
        [int]$NumPings = 4,

        # Number of times to hop for a trace (default to 15)
        [int]$NumHops = 15
    )

    Begin {
        #### Build Connection to SolarWinds Orion Server ####
        # If we want to update the note, we need to connect to SWIS
        if ( $AddNote ) {
            # Connect to "self" (Local Computername and connect with the certificate)
            $SwisConnection = Connect-Swis -Hostname "$env:COMPUTERNAME" -Certificate
        }
    }
    Process {
        if ( $pscmdlet.ShouldProcess("$IPAddress", "Ping the thing") ) {

            Write-Host "Pinging '$IPAddress' $NumPings times" -ForegroundColor Yellow
            # Using Test-Connection adds a whole bunch of other stuff we don't need, so get the basics
            $PingResults = Test-Connection -ComputerName $IPAddress -Count $NumPings -ErrorAction SilentlyContinue | Select-Object -Property @{ Name = "Source"; Expression = { $_.PSComputerName } }, Address, ReplySize, ResponseTime

            Write-Host "Running Traceroute for '$IPAddress'" -ForegroundColor Yellow
            # Tracing using Test-NetConnection adds a whole bunch of other stuff we don't need, so get the basics
            $TraceRtResults = Test-NetConnection -ComputerName $IPAddress -TraceRoute -Hops $NumHops -ErrorAction SilentlyContinue | Select-Object SourceAddress, RemoteAddress, @{ Name = "RTT"; Expression = { $_.PingReplyDetails.RoundtripTime } }, TraceRoute

            $Note = ""
            Write-Host "Ping Results:" -ForegroundColor Green
            if ( $PingResults ) {
                $PingResults
                $Note +=  @"
Ping Results:
-----------------------------------------------------
Source Address:         $( $env:COMPUTERNAME )
Remote Address:         $( $PingResults[0].Address )
Number of Pings:        $NumPings
Avg Response Time (ms): $( $PingResults | Measure-Object -Property ResponseTime -Average | Select-Object -ExpandProperty Average )

"@                
            }
            else {
                Write-Host "Ping to '$IPAddress' did not return any packets" -ForegroundColor Red
                $Note += @"
Ping Results:
-----------------------------------------------------
Source Address:         $( $env:COMPUTERNAME )
Remote Address:         $IPAddress
Number of Pings:        $NumPings
Avg Response Time (ms): N/A
***** PING FAILED *****

"@
            }


            Write-Host "Trace Results:" -ForegroundColor Green
            if ( $TraceRtResults ) {
                $TraceRtResults
                $Note += @"
Trace Route Results:
-----------------------------------------------------
Source Address:       $( $env:COMPUTERNAME )
Remote Address:       $IPAddress
Round Trip Time (ms): $( $TraceRtResults.RTT )
Hops:
$( $TraceRtResults.TraceRoute | ForEach-Object { "`t$( $_ )`n" } )
"@
            } else {
                Write-Host "Trace to '$IPAddress' did not complete correctly"
                $Note += @"
Trace Route Results:
-----------------------------------------------------
Source Address:       $( $env:COMPUTERNAME )
Remote Address:       $IPAddress
Round Trip Time (ms): N/A
Hops:
    N/A
***** TRACE FAILED *****
"@
            }

            if ( $AddNote ) {
                # Update the Note in Orion
                # Since 'AppendNote' is expecting an array of AlertObjectIds, we can just wrap with @( $thing ) to turn it into an array
                Invoke-SwisVerb -SwisConnection $SwisConnection -EntityName "Orion.AlertActive" -Verb "AppendNote" -Arguments ( @( $AlertObjectID ), $Note ) | Out-Null
            }
        }
    }

    End {
        # Nothing to do here
    }
}