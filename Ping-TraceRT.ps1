#Ping-TraceRT.ps1

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
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
        [Parameter(Mandatory = $true)]
        [int]$AlertObjectID,

        # Do you want us to update the note or just do the thing?
        [switch]$AddNote,

        # Number of times to try and ping (default to 4)
        [int]$NumPings = 4
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
            $PingResults = Test-Connection -ComputerName $IPAddress -Count $NumPings -ErrorAction SilentlyContinue | Select-Object -Property @{ Name = "Source"; Expression = { $_.PSComputerName } }, Address, IPV4Address, IPV6Address, ReplySize, ResponseTime

            Write-Host "Running Traceroute for '$IPAddress'" -ForegroundColor Yellow
            # Tracing using Test-NetConnection adds a whole bunch of other stuff we don't need, so get the basics
            $TraceRtResults = Test-NetConnection -ComputerName $IPAddress -TraceRoute -ErrorAction SilentlyContinue | Select-Object SourceAddress, RemoteAddress, @{ Name = "RTT"; Expression = { $_.PingReplyDetails.RoundtripTime } }, TraceRoute

            if ( -not ( $AddNote ) ) {
                Write-Host "Ping Results:" -ForegroundColor Green
                if ( $PingResults ) {
                    $PingResults
                }
                else {
                    Write-Host "Ping to '$IPAddress' did not return any packets" -ForegroundColor Red
                }

                Write-Host "Trace Results:" -ForegroundColor Green
                if ( $TraceRtResults.RTT -ne 0 ) {
                    $TraceRtResults
                }
                else {
                    Write-Host "Unable to trace to '$IPAddress'" -ForegroundColor Red
                }
            }
            else {
                # Build up the text for the note
                $Note = @"
Ping Results:
-----------------------------------------------------
Source Address:         $( $PingResults[0].Source )
Remote Address:         $( $PingResults[0].Address )
Number of Pings:        $NumPings
Avg Response Time (ms): $( $PingResults | Measure-Object -Property ResponseTime -Average | Select-Object -ExpandProperty Average )


Trace Route Results:
-----------------------------------------------------
Source Address:       $( $TraceRtResults.SourceAddress.IPAddress )
Remote Address:       $( $TraceRtResults.RemoteAddress.IPAddressToString )
Round Trip Time (ms): $( $TraceRtResults.RTT )
Hops:
$( $TraceRtResults.TraceRoute | ForEach-Object { "`t$( $_ )`n" } )
"@
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

# Tests
#Test-PingTrace -IPAddress "192.168.0.1" -AlertObjectID 11
#Test-PingTrace -IPAddress "8.8.8.8" -AlertObjectID 5
Test-PingTrace -IPAddress "4.2.2.1" -AlertObjectID 5 -AddNote
