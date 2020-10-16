<#
File: Update-Captions.ps1
Purpose: The is a quick script that I wrote to update Node Captions within Orion.  It currently is set to remove any domain names (keeping only the hostname)
         and capitalize those captions.

Version History: 1.0 - first upload

GENERAL DISCLAIMER:
I write all of my scripts using frequent comments and I attempt to use full parameterization for all function calls for easier readability for new users.
#>

# Filter and rename tasks
$HostNameOnly = $true
$Capitalize   = $true

if ( -not ( $SwisConnection ) )
{
    $OrionServer = Read-Host -Prompt "Please enter the DNS name or IP Address for your Orion Server"
    $SwisCredentials = Get-Credential -Message "Enter your Orion credentials for $OrionServer"
    $SwisConnection = Connect-Swis -Credential $SwisCredentials -Hostname $OrionServer
}

# Base Query for Nodes
# We really only need the Caption and the Uri, but I prefer to have a little extra.
$SwqlQuery = @"
SELECT [Nodes].NodeID
     , [Nodes].Uri
     , [Nodes].Caption
     , [Nodes].IPAddress
FROM Orion.Nodes AS [Nodes]
"@

#Build an empty collection for where clauses for the query
# These clauses will be put together with " OR " as the joiner, so include any "AND" statements within the logic
# For readability, I'm going to enclose any compound filters within parenthesis.
$WhereClauses = @()

if ( $HostNameOnly )
{
    # We need to filter for captions that match a domain name format: hostname.domain.local
    #   Fair warning - if you are using an IPv4 address as a caption, this will also match.
    #   We're trying to get around this by checking to see if the caption matches the IP, but no guarantees.
    
    $WhereClauses = "( [Nodes].Caption LIKE '%.%.%' AND [Nodes].Caption <> [Nodes].IPAddress )"
}

# If there are any where clauses, then let's put them together and add it to our base query
if ( $WhereClauses )
{
    # if there are clauses, then we need the "WHERE" keyword and a space for separation.
    # I'm choosing to put it on a separate line (`n) because I may want the $SwqlQuery more readable, but it doesn't matter for function
    $SwqlQuery += "`nWHERE "
    #             Join each of the WHERE clauses together with an " OR " (if we only have one, the -join does nothing)
    # Add it to the existing query string
    $SwqlQuery += $WhereClauses -join " OR "
}

$NodesToRename = Get-SwisData -SwisConnection $SwisConnection -Query $SwqlQuery
Write-Host "Found $( $NodesToRename.Count) node caption(s) to rename"

$NodesToRename | Add-Member -MemberType NoteProperty -Name NewCaption -Value "" -Force
# Copy Caption into NewCaption
ForEach ( $Node in $NodesToRename )
{
    $Node.NewCaption = $Node.Caption
}

if ( $Capitalize )
{
    ForEach ( $Node in $NodesToRename )
    {
        $Node.NewCaption = $Node.NewCaption.ToUpper()
    }
}

if ( $HostNameOnly )
{
    ForEach ( $Node in $NodesToRename )
    {
        $Node.NewCaption = $Node.NewCaption.Split(".")[0]
    }
}

# Remove any entries where Caption and NewCaption match (this shouldn't be necessary, but better safe)
# I'm using the "-cne" operator instead of the "-ne" because I want this case sensitive.
$NodesToRename = $NodesToRename | Where-Object { $_.Caption -cne $_.NewCaption }


# to actually do the rename
ForEach ( $Node in $NodesToRename )
{
    Write-Host "Updating caption on $( $Node.Caption ) to $( $Node.NewCaption )"
    # The parameter for -Properties is a hashtable of the field we want to update (Caption) and the value for it ($Node.NewCaption)
    Set-SwisObject -SwisConnection $SwisConnection -Uri $Node.Uri -Properties @{ Caption = $Node.NewCaption } -Verbose
}