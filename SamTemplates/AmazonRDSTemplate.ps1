#region Define Exit Codes
$ExitCode = @{ "Up" = 0;
               "Down" = 1;
               "Warning" = 2;
               "Critical" = 3;
               "Unknown" = 4 }
#endregion Define Exit Codes

#region Build Metric List (not all are used for each script monitor
$MetricNames = @"
DisplayName,Name,Statistics,Unit,DisplayUnit,Type,Ranking
CPU Utilization,CPUUtilization,Average,Percent,%,Compute,1
Database Connections,DatabaseConnections,Sum,Count,,Database,2
Disk Queue Depth,DiskQueueDepth,Sum,Count,,Storage,4
Freeable Memory,FreeableMemory,Average,Bytes,bytes,Compute,1
Free Storage Space,FreeStorageSpace,Average,Bytes,bytes,Storage,4
Network Receive Throughput,NetworkReceiveThroughput,Average,Bytes/Second,bytes/second,Network,3
Network Transmit Throughput,NetworkTransmitThroughput,Average,Bytes/Second,bytes/second,Network,3
Read IOPS,ReadIOPS,Average,Count/Second,operations/second,Storage,4
Write IOPS,WriteIOPS,Average,Count/Second,operations/second,Storage,4
Read Letency,ReadLatency,Average,Seconds,seconds,Storage,4
Write Latency,WriteLatency,Average,Seconds,seconds,Storage,4
Read Throughput,ReadThroughput,Average,Bytes/Second,bytes/second,Storage,4
Write Throughput,WriteThroughput,Average,Bytes/Second,bytes/second,Storage,4
Swap Usage,SwapUsage,Average,Bytes,bytes,Compute,1
"@

# Convert to objects based on the above raw data
$Metrics = $MetricNames | ConvertFrom-Csv

# Sort them
$Metrics = $Metrics | Sort-Object -Property Given | Sort-Object -Property Ranking
#endregion Build Metric List (not all are used for each script monitor


#region Retrieve and store passed arguments
# Get script argument EX: <accessKey>, <secretKey>, <Region>, <DatabaseName>, [TimeRange], [Period], [Retries], [WaitTime]
$Type          = $args[0]     # Parameter 1: Metric Type: Compute, Database, Network, Storage
$AccessKey     = $args[1]     # Parameter 2: Access Key
$SecretKey     = $args[2]     # Parameter 3: Secret Key
$Region        = $args[3]     # Parameter 4: AWS Region
$Database      = $args[4]     # Parameter 5: Database Name
# Optional parameters
$TimeRange     = $args[5]     # Parameter 6: Time Range (in minutes) [to be converted to seconds later]
$Period        = $args[6]     # Parameter 7: Period in Time Range
$GlobalRetries = $args[7]     # Parameter 8: Number of Retries
$WaitTime      = $args[8]     # Parameter 9: Wait Time between retries (in minutes)
#endregion Retrieve and store passed arguments

#region Generate Profile Name
$UniqueProfileId = Get-Random -Minimum 10000 -Maximum 99999

$ProfileName = "AWSRDS_SAM_$( $UniqueProfileId )" # Arbitrary file name to save the connection information
#endregion Generate Profile Name


#region check for valid values and revert to default if not acceptable
if ( -not $TimeRange ) {
   $TimeRange = 10
}

if ( -not $Period ) {
   $Period = 2
}

if ( -not $GlobalRetries) {
   $GlobalRetries = 3
}

if ( -not $WaitTime) {
   $WaitTime = 0.5
}
#endregion check for valid values and revert to default if not acceptable

#region Check for AWSPowerShell Module
if ( -not ( Get-Module -ListAvailable -Name AWSPowerShell -ErrorAction SilentlyContinue ) ) {
    write-host ("Importing AWS Module.....")
    try {
        Import-Module AWSPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
    }
    catch {
        Write-Host "[ERROR] $( $_.Exception.Message )"
        exit $ExitCode["Down"]
    }
}
#region Check for AWSPowerShell Module

#region Connect to AWS
$ConnectionRetries = $GlobalRetries
while ( $ConnectionRetries )
{  
    try {
        Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs $ProfileName -ErrorAction Stop -WarningAction SilentlyContinue
        Initialize-AWSDefaults -ProfileName $ProfileName -Region $Region -ErrorAction Stop -WarningAction SilentlyContinue
        Set-AWSCredentials -ProfileName $ProfileName -ErrorAction Stop -WarningAction SilentlyContinue
    }
    catch{
        Write-Host "[ERROR] $($_.Exception.Message)"
        $ConnectionRetries -= $GlobalRetries
        if ( $ConnectionRetries -le 0 ) {
            write-host ("Error while connecting")
            exit $ExitCode["Down"]
        }
    }
    Start-Sleep -Seconds $WaitTime
    Write-Warning -Message "Trying to reconnect to AWS"
}
#endregion Connect to AWS

#region Get the metrics
# Define the time range
# End Time is "right now"
$EndTime = ( Get-Date ).ToUniversalTime()
# Start Time is X minutes ago as defined by the argument passed to the $Time variable
$StartTime = $EndTime.AddMinutes(-$TimeRange)

# The AWS function wants the period in seconds, so we'll convert that
$PeriodInSeconds = $Period * 60

$SamOutput = @()
ForEach ( $Metric in $Metrics | Where-Object { $_.Type -eq $Type } )
{
    $DataRetries = $GlobalRetries
    while ( $DataRetries ) {
        try {
            $Data = Get-CWMetricStatistic -Namespace 'AWS/RDS' -Dimension @{ Name = ”DBInstanceIdentifier”; Value = $Database } -MetricName $Metric.Name -UtcStartTime $StartTime -UtcEndTime $EndTime -Period $PeriodInSeconds -Statistics $Metric.Statistics -Unit $Metric.Unit -ErrorAction Stop -WarningAction SilentlyContinue
            $DataPoint = $Data.DataPoints | Sort-Object -Property Timestamp -Descending | Select-Object -First 1 | Select-Object -ExpandProperty $Metric.Statistics
            $DataPoint = [math]::Round($DataPoint, 2) 
            $SamOutput += [PSObject]@{ Identifier = $Metric.Name; Statistic = $DataPoint; Message = "$( $Metric.DisplayName ) for '$Database' is $DataPoint $( $Metric.DisplayUnit )" }
        }
        catch {
            Write-Host "[ERROR] $( $_.Exception.Message )"
            $DataRetries--
            if ( $DataRetries -le 0 ) {   
                write-host ("Error while fetching the metric")
                exit $ExitCode["Down"]
            }
            Start-Sleep -Seconds $waitTime
            write-host ("Retrying to fetch the data")
        }
        finally {
            ForEach ( $Output in $SamOutput ) {
                Write-Host "Message.$( $Output.Identifier ): $( $Output.Message )"
                Write-Host "Statistic.$( $Output.Identifier ): $( $Output.Statistic )"
            }
            #Cleanup profile information
            Get-AwsCredential -ProfileName $ProfileName | Remove-AWSCredentialProfile -ErrorAction SilentlyContinue

            exit $ExitCode["Up"]
        }
    }
}
#endregion Get the metrics


