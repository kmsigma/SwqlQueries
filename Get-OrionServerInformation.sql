/* 
Script: Get-OrionServerDetails.sql
Purpose: Retrieve versions from the SolarWinds Orion Database

Scripts are not supported under any SolarWinds support program or service.
Scripts are provided AS IS without warranty of any kind. SolarWinds further 
disclaims all warranties including, without limitation, any implied warranties 
of merchantability or of fitness for a particular purpose. The risk arising 
out of the use or performance of the scripts and documentation stays with you. 
In no event shall SolarWinds or anyone else involved in the creation, 
production, or delivery of the scripts be liable for any damages whatsoever
(including, without limitation, damages for loss of business profits, business
interruption, loss of business information, or other pecuniary loss) arising
out of the use of or inability to use the scripts or documentation. 
*/

-- 'SolarWindsOrion' is the default name of the Orion database.
-- If you used a different name, replace it below
USE SolarWindsOrion;

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
-- Ignore 'products' that are actually just 'features'
WHERE [Product] in ( 'Database Performance Analyzer Integration Module'
                   , 'IP Address Manager'
                   , 'Log Analyzer'
                   , 'NetFlow Traffic Analyzer'
                   , 'Network Configuration Manager'
                   , 'Network Performance Monitor'
                   , 'Orion Platform'
                   , 'Server & Application Monitor'
                   , 'Server Configuration Monitor'
                   , 'Storage Resource Monitor'
                   , 'Toolset'
                   , 'User Device Tracker'
                   , 'VoIP and Network Quality Manager'
                   , 'Web Performance Monitor' )
ORDER BY Hostname
