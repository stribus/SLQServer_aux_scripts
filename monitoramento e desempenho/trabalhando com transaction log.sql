--"D:\bases\GV_Trans_log_teste.trn"

--BACKUP LOG GVDASA_GVCOLLEGE TO DISK ='D:\bases\GV_Trans_log_teste.trn'

--SELECT
--    *
--FROM
--    fn_dblog (NULL, NULL)



SELECT 
	*
--	[Current LSN]
--	, [Transaction ID]
--	, [Transaction Name]
--	, [Operation]
--	, [Begin Time]
--	, [PartitionID]
--	, [TRANSACTION SID]
	,case
		when [TRANSACTION SID] is not null then	SUSER_SNAME([TRANSACTION SID])
	end as [LoginName]
	FROM fn_dump_dblog (
		NULL
		, NULL
		, N'DISK'
		, 1
		,N'D:\bases\GV_Trans_log_teste.trn'  --, N'D:\ReadingDBLog_201503022236.trn'		
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
		, DEFAULT
	)
where 
	[TRANSACTION SID] is not null
	or command is not null