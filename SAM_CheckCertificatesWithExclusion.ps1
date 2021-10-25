#region Define Exit Codes
$ExitCode = @{ "Up" = 0;
    "Down"          = 1;
    "Warning"       = 2;
    "Critical"      = 3;
    "Unknown"       = 4 
}
#endregion Define Exit Codes

# Getting the Parameters from the passed arguments
# Expected Parameters:
#   first is an integer representing the number of days before execution
#   second through the end is a list of subjects to exclude
if ( $args ) {
    $VerbosePreference = "SilentlyContinue"
    $intThreshold = $args[0]
    $excludeSubjects = @()
    For ( $i = 1; $i -lt $args.Count; $i++ ) {
        $excludeSubjects += $args[$i]
    }
} else {
    $VerbosePreference = "Continue"
    Write-Verbose -Message "Executing in 'Test' Mode with static options"
    $intThreshold = 60 # days
    $excludeSubjects = "Verisign", "Microsoft"
    $testMode = $true
}



Write-Verbose -Message "Setting Deadline date to: $( ( Get-Date ).AddDays($intThreshold ) )"
$dateDeadline = ( Get-Date ).AddDays($intThreshold)

# Lookup the target server name from DNS
$HostNames = [System.Net.Dns]::GetHostByAddress("192.168.21.65")
if ( $HostNames ) {
    # Use the first entry from hostnames, and use only the computername (strip off everything after the first .)
    $TargetServer = $HostNames[0].HostName.Split(".")[0].ToUpper()
}

$objStore = Invoke-Command -ComputerName $TargetServer -Credential $LocalCreds -ScriptBlock { Get-ChildItem -Path 'Cert:\LocalMachine\Root' }
# Add a member that'll present the name in an easier way
$objStore | Add-Member -MemberType ScriptProperty -Name "Name" -Value { ( $this.Subject.Split(",") | ForEach-Object { $_.Trim().Split("=")[1] } ) -join ", " } -Force
# add a member so I can filter for those already expired
$objStore | Add-Member -MemberType ScriptProperty -Name "IsExpired" -Value { $this.NotAfter -lt ( Get-Date ) } -Force
# add a member so I can filter for those with upcoming expiration
$objStore | Add-Member -MemberType ScriptProperty -Name "IsUpcomingExpiration" -Value { $this.NotAfter -lt $dateDeadline } -Force

Write-Verbose -Message "Original Store has: $( $objStore.Count ) entrie(s)"
$cleanStore = $objStore
ForEach ( $excludeSubject in $excludeSubjects) {
    Write-Verbose -Message "Filtering off '$excludeSubject' from Certificate List"
    $cleanStore = $cleanStore | Where-Object { $_.Subject -notlike "*$excludeSubject*" }
}
Write-Verbose -Message "Filtered Store has: $( $cleanStore.Count ) entrie(s)"

# Build objects to make creating the output easier
$expiredCertificates            = $cleanStore | Where-Object { $_.IsExpired }
$upcomingExpirationCertificates = $cleanStore | Where-Object { ( -not ( $_.IsExpired ) ) -and ( $_.IsUpcomingExpiration ) }
$validCertificates              = $cleanStore | Where-Object { ( -not ( $_.IsExpired ) ) -and ( -not ( $_.IsUpcomingExpiration ) ) }

# Do you want to include the certificate names?  This can make the messages VERY long
$IncludeCertNames = $false
if ( $IncludeCertNames ) {
    $expiredList  = " [Certificate List: $( $expiredCertificates.Name -join "; " )]"
    $upcomingList = " [Certificate List: $( $upcomingExpirationCertificates.Name -join "; " )]"
    $excludeList  = " [Ignored Subjects: $( $excludeSubjects -join "; " )]"
} else {
    $expiredList  = ""
    $upcomingList = ""
    $excludeList  = ""
}
Write-Host "Message.Upcoming: $( $upcomingExpirationCertificates.Count ) certificate(s) on '$TargetServer' are expiring in the next $intThreshold days.$upcomingList"
Write-Host "Statistic.Upcoming: $( $upcomingExpirationCertificates.Count )"
Write-Host "Message.Expired: $( $expiredCertificates.Count ) certificate(s) on '$TargetServer' are already expired.$expiredList"
Write-Host "Statistic.Expired: $( $expiredCertificates.Count )"
Write-Host "Message.Valid: $( $validCertificates.Count ) certificate(s) on '$TargetServer' are valid."
Write-Host "Statistic.Valid: $( $validCertificates.Count )"
Write-Host "Message.Ignored: Ignoring $( $objStore.Count - $cleanStore.Count ) certificate(s) on '$TargetServer'$excludeList"
Write-Host "Statistic.Ignored: $( $objStore.Count - $cleanStore.Count )"

if ( -not $testMode ) {
    exit $ExitCode['Up']
}
