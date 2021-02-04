<#

Simple script to convert all columns on views to have the same width

#>

$SwqlQuery = @"
SELECT ViewID
     , ViewKey
     , ViewTitle
     , ViewGroupName
     , ViewGroup
     , ViewType
     , ViewGroupPosition
     , ViewIcon
     , Columns
     , Column1Width
     , Column2Width
     , Column3Width
     , Column4Width
     , Column5Width
     , Column6Width
     , System
     , Customizable
     , LimitationID
     , NOCView
     , NOCViewRotationInterval
     , Uri
FROM Orion.Views
WHERE Columns <> 0

"@

if ( -not ( $SwisConnection ) ) {
    $OrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the Orion Server"
    $SwisCredentials = Get-Credential -Message "Enter your Orion credentials for $OrionServer"
    $SwisConnection  = Connect-Swis -Credential $SwisCredentials -Hostname $OrionServer
}

$DisplayWidth = 1750 # pixels wide

$Views = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery
ForEach ( $View in $Views ) {
    $EvenColumnWidth = [math]::Floor($DisplayWidth / $View.Columns)
    # Cycle through each column
    for ( $i = 1; $i -le 6; $i++ ) {
        $FieldName = "Column$( $i )Width"
        # check to see if a column is used
        if ( $i -le $View.Columns ) {
            # if yes, then set the width
            $View.$FieldName = $EvenColumnWidth
        } else {
            # if not, set it to NULL
            $View.$FieldName = $null
        }
    }
    $ViewProperties = @{
        Column1Width = $View.Column1Width
        Column2Width = $View.Column2Width
        Column3Width = $View.Column3Width
        Column4Width = $View.Column4Width
        Column5Width = $View.Column5Width
        Column6Width = $View.Column6Width
    }
    Write-Host "Updating the columns widths on $( $View.ViewTitle ) [$( $View.ViewID )] to $EvenColumnWidth px"
    Set-SwisObject -SwisConnection $SwisConnection -Uri $View.Uri -Properties $ViewProperties
}