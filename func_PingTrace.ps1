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

        # Number of times to try and ping (default to 4)
        [int]$NumPings = 4,

        # Number of times to hop for a trace (default to 15)
        [int]$NumHops = 15
    )

    Begin {
        # Nothing to see here
    }
    Process {
        if ( $pscmdlet.ShouldProcess("$IPAddress", "Ping the thing") ) {

            Write-Verbose -Message "Sending $NumPings to '$IPAddress'"
            # Using Test-Connection adds a whole bunch of other stuff we don't need, so get the basics
            $PingResults = Test-Connection -ComputerName $IPAddress -Count $NumPings -ErrorAction SilentlyContinue | Select-Object -Property @{ Name = "Source"; Expression = { $_.PSComputerName } }, Address, ReplySize, ResponseTime

            Write-Verbose -Message "Running a trace to '$IPAddress' with up to $NumHops hops"
            # Tracing using Test-NetConnection adds a whole bunch of other stuff we don't need, so get the basics
            $TraceRtResults = Test-NetConnection -ComputerName $IPAddress -TraceRoute -Hops $NumHops -ErrorAction SilentlyContinue | Select-Object SourceAddress, RemoteAddress, @{ Name = "RTT"; Expression = { $_.PingReplyDetails.RoundtripTime } }, TraceRoute

            # Start with an empty Note
            $Note = ""
            if ( $PingResults ) {
                # Add the ping success information to the Note
                $Note += @"
Ping Results:
-----------------------------------------------------
Source Address:         $( $env:COMPUTERNAME )
Remote Address:         $( $PingResults[0].Address )
Number of Pings:        $NumPings
Avg Response Time (ms): $( $PingResults | Measure-Object -Property ResponseTime -Average | Select-Object -ExpandProperty Average )
`n
"@                
            }
            else {
                # Add the ping failure information to the Note
                $Note += @"
Ping Results:
-----------------------------------------------------
Source Address:         $( $env:COMPUTERNAME )
Remote Address:         $IPAddress
Number of Pings:        $NumPings
Avg Response Time (ms): N/A
***** PING FAILED *****
`n
"@
            }

            if ( $TraceRtResults ) {
                # Add the tracert success information to the Note
                $Note += @"
Trace Route Results:
-----------------------------------------------------
Source Address:       $( $env:COMPUTERNAME )
Remote Address:       $IPAddress
Round Trip Time (ms): $( $TraceRtResults.RTT )
Hops:
$( $TraceRtResults.TraceRoute | ForEach-Object { "`t$( $_ )`n" } )
`n
"@
            }
            else {
                # Add the tracert success information to the Note
                $Note += @"
Trace Route Results:
-----------------------------------------------------
Source Address:       $( $env:COMPUTERNAME )
Remote Address:       $IPAddress
Round Trip Time (ms): N/A
Hops:
    N/A
***** TRACE FAILED *****
`n
"@

            }
            
            # We've finished building the note, so let's send it back outside the function
            $Note

        }
    }

    End {
        # Nothing to do here
    }
}