<##################################################
Update-OrionServerNodeIds.ps1

This script will update the Orion.OrionServers elements with the matching NodeIDs

It prompts for confirmation on each update since there's a chance there will be a mismatch.
---Tested with Core 2020.2.6 HF2---
##################################################>

if ( -not ( $SwisConnection ) ) {
    $SwisHost = Read-Host -Prompt "Provide the IP or FQDN of your Orion server"

    if ( -not ( $SwisCreds ) ) {
        $SwisCreds = Get-Credential -Message "Enter your Orion credentials for $SwisHost"
    }

    if ( $SwisHost -and $SwisCreds ) {
        $SwisConnection = Connect-Swis -Hostname $SwisHost -Credential $SwisCreds
    }
}

$MissingNodeIds = Get-SwisData -SwisConnection $SwisConnection -Query "SELECT Uri, HostName FROM Orion.OrionServers WHERE IsNull(NodeID, 0) = 0"
if ( $MissingNodeIds ) {
    ForEach ( $MissingNodeId in $MissingNodeIds ) {
        Write-Host "Checking matches for '$( $MissingNodeId.HostName )'"
        $PossibleMatches = Get-SwisData -SwisConnection $SwisConnection -Query "SELECT NodeID, Caption, DNS, SysName, IPAddress FROM Orion.Nodes WHERE Caption LIKE '%$( $MissingNodeId.HostName )%' OR DNS LIKE '%$( $MissingNodeId.HostName )%' OR SysName LIKE '%$( $MissingNodeId.HostName )%'"

        if ( $PossibleMatches.Count -eq 1 ) {
            # Single match
            Write-Host "`tFound a potential match:"
            $PossibleMatches | Format-Table

            # Build menu for choice
            $Yes = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList ( '&Yes', "Set NodeID for $( $MissingNodeId.HostName ) to $( $PossibleMatches.NodeID )" )
            $No = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList ( '&No', "Make no changes")

            $Choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)
            $Title = "Update Orion.Servers Entry"
            $Message = "Do you want to update entry for '$( $MissingNodeId.HostName )' in Orion.OrionServers with NodeID: $( $PossibleMatches.NodeID )?"
            $Response = $Host.Ui.PromptForChoice($Title, $Message, $Choices, 1)
            if ( $Response -eq "Y" ) {
                Write-Host "We'd run the update now" -ForegroundColor Green
            }
            else {
                Write-Host "I guess not." -ForegroundColor Red
            }
        }
        elseif ( $PossibleMatches.Count -gt 1 ) {
            # Multiple matches
            Write-Host "`tFound multiple potential matches:"
            $PossibleMatches | Format-Table
            $Response = $null
            do {
                if ( -not $ResponseOk ) {
                    if ( $Response ) {
                        Write-Error -Message "'$Response' is an invalid NodeID.  Please enter a Node ID from the below table."
                    }
                    $PossibleMatches | Format-Table -AutoSize
                }
                Write-Host "Enter the NodeID you'd like to assign to '$( $MissingNodeID.HostName )' in Orion.OrionServers " -NoNewLine
                $Response = Read-Host -Prompt "or enter 'S' to skip"
                $ResponseOk = $Response -in ( $PossibleMatches.NodeID ) -or $Response -eq 's'
            } until ( $ResponseOk )
            if ( $Response -ne 's' ) {
                Write-Host "We'd run the update now" -ForegroundColor Green
            }
            else {
                Write-Host "I guess not." -ForegroundColor Red
            }
        }
        else {
            # No matches
            Write-Error -Message "Found no appropriate matches.  Are you monitoring your Orion servers?"
        }



    }
}
else {
    Write-Warning -Message "All Orion Server objects have a matching NodeID"
}