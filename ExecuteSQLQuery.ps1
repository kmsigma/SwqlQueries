# The below is a SQL query, not a SWQL query
# The default SolarWinds Platform user must have sufficient rights to read the database

# The return formatting assumes:
# * This is a SELECT query
# * it only returns on dataset
$SqlQuery = @"
SELECT [ID]
     , [Guid]
     , [Name]
     , [Version]
     , [DisplayName]
     , [Description]
     , [Created]
     , [Updated]
     , [TemplateData]
     , [RequestsCount]
     , [MetricsCount]
FROM [APIPoller_Templates]
"@

# Exclude Unecessary XML details
$PropertiesToExclude = @(
   'Attributes',
   'BaseURI',
   'ChildNodes',
   'FirstChild',
   'HasAttributes',
   'HasChildNodes', 
   'id', 
   'InnerText', 
   'InnerXml', 
   'IsEmpty', 
   'IsReadOnly', 
   'LastChild', 
   'LocalName', 
   'Name', 
   'NamespaceURI', 
   'NextSibling', 
   'NodeType', 
   'ObjectId', 
   'OuterXml', 
   'OwnerDocument', 
   'ParentNode', 
   'Prefix', 
   'PreviousSibling', 
   'PreviousText', 
   'rowOrder', 
   'SchemaInfo', 
   'Value'
)

# Assume that we already have the Swis Connection information stored
$ExecuteResponse = Invoke-SwisVerb -SwisConnection $SwisConnection -Entity 'Orion.Reporting' -Verb 'ExecuteSQL' -Arguments ( $SqlQuery, $null, $null, $false )


$DataSet = $ExecuteResponse.diffgram.DocumentElement.ExecuteSQLResults | Sort-Object -Property rowOrder | Select-Object -ExcludeProperty $PropertiesToExclude

$DataSet | Format-Table