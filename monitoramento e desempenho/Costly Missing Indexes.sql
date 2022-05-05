SELECT
    TOP 10
    [Total Cost] = ROUND((avg_total_user_cost * avg_user_impact * (user_seeks + user_scans))/100,0) 
    ,avg_user_impact /*porcentagem media de melhoria por consulta*/
    ,(user_seeks + user_scans) query_count
    ,TableName = statement 
    ,[EqualityUsage] = equality_columns 
    ,[InequalityUsage] = inequality_columns 
    ,[Include Cloumns] = included_columns
FROM
    sys.dm_db_missing_index_groups g
    INNER JOIN sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle
    INNER JOIN sys.dm_db_missing_index_details d ON d.index_handle = g.index_handle
ORDER BY [Total Cost] DESC;




/***
 * indices mais usados
 * 
 */
SELECT TOP 1
	[Maintenance cost] = (user_updates + system_updates),
	[Retrieval usage] = (user_seeks + user_scans + user_lookups),
	DatabaseName = DB_NAME(),
	TableName = OBJECT_NAME(s.[object_id]),
	IndexName = i.name 
INTO 
	#TempMaintenanceCost
FROM 
	sys.dm_db_index_usage_stats s
	INNER JOIN sys.indexes i   ON s.[object_id] = i.[object_id]   AND s.index_id = i.index_id
WHERE 
	s.database_id = DB_ID()
	AND OBJECTPROPERTY(s.[object_id],'IsMsShipped') = 0
	AND (user_updates + system_updates) > 0
	-- Only report on active rows.
	AND s.[object_id] = -999
	-- Dummy value to get table structure.
;
-- Loop around all the databases on the server.
EXEC sp_MSForEachDB 'USE [?]; 
	-- Table already exists.
	INSERT INTO #TempMaintenanceCost 
	select * 
	from (
	SELECT TOP 30 
		[Maintenance cost] = (user_updates + system_updates) 
		,[Retrieval usage] = (user_seeks + user_scans + user_lookups) 
		,DatabaseName = DB_NAME() ,TableName = OBJECT_NAME(s.[object_id]) 
		,IndexName = i.name 
	FROM 
		sys.dm_db_index_usage_stats s 
		INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id 
	WHERE 
		s.database_id = DB_ID() 
		AND i.name IS NOT NULL 
		-- Ignore HEAP indexes.
		AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0 
		AND (user_updates + system_updates) > 0 
		-- Only report on active rows.
	ORDER BY [Maintenance cost] DESC 
	) k
	union 
	select * from (
	SELECT TOP 30 
		[Maintenance cost] = (user_updates + system_updates) 
		,[Retrieval usage] = (user_seeks + user_scans + user_lookups) 
		,DatabaseName = DB_NAME() ,TableName = OBJECT_NAME(s.[object_id]) 
		,IndexName = i.name 
	FROM 
		sys.dm_db_index_usage_stats s 
		INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id 
	WHERE 
		s.database_id = DB_ID() 
		AND i.name IS NOT NULL 
		-- Ignore HEAP indexes.
		AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0 
		AND (user_updates + system_updates) > 0 
		-- Only report on active rows.
	ORDER BY [Retrieval usage] DESC 
	)d
'
-- mais manutenção/updates
SELECT TOP 30 *
FROM #TempMaintenanceCost
ORDER BY [Maintenance cost] DESC
-- mais usados/select
SELECT TOP 30 *
FROM #TempMaintenanceCost
ORDER BY [Retrieval usage] DESC
-- Tidy up. 
DROP TABLE #TempMaintenanceCost