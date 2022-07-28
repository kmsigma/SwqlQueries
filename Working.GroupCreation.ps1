#Creating a table with sites creation needed: 
$GroupsToCreate = $allnbsites | Where-Object { $_.name -in $MissingGroups.DefinedEng } | Select-Object url, name, status, region, facility, physical_address, latitude, longitude

$GroupsToCreate = Import-Csv -Path .\GroupsToCreate.csv

ForEach ($gtc in $groupsToCreate) {
    $BMR_Eng_Number = $gtc.Name
    $groupName = $gtc.facility
    $longitude = $gtc.Longitude
    $latitude = $gtc.Latitude

    #creating the group:
    Invoke-SwisVerb -SwisConnection $SwisConnection -EntityName "Orion.Container" -Verb "CreateContainer" -Arguments @(
        # group name
        $groupname, 
        # owner, must be 'Core'
        "Core",
        # refresh frequency
        60,
        # Status rollup mode: 0 = Mixed status shows warning, 1 = Show worst status, 2 = Show best status
        0,
        # group description
        "Created by Provisioning Script (PL) v1.0",
        # polling enabled/disabled = true/false (in lowercase)
        $true, 
        ( [xml]"<ArrayOfMemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion' />" ).DocumentElement
    )

    $NewGroupQuery = @"
SELECT [gcp].ContainerID
     , [g].Name
     , [g].LastChanged
     , [gcp].BMR_Eng_Number
     , [gcp].c
     , [gcp].Longitude
     , [gcp].Latitude
     , [gcp].LMRN_Description
     , [gcp].LMRN_Zone
     , [g].URI
     , CASE
         WHEN [g].URI IS NOT NULL THEN CONCAT([g].URI,'/CustomProperties')
         ELSE NULL
       END AS CP_URI 
FROM Orion.GroupCustomProperties AS [gcp]
LEFT JOIN Orion.Groups AS [g]
  ON [gcp].ContainerID = [g].ContainerID
WHERE [g].Name = '$groupname'
"@
    #Getting newly group information: 
    $groupData = Get-SwisData $SwisConnection -Query $NewGroupQuery

    #Populating custom properties of the new group:
    $CP = @{
        "BMR_Eng_Number" = $BMR_Eng_Number
        "Longitude"      = $longitude
        "Latitude"       = $latitude
    }
    Set-SwisObject -SwisConnection $SwisConnection -Uri $groupData.CP_URI -Properties $CP

    # Creating dynamic to populate group:
    $members = @(
        @{ Name = "BMR_Eng_Number is $BMR_Eng_Number"; Definition = "filter:/Orion.Nodes[CustomProperties.BMR_Eng_Number=$BMR_Eng_Number]" }
    )
    Invoke-SwisVerb $SwisConnection -EntityName "Orion.Container" -Verb "AddDefinitions" -Arguments @(
        # group ID
        $groupData.ContainerID,
        # group member to add
        ([xml]@(
            "<ArrayOfMemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion'>",
            [string]( $members | ForEach-Object {
                    "<MemberDefinitionInfo><Name>$( $_.Name )</Name><Definition>$( $_.Definition )</Definition></MemberDefinitionInfo>"
                }
            ),
            "</ArrayOfMemberDefinitionInfo>"
        )).DocumentElement
    ) | Out-Null
}