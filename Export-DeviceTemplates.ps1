<######################################################################
Name:   Export-DeviceTemplates.ps1
Author: Kevin M. Sparenberg
-----------------------------------------------------------------------
Purpose: Export all non-default NCM Device Templates from Orion Server
 
Version History:
1.0 - 01AUG2017 - Initial Build
 
Notes:
Change the elements in the Declare Variables region to your own needs

If you want to export ALL templates, then remove the WHERE clause
in the SWQL Query.
######################################################################>
 
#region Declare Variables
# Export Path in Local File System
$ExportPath = ".\DeviceTemplateExports\"
 
# Test Export Path & Create folder if doesn't exist
if ( -not ( Test-Path -Path $ExportPath -ErrorAction SilentlyContinue ) ) {
    Write-Warning -Message "Creating Folder at $ExportPath"
    New-Item -Path $ExportPath -ItemType Directory | Out-Null
}
 
 
# Orion Username & Password & Host (Name or IP)
$SwisHost = "kmsorion01v.kmsigma.local"
 
# SWQL Query for Templates
# Only includes non-default (last line)
# To include all templates, remove the WHERE clause
$Swql = @"
SELECT TemplateName
     , SystemOID
     , TemplateXml
     , SystemDescriptionRegex
     , CASE AutoDetectType
        WHEN 0 THEN 'BySystemOid'
        WHEN 1 THEN 'BySystemDescription'
       END AS [AutoDetectType]
FROM Cli.DeviceTemplates
WHERE IsDefault <> 'True'
"@
#endregion Declare Variables
 
#region Connect to SWIS
if ( -not ( $SwisCred ) ) {
    $SwisCred = Get-Credential -Message "Enter your Orion Credentails for '$SwisHost'"
}

$SwisConnection = Connect-Swis -Hostname $SwisHost -Credential $SwisCred
#endregion Connect to SWIS

# Query for all "non-default" Templates
$DeviceTemplates = Get-SwisData -SwisConnection $SwisConnection -Query $Swql

# Add 'filename' member
$DeviceTemplates | Add-Member -MemberType ScriptProperty -Name "Filename" -Value { $this.TemplateName + '-' + $this.SystemOID + '.ConfigMgmt-Commands' }

#region Export Templates to File System
ForEach ( $DeviceTemplate in $DeviceTemplates ) {
    try {
        $TemplateBodyXML = [xml]( $DeviceTemplate.TemplateXml )
        $TemplateBodyXML.'Configuration-Management'.Device = $DeviceTemplate.TemplateName
        if ( -not ( $TemplateBodyXML.'Configuration-Management'.SystemOID ) ) {
            $TemplateBodyXML.'Configuration-Management'.SetAttribute("SystemOID",  $DeviceTemplate.SystemOID)
        }
        else {
            $TemplateBodyXML.'Configuration-Management'.SystemOID = $DeviceTemplate.SystemOID
        }
        if ( -not ( $TemplateBodyXML.'Configuration-Management'.SystemDescriptionRegex ) ) {
            $TemplateBodyXML.'Configuration-Management'.SetAttribute("SystemDescriptionRegex", $DeviceTemplate.SystemDescriptionRegex)
        }
        else {
            $TemplateBodyXML.'Configuration-Management'.SystemDescriptionRegex = $DeviceTemplate.SystemDescriptionRegex
        }
        $TemplateBodyXML.'Configuration-Management'.SetAttribute("AutoDetectType", $DeviceTemplate.AutoDetectType)
        $TemplateBodyXML.Save( ( Join-Path -Path $ExportPath -ChildPath $DeviceTemplate.FileName ) )
    }
    catch {
        Write-Error -Message "Ran into an error processing $( $DeviceTemplate.TemplateName )."
    }
}
#endregion Export Templates to File System