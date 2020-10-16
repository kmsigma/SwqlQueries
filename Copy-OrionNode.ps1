# Original Script Source: https://thwack.solarwinds.com/t5/Product-Blog/How-to-automate-the-creation-of-Orion-Platform-aka-Core-nodes/ba-p/447958

# All that I've done thusfar is clean up some of the calls and formatting from
# the above post's attachment.  Overall, it's very good, but hasn't been touched
# in forever.  It could use some love and I'll work on it when I can spare time.

$ErrorActionPreference = 'SilentlyContinue'

# Set up the hostname, username, and password for the source system
if ( -not ( $SourceSwisConnection ) )
{
    $SourceOrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the source Orion Server"
    $SourceSwisCredentials = Get-Credential -Message "Enter your Orion credentials for $SourceOrionServer"
    $SourceSwisConnection  = Connect-Swis -Credential $SourceSwisCredentials -Hostname $SourceOrionServer
}

# Set up the hostname, username, and password for the target system
if ( -not ( $TargetSwisConnection ) )
{
    $TargetOrionServer     = Read-Host -Prompt "Please enter the DNS name or IP Address for the target Orion Server"
    $TargetSwisCredentials = Get-Credential -Message "Enter your Orion credentials for $TargetOrionServer"
    $TargetSwisConnection  = Connect-Swis -Credential $TargetSwisCredentials -Hostname $TargetOrionServer
}

<# removed because this function serves no purpose with modern PowerShell
 # we can just check to see if the object exists.
 # if it does, then it's not IsEmpty
 # -----------------------------------
 # PS C:\> -not ''
 # True
 # PS C:\> -not $null
 # True
 # PS C:\> -not "thing"
 # False
function IsEmpty($str) {
    $str -eq $null -or $str -eq '' -or $str.GetType() -eq [DBNull]
}
#>

# Define which properties will be copied from the source to the target for Nodes, Interfaces, and Volumes
$NodePropsToCopy = @( "AgentPort", "Allow64BitCounters", "Caption", "ChildStatus", "CMTS", "Community", 
    "Contact", "DNS", "DynamicIP", "External", "GroupStatus", "IOSImage", 
    "IOSVersion", "IPAddress", "IPAddressGUID", "IPAddressType", "LastSystemUpTimePollUtc", 
    "Location", "MachineType", "NodeDescription", "ObjectSubType", "PollInterval", "RediscoveryInterval", 
    "RWCommunity", "Severity", "SNMPVersion", "StatCollection", "Status", "StatusDescription", 
    "StatusLED", "SysName", "SysObjectID", "TotalMemory", "UnManaged", "Vendor", "VendorIcon",
    "BufferNoMemThisHour", "BufferNoMemToday", "BufferSmMissThisHour", "BufferSmMissToday", "BufferMdMissThisHour",
    "BufferMdMissToday", "BufferBgMissThisHour", "BufferBgMissToday", "BufferLgMissThisHour",
    "BufferLgMissToday", "BufferHgMissThisHour", "BufferHgMissToday" )

$InterfacePropsToCopy = @( "AdminStatus", "AdminStatusLED", "Caption", "Counter64", "CustomBandwidth", "FullName", 
    "IfName", "InBandwidth", "Inbps", "InDiscardsThisHour", "InDiscardsToday", "InErrorsThisHour", "InErrorsToday", 
    "InMcastPps", "InPercentUtil", "InPktSize", "InPps", "InterfaceAlias", "InterfaceIcon", "InterfaceIndex", 
    "InterfaceMTU", "InterfaceName", "InterfaceSpeed", "InterfaceSubType", "InterfaceType", "InterfaceTypeDescription", 
    "InterfaceTypeName", "InUcastPps", "MaxInBpsToday", "MaxOutBpsToday", "ObjectSubType", "OperStatus", "OutBandwidth", 
    "Outbps", "OutDiscardsThisHour", "OutDiscardsToday", "OutErrorsThisHour", "OutErrorsToday", "OutMcastPps", 
    "OutPercentUtil", "OutPktSize", "OutPps", "OutUcastPps", "PhysicalAddress", "PollInterval", "RediscoveryInterval", 
    "Severity", "StatCollection", "Status", "StatusLED", "UnManaged", "UnPluggable" )

$VolumePropsToCopy = @( "Icon", "Index", "Caption", "StatusIcon", "Type", "Size", "Responding", "FullName", 
    "VolumePercentUsed", "VolumeAllocationFailuresThisHour", "VolumeDescription", "VolumeSpaceUsed", 
    "VolumeAllocationFailuresToday", "VolumeSpaceAvailable" )
    
# Create the property ImportedByAPI in the remote system
# I </3 that this is a text field.  Personally, I would have gone with a boolean (yes/no, true/false), but I'll live.
if ( -not ( Get-SwisData -SwisConnection $TargetSwisConnection -Query "SELECT Field FROM Orion.CustomProperty WHERE Table='Nodes' AND Field='ImportedByAPI'" ) )
{
    Invoke-SwisVerb -SwisConnection $TargetSwisConnection -EntityName "Orion.NodesCustomProperties" -Verb "CreateCustomProperty" -Arguments @( "ImportedByAPI", "created from PowerShell", "System.String", 100, "", "", "", "", "", "" )
}

#region List of the Queries we'll be using
# I almost always do my queries in a multi-line (here-string) format because it's easier for me to read
$SwqlEngines = @"
SELECT EngineID
     , ServerName
     , IP
     , ServerType
FROM Orion.Engines
ORDER BY EngineID
"@
$SwqlHasNpm = @"
SELECT Name
FROM Orion.InstalledModule
WHERE Name = 'NPM'
  AND IsExpired = 'False'
"@
$SwqlHasNcm = @"
SELECT Name
FROM Orion.InstalledModule
WHERE Name = 'NCM'
  AND IsExpired = 'False'
"@
$SwqlNodeUriByIp = @"
SELECT Uri
FROM Orion.Nodes
WHERE IPAddress = @IP
"@

$SwqlNodes = @"
SELECT Uri
     , IPAddress
     , Caption
     , NodeID
FROM Orion.Nodes
WHERE ObjectSubType = 'SNMP'
ORDER BY Caption
"@
$SwqlPollers = @"
SELECT PollerType
FROM Orion.Pollers
WHERE NetObject = @NetObject
"@

$SwqlInterfaceUrisByNode = @"
SELECT Nodes.Interfaces.Uri
FROM Orion.Nodes
WHERE NodeID = @NodeID
"@

$SwqlVolumeUrisByNodeID = @"
SELECT Nodes.Volumes.Uri
FROM Orion.Nodes
WHERE NodeID = @NodeID
"@
#endregion List of the Queries we'll be using

# Check whether both the source and target have NPM installed
# If the system supports interfaces, then we can safely assume that NPM is installed
$SourceHasNpm = ( -not ( Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlHasNpm ) )
$TargetHasNpm = ( -not ( Get-SwisData -SwisConnection $TargetSwisConnection -Query $SwqlHasNpm ) )

# Check whether the target has NCM installed
# if the query returns anything, then NCM is installed
$TargetHasNCM = ( -not ( Get-SwisData -SwisConnection $TargetSwisConnection -Query $SwqlHasNcm ) )

# Get the complete list of Nodes from the source system
# You can add a WHERE clause to this query if you only want to copy certain nodes
$SourceNodes = Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlNodes

$TargetEngines = Get-SwisData -SwisConnection $TargetSwisConnection -Query $SwqlEngines
# check to see if we're dealing with multiple polling engines
if ( $TargetEngines.Count -gt 1 )
{
    # Take the cheater way out at the moment and select the first engine
    $TargetEngineID = $TargetEngines[0].EngineID
    Write-Host "We are going load the nodes on $( $TargetEngines[0].ServerName ) ($( $TargetEngines[0].IP )).  If you want to move them, you can do this in Node Management" -ForegroundColor Yellow
}

ForEach ( $SourceNode in $SourceNodes )
{

    # See if there is aleady a node on the target with the same IP address
    $TargetNodeUri = Get-SwisData -SwisConnection $TargetSwisConnection -Query $SwqlNodeUriByIp -Parameters @{ "IP" = $SourceNode.IPAddress }
    # Original script had "$target -eq $null", but "-eq $null" is redundant.  You can just check for existence using "-not"
    if ( $TargetNodeUri )
    {
        Write-Host "Skipping $( $SourceNode.Caption) ($( $SourceNode.IPAddress )) because it is already managed by $TargetOrionServer"
        continue
    }

    # Fetch all properties of the source node
    $SourceNodeProps = Get-SwisObject -SwisConnection $SourceSwisConnection  -Uri $SourceNode.Uri

    <# Removed this section because we are already checking for SNMP only in the $SwqlNodes query above
    # Skip WMI nodes - this script does not support copying Windows credentials
    if ( $SourceNodeProps.ObjectSubType -eq "WMI" ) {
        Write-Host "Skipping" $SourceNode.Caption "(" $SourceNode.IPAddress ") because it uses WMI."
        continue
    }
    #>

    # Make an in-memory copy of the node
    Write-Host "Copying" $SourceNode.Caption "(" $SourceNode.IPAddress ")"
    $TargetNodeProps = @{}
    $nodePropsToCopy | ForEach-Object {
        if ( $SourceNodeProps[$_] )
        {
            $TargetNodeProps[$_] = $SourceNodeProps[$_]
        }
    }
    $TargetNodeProps["EngineID"] = $TargetEngineID 

    # Create the node on the target system
    $NewUri = New-SwisObject -SwisConnection $TargetSwisConnection -EntityType "Orion.Nodes" -Properties $TargetNodeProps
    $NewNode = Get-SwisObject -SwisConnection $TargetSwisConnection -Uri $NewUri


    # Associate the custom property "ImportedByAPI" with this node and set its value to "true"
    Set-SwisObject -SwisConnection $TargetSwisConnection -Uri ( "$( $NewUri )/CustomProperties" ) -Properties @{ "ImportedByAPI" = "true" }

    # SNMPv3 credentials are in a sub-object and must be copied separately
    if ( $SourceNodeProps.SNMPVersion -eq 3)
    {
        Write-Host "`tCopying SNMPv3 credentials"
        $v3creds = Get-SwisObject -SwisConnection $SourceSwisConnection -Uri ("$( $SourceNode.Uri )/SNMPv3Credentials")
        @( "NodeID", "Uri", "InstanceType", "DisplayName", "Description" ) | ForEach-Object {
            $v3creds.Remove($_) | Out-Null
        }
        Set-SwisObject -SwisConnection $Target -Uri ( "$( $newUri )/SNMPv3Credentials") -Properties $v3creds
    }
    
    # Copy the pollers for the new node
    $PollerTypes = Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlPollers -Parameters @{ "NetObject" = "N:$( $SourceNodeProps.NodeID )" }
    
    ForEach ($PollerType in $PollerTypes)
    {
        # Create a new hashtable with the property details
        $Poller = @{
           PollerType = $PollerType
           NetObject = "N:$( $NewNode.NodeID )"
           NetObjectType = "N"
           NetObjectID = $NewNode.NodeID
        }
        Write-Host "`tAdding poller $PollerType"
        New-SwisObject -SwisConnection $TargetSwisConnection -EntityType "Orion.Pollers" -Properties $Poller | Out-Null
    }

    # Copy interface and volume informaiton from one system to another
    # If NPM is installed on both the source and target systems...
    if ( $SourceHasNpm -and $TargetHasNpm ) {
        # Get the interfaces on the source node
        $SourceInterfaces = Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlInterfaceUrisByNode -Parameters @{ "NodeID" = $SourceNode.NodeID }
        ForEach ( $SourceInterface in $SourceInterfaces )
        {
            $SourceIfProps = Get-SwisObject -SwisConnection $SourceSwisConnection -Uri $SourceInterface
            Write-Host "`tCopying $( $SourceNode.Caption ) / $( $SourceIfProps.Caption )"
            # Build an empty hashtable for the target interface properties
            $TargetIfProps = @{}
            $InterfacePropsToCopy | ForEach-Object {
                # Fill it in from the Source
                $TargetIfProps[$_] = $SourceIfProps[$_]
            }
            $TargetIfProps["NodeID"] = $NewNode.NodeID
            
            # Create the copy
            $NewIfUri = New-SwisObject -SwisConnection $TargetSwisConnection -EntityType "Orion.NPM.Interfaces" -Properties $TargetIfProps
            $NewIf = Get-SwisObject -SwisConnection $TargetSwisConnection -Uri $newIfUri
            
            # Copy the pollers for the new interface
            $IfPollerTypes = Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlPollers @{ "NetObject" = "I: $( $SourceIfProps.InterfaceID )" }
    
            ForEach ($ifPollerType in $ifPollerTypes)
            {
                $IfPoller = @{
                    PollerType = $IfPollerType
                    NetObject = "I:$( $NewIf.InterfaceID )"
                    NetObjectType = "I"
                    NetObjectID = $NewIf.InterfaceID
                }
                Write-Host "      Adding poller $ifPollerType"
                New-SwisObject -SwisConnection $TargetSwisConnection -EntityType "Orion.Pollers" -Properties $IfPoller | Out-Null
            }
        }
    }

    # Get the volumes on the source node
    $SourceVolumes = Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlVolumeUrisByNodeID -Paremeters @{ "NodeID" = $SourceNode.NodeID }
    ForEach ( $SourceVolume in $SourceVolumes ) {
        $SourceVolProps = Get-SwisObject -SwisConnection $SourceSwisConnection -Uri $SourceVolume
        Write-Host "`tCopying $( $SourceNode.Caption ) / $( $SourceVolProps.Caption )"
        $TargetVolProps = @{}
        $VolumePropsToCopy | ForEach-Object {
            $TargetVolProps[$_] = $SourceVolProps[$_]
        }
        $TargetVolProps["NodeID"] = $NewNode.NodeID

        # Create the copy
        $NewVolUri = New-SwisObject -SwisConnection $TargetSwisConnection -EntityType "Orion.Volumes" -Properties $TargetVolProps
        $NewVol = Get-SwisObject -SwisConnection $TargetSwisConnection -Uri $NewVolUri

        # Copy the pollers for the new Volume
        $VolPollerTypes = Get-SwisData -SwisConnection $SourceSwisConnection -Query $SwqlPollers -Parameters @{ "NetObject" = "V:$( $SourceVolProps.VolumeID )" }
    
        ForEach ($VolPollerType in $VolPollerTypes) {
            $VolPoller = @{
                PollerType = $VolPollerType
                NetObject = "V:$( $NewVol.VolumeID )"
                NetObjectType = "V"
                NetObjectID = $NewVol.VolumeID
            }
            Write-Host "`tAdding poller $VolPollerType"
            New-SwisObject -SwisConnection $TargetSwisConnection -EntityType "Orion.Pollers" -Properties $VolPoller | Out-Null
        }
    }

    # If the target has NCM installed, add the new node to NCM
    if ( $TargetHasNCM)
    {
        Invoke-SwisVerb -SwisConnection $TargetSwisConnection -EntityName "Cirrus.Nodes" -Verb "AddNodeToNCM" -Arguments $NewNode.NodeID
    }
}
