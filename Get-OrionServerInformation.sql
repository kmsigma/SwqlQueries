/* Get a list of all of the Orion servers and the associated software on them */
SELECT [Hostname]
     , [ServerType]
	 , [Product]
	 , CASE
	      WHEN HotFix IS NULL THEN [ReleaseVersion]
		  ELSE [ReleaseVersion] + ' HF' + [HotFix]
	   END AS [Version]
FROM [OrionServers]
CROSS APPLY OPENJSON([Details])
   WITH (
      [Product]        varchar(50) '$.Name'
    , [ReleaseVersion] varchar(25) '$.Version'
	, [Hotfix]         varchar(5)  '$.HotfixVersionNumber'
   ) AS VersionInfo
-- Ignore 'products' that are actually just 'featues'
WHERE [Product] in ( 'IP Address Manager', 'Log Analyzer', 'NetFlow Traffic Analyzer', 'Network Configuration Manager', 'Network Performance Monitor', 'Orion Platform', 'Server & Application Monitor', 'Server Configuration Monitor', 'Storage Resource Monitor', 'User Device Tracker', 'VoIP and Network Quality Manager', 'Web Performance Monitor' )
ORDER BY OrionServerID

