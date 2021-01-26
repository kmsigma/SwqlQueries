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

SELECT [Hostname],
	[ServerType],
	CASE 
		WHEN (
				EXISTS (
					SELECT *
					FROM Licensing_LicenseAssignments
					WHERE [ProductName] = 'VM'
					)
				AND ([Acronym] = 'VMAN')
				)
			THEN 'Virtualization Manager'
		WHEN (
				NOT EXISTS (
					SELECT *
					FROM Licensing_LicenseAssignments
					WHERE [ProductName] = 'VM'
					)
				AND ([Acronym] = 'VMAN')
				)
			THEN 'Virtual Infrastructure Monitor'
		ELSE [Product]
		END AS [Product],
	[Acronym],
	CASE 
		WHEN HotFix IS NULL
			THEN [ReleaseVersion]
		ELSE [ReleaseVersion] + ' HF' + [HotFix]
		END AS [Version]
FROM [OrionServers]
CROSS APPLY OPENJSON([Details]) WITH (
		[Product] VARCHAR(50) '$.Name',
		[Acronym] VARCHAR(5) '$.ShortName',
		[ReleaseVersion] VARCHAR(25) '$.Version',
		[Hotfix] VARCHAR(5) '$.HotfixVersionNumber'
		) AS VersionInfo
-- Remove 'features' that are erroneously listed as a 'product'
WHERE [Product] NOT IN ('Cloud Monitoring', 'Quality of Experience', 'NetPath', 'Virtual Infrastructure Monitor')
ORDER BY Hostname
