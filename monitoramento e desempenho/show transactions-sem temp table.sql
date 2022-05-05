SET NOCOUNT ON

DECLARE @SqlStmnt varchar(100)='%FALTA%'
DECLARE @login varchar(100)= 'sa'

DECLARE @WaitThreshold INT = 1 * 100000 ;-- Segundos;
DECLARE @ServerVersion INT;

Set @ServerVersion = Replace(Left(Convert(VARCHAR, ServerProperty('ProductVersion')), 2), '.', '');


WITH tmpBlockers AS (
SELECT
		SessionID = S.session_id,
		HeadBlocker = CASE WHEN R.blocking_session_id IS NULL OR R.blocking_session_id = 0 THEN 'TRUE' ELSE 'FALSE' END,
		BlockingSessionID = R.blocking_session_id,
		RequestStatus = R.[status],
		SessionStatus = S.[status],
		SqlStmnt = Cast(Left(
			CASE R.[sql_handle]
				WHEN NULL THEN (SELECT [text] FROM sys.dm_exec_sql_text(R.[sql_handle]))
				ELSE (SELECT [text] FROM sys.dm_exec_sql_text(C.most_recent_sql_handle)) 
			END, 4000) AS NVARCHAR(4000)),
		ProgramName = S.[program_name],
		HostName = S.[host_name],
		HostProcessID = S.host_process_id,
		LoginName = S.login_name,
		LoginTime = S.login_time,
		RequestStartTime = R.start_time,
		--DurRequest = Convert(VARCHAR(15), DateAdd(MILLISECOND, DateDiff(MILLISECOND, R.start_time, GetDate()), '1900-01-01'), 114),
		WaitType = R.wait_type,
		LastWaitType = R.last_wait_type,
		WaitTimeSec = (R.wait_time / 1000),
		Command = R.command,
		WaitResource = R.wait_resource,
		TransIsolationLevel = 
			CASE Coalesce(R.transaction_isolation_level, S.transaction_isolation_level)
				WHEN 0 THEN 'UNSPECIFIED'
				WHEN 1 THEN 'READ UNCOMMITTED'
				WHEN 2 THEN 'READ COMMITTED'
				WHEN 3 THEN 'REPEATABLE'
				WHEN 4 THEN 'SERIALIZABLE' 
				WHEN 5 THEN 'SNAPSHOT' 
				ELSE Convert(VARCHAR(10), Coalesce(R.transaction_isolation_level, S.transaction_isolation_level)) + '-Unknown' 
			END,
		OpenTransCount = R.open_transaction_count,
		OpenResultSetCount = R.open_resultset_count,
		PercentComplete = Convert(DECIMAL(10, 5), R.percent_complete),
		EstimatedCompletionTime = R.estimated_completion_time,
		RequestLogicalReads = 
			CASE 
				WHEN (@ServerVersion > 9) OR (@ServerVersion = 9 AND ServerProperty('ProductLevel') >= 'SP2' COLLATE Latin1_General_BIN) THEN R.logical_reads 
				ELSE R.logical_reads - S.logical_reads 
			END,  
		RequestReads = 
			CASE 
				WHEN (@ServerVersion > 9) OR (@ServerVersion = 9 AND ServerProperty('ProductLevel') >= 'SP2' COLLATE Latin1_General_BIN) THEN R.reads 
				ELSE R.reads - S.reads 
			END,  
		RequestWrites = 
			CASE 
				WHEN (@ServerVersion > 9) OR (@ServerVersion = 9 AND ServerProperty('ProductLevel') >= 'SP2' COLLATE Latin1_General_BIN) THEN R.writes 
				ELSE R.writes - S.writes 
			END,
		RequestCPUTime = R.cpu_time,
		LockTimeout = R.[lock_timeout],
		DeadlockPriority = R.[deadlock_priority],
		RequestRowCount = R.row_count,
		RequestPrevError = R.prev_error,
		NestLevel = R.nest_level, 
		GrantedQueryMemory = R.granted_query_memory, 
		IsUserProcess = S.is_user_process,
		UserID = R.[user_id], 
		TransactionID = R.transaction_id, 
		SessionCPUTime = S.cpu_time, 
		MemoryUsage = S.memory_usage, 
		SessionReads = S.reads,
		SessionLogicalReads= S.logical_reads, 
		SessionWrites= S.writes, 
		SessionPrevError = S.prev_error, 
		SessionRowCount = S.row_count
	--INTO #tmpBlockers
	FROM sys.dm_exec_sessions S
		LEFT OUTER JOIN sys.dm_exec_requests R ON R.session_id = S.session_id
		LEFT OUTER JOIN sys.dm_exec_connections C ON C.session_id = S.session_id
	WHERE
		S.session_id >= 50
)
-- Procura os tipos ou n�veis de bloqueios
, BlockingLevels(SessionID, BlockingSessionID, BlockingLevel, HeadBlocker) AS
(
		SELECT SessionID, BlockingSessionID, 0 AS BlockingLevel, SessionID AS HeadBlocker
			FROM tmpBlockers
			WHERE BlockingSessionID IS NULL OR BlockingSessionID = 0
	UNION ALL
		SELECT TB.SessionID, TB.BlockingSessionID, BL.BlockingLevel + 1 AS BlockingLevel, BL.HeadBlocker AS HeadBlocker
			FROM tmpBlockers TB
				JOIN BlockingLevels BL ON TB.BlockingSessionID = BL.SessionID
)
, tmpHeadBlockers as  
(SELECT *
	--INTO #tmpHeadBlockers
	FROM BlockingLevels
),
tmpHeadBlockerDepth as (
SELECT COUNT(*) - 1 AS HeadBlockingDepth, HeadBlocker 
	--INTO #tmpHeadBlockerDepth 
	FROM tmpHeadBlockers 
	GROUP BY HeadBlocker 
)
-- Esta query pode ser recolhida na consulta acima. Arqui � dividido para evitar um consumo alto de mem�ria.
SELECT
		TB.SessionID, 
		TB.BlockingSessionID, 
		THB.BlockingLevel, 
		TB.HeadBlocker, 
		THBD.HeadBlockingDepth, 
		TB.RequestStatus, 
		TB.SessionStatus, 
		TB.SqlStmnt, 
		TB.RequestStartTime, 
		--TB.DurRequest,
		TB.WaitType, 
		TB.LastWaitType, 
		TB.WaitTimeSec, 
		TB.Command, 
		TB.ProgramName, 
		TB.HostName, 
		TB.HostProcessID, 
		TB.IsUserProcess, 
		TB.LoginName, 
		TB.LoginName, 
		TB.WaitResource, 
		TB.TransIsolationLevel, 
		TB.OpenTransCount, 
		TB.OpenResultSetCount, 
		TransactionName = Coalesce([AT].[name], AT2.[name]), 
		TransactionBeginTime = Coalesce([AT].transaction_begin_time, AT2.transaction_begin_time), 
		TransactionType = 
			CASE Coalesce([AT].transaction_type, AT2.transaction_type) 
				WHEN 1 THEN 'READ/WRITE TRANSACTION' 
				WHEN 2 THEN 'READ-ONLY TRANSACTION' 
				WHEN 3 THEN 'SYSTEM TRANSACTION' 
				WHEN 4 THEN 'DISTRIBUTED TRANSACTION' 
				ELSE Convert(VARCHAR(10), Coalesce([AT].transaction_type, AT2.transaction_type)) + '-UNKNOWN' 
			END , 
		TransactionState = 
			CASE Coalesce([AT].transaction_state, AT2.transaction_state) 
				WHEN 0 THEN 'THE TRANSACTION HAS NOT BEEN COMPLETELY INITIALIZED YET.' 
				WHEN 1 THEN 'THE TRANSACTION HAS BEEN INITIALIZED BUT HAS NOT STARTED.' 
				WHEN 2 THEN 'THE TRANSACTION IS ACTIVE.' 
				WHEN 3 THEN 'THE TRANSACTION HAS ENDED. THIS IS USED FOR READ-ONLY TRANSACTIONS.' 
				WHEN 4 THEN 'THE COMMIT PROCESS HAS BEEN INITIATED ON THE DISTRIBUTED TRANSACTION. THIS IS FOR DISTRIBUTED TRANSACTIONS ONLY. THE DISTRIBUTED TRANSACTION IS STILL ACTIVE BUT FURTHER PROCESSING CANNOT TAKE PLACE.' 
				WHEN 5 THEN 'THE TRANSACTION IS IN A PREPARED STATE AND WAITING RESOLUTION.' 
				WHEN 6 THEN 'THE TRANSACTION HAS BEEN COMMITTED.' 
				WHEN 7 THEN 'THE TRANSACTION IS BEING ROLLED BACK.' 
				WHEN 8 THEN 'THE TRANSACTION HAS BEEN ROLLED BACK.' 
				ELSE Convert(VARCHAR(10), Coalesce([AT].transaction_state, AT2.transaction_state)) + '-UNKNOWN' 
			END, 
		TB.PercentComplete, 
		TB.EstimatedCompletionTime, 
		TB.RequestLogicalReads, 
		TB.RequestReads, 
		TB.RequestWrites, 
		TB.RequestCPUTime, 
		TB.LockTimeout, 
		TB.DeadlockPriority, 
		TB.RequestRowCount, 
		TB.RequestPrevError, 
		TB.NestLevel, 
		TB.GrantedQueryMemory, 
		TB.UserID, 
		TB.TransactionID, 
		TB.SessionCPUTime, 
		TB.MemoryUsage, 
		TB.SessionReads, 
		TB.SessionLogicalReads, 
		TB.SessionWrites, 
		TB.SessionPrevError, 
		TB.SessionRowCount 
	FROM tmpBlockers TB 
		LEFT OUTER JOIN sys.dm_tran_active_transactions [AT] ON [AT].transaction_id = TB.TransactionID
		LEFT OUTER JOIN sys.dm_tran_session_transactions TS ON TS.session_id = TB.SessionID
		LEFT OUTER JOIN sys.dm_tran_active_transactions AS AT2 ON AT2.transaction_id = TS.transaction_id 
		LEFT OUTER JOIN tmpHeadBlockers AS THB ON THB.SessionID = TB.SessionID
		LEFT OUTER JOIN tmpHeadBlockerDepth AS THBD ON THBD.HeadBlocker = TB.SessionID
	where 
		TB.LoginName = @login
		and TB.SqlStmnt like @SqlStmnt
	ORDER BY TB.HeadBlocker DESC, THB.BlockingLevel

