--title:running query
select
	S.SPID
	 ,CAST( Y.STATUSID AS VARCHAR)+' - ' +(S.STATUS) STATUS
	 ,CONVERT(VARCHAR, DATEADD(SECOND, DATEDIFF(SECOND, R.START_TIME, GETDATE()), 0), 108) AS [TEMPO TOTAL (HH:MM:SS)] -- TEMPO TOTAL QUE A QUERY ESTÁ RODANDO EM FORMATO HH:MM:SS
	 ,CASE
		WHEN Y.STATUSID IN (10) THEN NULL
		ELSE SUBSTRING(  SCRIPTSQL,
            COALESCE(NULLIF(STMT_START / 2, 0), 1),
            CASE STMT_END
                WHEN -1
                    THEN DATALENGTH(SCRIPTSQL)
                ELSE
                    (STMT_END / 2 - COALESCE(NULLIF(STMT_START / 2, 0), 1))
                END
        )
     END   RODANDO
     ,SCRIPTSQL
     ,OBJECT_NAME(st.objectid, st.dbid) AS NomeObjeto
     ,DB_NAME(S.DBID ) BASE
     ,S.HOSTNAME
     ,S.PROGRAM_NAME
     ,S.LOGINAME
     ,S.CPU
     ,S.MEMUSAGE --NÚMERO DE PÁGINAS NO CACHE DE PROCEDIMENTO QUE ESTÃO ATUALMENTE ALOCADAS PARA ESTE PROCESSO. UM NÚMERO NEGATIVO INDICA QUE O PROCESSO ESTÁ LIBERANDO A MEMÓRIA ALOCADA POR OUTRO PROCESSO.
     ,S.PHYSICAL_IO
     ,S.WAITTIME [WAITTIME (MS)] --TEMPO DE ESPERA ATUAL EM MILISSEGUNDOS
     ,S.LASTWAITTYPE
     ,case
			WHEN S.WAITTIME = 0X0000 THEN 'sem espera'
    		WHEN S.WAITTYPE =0X006E THEN 'aguardando memoria'
    		WHEN S.WAITTYPE =0X0061 THEN 'aguardando liberação de memória (alocação insuficiente)'
    		WHEN S.WAITTYPE =0X02F2 THEN 'aguardando conclusão de E/S'
    		WHEN S.WAITTYPE =0X00BF THEN 'aguardando liberação de spinlock'
			WHEN S.WAITTYPE = 0X0070 THEN 'espera : ' + ISNULL(NULLIF(RTRIM(S.LASTWAITTYPE),''), '?')
			-- ===== BLOQUEIOS (LCK_*) =====
			WHEN S.LASTWAITTYPE LIKE 'LCK_%' AND S.WAITTYPE <> 0X0000 THEN
				'BLOQUEIO: ' + rtrim(S.LASTWAITTYPE)
				+ ' [' + ISNULL(RES_ID.DESCRICAO,'?') + ']'
				+ ' em ' + ISNULL(RES_ID.TIPO,'')
				+ ':' + ISNULL(RES_NAME.OBJECT_NAME, S.WAITRESOURCE)
				+ CASE WHEN S.BLOCKED > 0 THEN ' (bloqueado por SPID ' + CAST(S.BLOCKED AS VARCHAR) + ')' ELSE '' END
			-- ===== ESPERAS DE E/S =====
			WHEN S.LASTWAITTYPE LIKE 'PAGEIOLATCH_%' THEN 'E/S disco: ' + S.LASTWAITTYPE + ' (' + CAST(S.WAITTIME AS VARCHAR) + 'ms)'
			WHEN S.LASTWAITTYPE = 'WRITELOG' THEN 'Gravacao log transacao (' + CAST(S.WAITTIME AS VARCHAR) + 'ms)'
			WHEN S.LASTWAITTYPE = 'IO_COMPLETION' THEN 'Conclusao E/S (' + CAST(S.WAITTIME AS VARCHAR) + 'ms)'
			-- ===== ESPERAS DE REDE =====
			WHEN S.LASTWAITTYPE = 'ASYNC_NETWORK_IO' THEN 'Aguardando cliente consumir dados'
			-- ===== ESPERAS DE PARALELISMO =====
			WHEN S.LASTWAITTYPE IN ('CXPACKET','CXCONSUMER','CXSYNC_PORT','CXSYNC_CONSUMER') THEN 'Paralelismo: ' + S.LASTWAITTYPE
			-- ===== ESPERAS DE MEMORIA =====
			WHEN S.LASTWAITTYPE = 'RESOURCE_SEMAPHORE' THEN 'Aguardando concessao de memoria'
			WHEN S.LASTWAITTYPE = 'SOS_SCHEDULER_YIELD' THEN 'Quantum expirado (CPU)'
			-- ===== ESPERAS DE LATCH =====
			WHEN S.LASTWAITTYPE LIKE 'LATCH_%' THEN 'Latch: ' + S.LASTWAITTYPE
			WHEN S.LASTWAITTYPE LIKE 'PAGELATCH_%' THEN 'Contencao pagina memoria: ' + S.LASTWAITTYPE
    		ELSE CONVERT(VARCHAR(64), S.WAITTYPE, 1) + CASE WHEN S.LASTWAITTYPE <> '' THEN ' (' + rtrim(S.LASTWAITTYPE) + ')' ELSE '' END
    END ESPERA
     ,S.WAITRESOURCE
     ,M.REQUESTED_MEMORY_KB/1024 [MEMORIA REQUISITADA MB] --Quantidade total solicitada de memória em quilobytes.
     ,M.GRANTED_MEMORY_KB/1024 	[TOTAL DE MEMÓRIA REALMENTE CONCEDIDO MB]		--Total de memória realmente concedido em quilobytes. Poderá ser NULL se a memória ainda não tiver sido concedida.
     ,M.REQUIRED_MEMORY_KB/1024 [MEMÓRIA MÍNIMA EXIGIDA MB]
	 ,S.CMD
	 ,Y.DESCRICAO
	 ,BLOCK_SESSION.BLOCKED_SESSIONS_ID
	 ,BLOCK_SESSION.BLOCKING_SESSION_ID
	 ,RES_ID.[DATABASE_ID]
from
	SYS.SYSPROCESSES S WITH(NOLOCK)
	OUTER APPLY (select text  scriptSQL
	from ::fn_get_sql(s.sql_handle)) X
	left join ( values
		(9 ,'dormant' ,'SQL Server está redefinindo/resetting  a sessão.')
		,('1' ,'running' ,'A sessão está executando um ou mais lotes. Quando são habilitados MARS (Vários Conjuntos de Resultados Ativos), uma sessão pode executar vários lotes. Para obter mais informações, consulte Usando MARS (vários conjuntos de resultados ativos).')
		,('4' ,'background' ,'A sessão está executando uma tarefa em segundo plano, como a detecção de deadlock.')
		,('3' ,'rollback ' ,'A sessão tem uma reversão de transação em processo.')
		,('5' ,'pending' ,'A sessão está esperando um thread de trabalho ficar disponível.')
		,('2' ,'runnable' ,'A tarefa na sessão está na fila executável de um agendador enquanto aguarda um quantum de tempo.')
		,('7' ,'spinloop' ,'A tarefa na sessão está aguardando a liberação de um spinlock.')
		,('8' ,'suspended' ,'A sessão está aguardando a conclusão de um evento, como E/S, commit, rollback, liberação de lock ou reversão de transação.')
		,('10' ,'sleeping' ,'There is no work to be done.')
	) y(statusId,status,descricao) on  s.status = y.status
	LEFT JOIN SYS.DM_EXEC_QUERY_MEMORY_GRANTS M WITH(NOLOCK) ON  M.SESSION_ID = S.SPID
	LEFT JOIN SYS.DM_EXEC_REQUESTS R WITH(NOLOCK) ON R.SESSION_ID = S.SPID
	OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
	OUTER APPLY (
		select
		LEFT(a, pos - 2) AS tipo
			-- object_id: extrair dinamicamente até o próximo ':' (sem hardcode de 7 chars)
			 ,CASE
				WHEN LEFT(a, 3) = 'TAB' THEN
					ltrim(SUBSTRING(a, pos2 + 1,
						CHARINDEX(':', a, pos2 + 1) - pos2 - 1
					))
				ELSE NULL
			END AS [object_id]
			 ,TRY_CAST(SUBSTRING(a, pos+1, CHARINDEX(':', a, pos) - CHARINDEX(':', a) - 2) AS INT) AS [DATABASE_ID]
			 ,CASE -- index_ (apenas TAB)
				WHEN LEFT(a, 3) = 'TAB' THEN
					TRY_CAST(RIGHT(a, CHARINDEX(':', REVERSE(a)) - 1) AS INT)
				ELSE NULL
			END AS [index_]
			 ,CASE -- hobt_id (apenas KEY)
				WHEN LEFT(a, 3) = 'KEY' THEN
					TRY_CAST(SUBSTRING(a, CHARINDEX(':', a, CHARINDEX(':', a) + 1) + 2,
					CHARINDEX(' ', a, CHARINDEX(':', a, CHARINDEX(':', a) + 1)) -
					CHARINDEX(':', a, CHARINDEX(':', a) + 1) - 2) AS BIGINT)
				ELSE NULL
			END AS [hobt_id]
			 ,CASE -- lockres (apenas KEY)
				WHEN LEFT(a, 3) = 'KEY' AND CHARINDEX('(', a) > 0 AND CHARINDEX(')', a) > CHARINDEX('(', a) THEN
					SUBSTRING(rtrim(ltrim(a)), CHARINDEX('(', rtrim(ltrim(a))) + 1, CHARINDEX(')', rtrim(ltrim(a))) - CHARINDEX('(', rtrim(ltrim(a))) - 1)
				ELSE NULL
			END AS [lockres]
			 ,CASE -- FileID (apenas PAGE e RID)
				WHEN LEFT(a, 4) IN ('PAGE', 'RID:') THEN
					TRY_CAST(SUBSTRING(a, CHARINDEX(':', a, CHARINDEX(':', a) + 1) + 2,
					CHARINDEX(':', a, CHARINDEX(':', a, CHARINDEX(':', a) + 1) + 1) -
					CHARINDEX(':', a, CHARINDEX(':', a) + 1) - 2) AS INT)
				ELSE NULL
			END AS [FileID]
			 ,CASE -- PageID (apenas PAGE e RID)
				WHEN LEFT(a, 4) IN ('PAGE', 'RID:') THEN
					TRY_CAST(RIGHT(a, CHARINDEX(':', REVERSE(a)) - 1) AS INT)
				ELSE NULL
			END AS [PageID]
			-- DESCRICAO: sem duplicatas, com tipos adicionais
			 ,CASE S.LASTWAITTYPE
				WHEN 'LCK_M_S'     THEN 'compartilhado (S)'
				WHEN 'LCK_M_U'     THEN 'update (U)'
				WHEN 'LCK_M_X'     THEN 'exclusivo (X)'
				WHEN 'LCK_M_IS'    THEN 'intenção compartilhada (IS)'
				WHEN 'LCK_M_IU'    THEN 'intenção update (IU)'
				WHEN 'LCK_M_IX'    THEN 'intenção exclusivo (IX)'
				WHEN 'LCK_M_SIU'   THEN 'compartilhado c/ intenção update (SIU)'
				WHEN 'LCK_M_SIX'   THEN 'compartilhado c/ intenção exclusivo (SIX)'
				WHEN 'LCK_M_UIX'   THEN 'update c/ intenção exclusivo (UIX)'
				WHEN 'LCK_M_BU'    THEN 'bulk update (BU)'
				WHEN 'LCK_M_RS_S'  THEN 'range-shared compartilhado (RS-S)'
				WHEN 'LCK_M_RS_U'  THEN 'range-shared update (RS-U)'
				WHEN 'LCK_M_RIn_NL' THEN 'range-insert null (RIn-NL)'
				WHEN 'LCK_M_RX_S'  THEN 'range-exclusive compartilhado (RX-S)'
				WHEN 'LCK_M_RX_U'  THEN 'range-exclusive update (RX-U)'
				WHEN 'LCK_M_RX_X'  THEN 'range-exclusive exclusivo (RX-X)'
				WHEN 'LCK_M_SCH_M' THEN 'schema modification (Sch-M)'
				WHEN 'LCK_M_SCH_S' THEN 'schema stability (Sch-S)'
				ELSE S.LASTWAITTYPE
			END AS DESCRICAO
			 ,A.A
	FROM (
			SELECT
			CHARINDEX(':', S.WAITRESOURCE) + 1 AS POS
				 ,CHARINDEX(':', S.WAITRESOURCE, CHARINDEX(':', S.WAITRESOURCE) + 1) AS POS2 -- posição do segundo ':'
				 ,S.WAITRESOURCE AS A
				 ,isnull(LEN(S.WAITRESOURCE),0) l
		) A
	WHERE
			S.LASTWAITTYPE like 'LCK_%'
		and S.WAITRESOURCE like '%:%'
		AND POS IS NOT NULL
		AND A.POS BETWEEN 1 AND A.L
	)RES_ID
	OUTER APPLY (
		select
		case
				when
					tipo = 'TAB'
			and TRY_CAST(res_id.object_id AS INT) IS NOT NULL
			and TRY_CAST(res_id.database_id AS INT) IS NOT NULL
				then OBJECT_NAME(TRY_CAST(res_id.object_id AS INT), TRY_CAST(res_id.database_id AS INT))
				when
					tipo = 'KEY'
			and res_id.hobt_id IS NOT NULL
			and TRY_CAST(res_id.database_id AS INT) IS NOT NULL
				then (
					SELECT TOP 1
			OBJECT_NAME(p.object_id, TRY_CAST(res_id.database_id AS INT))
		FROM sys.partitions p WITH(NOLOCK)
		WHERE p.hobt_id = res_id.hobt_id
				)
				else ''
			end object_name
	)res_name
	OUTER APPLY (
		SELECT
		stuff((
				SELECT
			','+cast(blocking_session_id as varchar)
		FROM
			sys.dm_exec_requests WITH(NOLOCK)
		WHERE
									session_id = s.spid
			and blocking_session_id <> 0
		for xml path(''), type
						).value('.', 'varchar(max)'), 1, 1, '') as BLOCKED_SESSIONS_ID -- concatenação de sessões bloqueadas por esta sessão
			 ,stuff((
				SELECT
			','+cast(session_id as varchar)
		FROM
			sys.dm_exec_requests WITH(NOLOCK)
		WHERE
					blocking_session_id = s.spid
		for xml path(''), type
				).value('.', 'varchar(max)'), 1, 1, '') as BLOCKING_SESSION_ID -- concatenação de sessões bloequando esta sessão
	) BLOCK_SESSION
WHERE
	SPID <> @@SPID --REMOVE A PROPRIA CONSULTA
	--AND SPID > 50
	--AND S.HOSTNAME ='NTI202502'
	AND STMT_END <> 0
	AND (
		(S.CMD <> 'AWAITING COMMAND'
		--AND SPID > 50
		)
	OR BLOCK_SESSION.BLOCKED_SESSIONS_ID IS NOT NULL
	OR BLOCK_SESSION.BLOCKING_SESSION_ID IS NOT NULL
	)
ORDER BY Y.STATUSID

/*
SELECT
	counter_name
	, cntr_value/ 1024 [qtd memoria livre MB]
FROM
	sys.dm_os_performance_counters
WHERE
	object_name LIKE '%Memory Manager%' 
	and counter_name = 'Free Memory (KB)'

*/

--SELECT @@spid
-- kill 80


--SELECT * FROM SYS.DM_EXEC_SESSIONS WHERE  STATUS = 'running' and DATABASE_ID = DB_ID('NOVO_SGP_DIARIO') 



SELECT
    RIGHT('00' + CAST(DATEDIFF(SECOND, COALESCE(B.start_time, A.login_time), GETDATE()) / 86400 AS VARCHAR), 2) + ' ' + 
    RIGHT('00' + CAST((DATEDIFF(SECOND, COALESCE(B.start_time, A.login_time), GETDATE()) / 3600) % 24 AS VARCHAR), 2) + ':' + 
    RIGHT('00' + CAST((DATEDIFF(SECOND, COALESCE(B.start_time, A.login_time), GETDATE()) / 60) % 60 AS VARCHAR), 2) + ':' + 
    RIGHT('00' + CAST(DATEDIFF(SECOND, COALESCE(B.start_time, A.login_time), GETDATE()) % 60 AS VARCHAR), 2) + '.' + 
    RIGHT('000' + CAST(DATEDIFF(SECOND, COALESCE(B.start_time, A.login_time), GETDATE()) AS VARCHAR), 3) 
    AS Duration,
    A.session_id AS session_id,
    B.command,
    CAST('<?query --' + CHAR(10) + (
        SELECT TOP 1 SUBSTRING(X.[text], B.statement_start_offset / 2 + 1, ((CASE
                                                                          WHEN B.statement_end_offset = -1 THEN (LEN(CONVERT(NVARCHAR(MAX), X.[text])) * 2)
                                                                          ELSE B.statement_end_offset
                                                                      END
                                                                     ) - B.statement_start_offset
                                                                    ) / 2 + 1
                     )
    ) + CHAR(10) + '--?>' AS XML) AS sql_text,
    CAST('<?query --' + CHAR(10) + X.[text] + CHAR(10) + '--?>' AS XML) AS sql_command,
    A.login_name,
    '(' + CAST(B.wait_time AS VARCHAR(20)) + 'ms)' + COALESCE(B.wait_type, B.last_wait_type) + COALESCE((CASE 
        WHEN E.wait_type LIKE 'PAGEIOLATCH%' THEN ':' + DB_NAME(LEFT(E.resource_description, CHARINDEX(':', E.resource_description) - 1)) + ':' + SUBSTRING(E.resource_description, CHARINDEX(':', E.resource_description) + 1, 999)
        ELSE E.resource_description 
    END), '') AS wait_info,
    FORMAT(COALESCE(B.cpu_time, 0), '###,###,###,###,###,###,###,##0') AS CPU,
    FORMAT(COALESCE(F.tempdb_allocations, 0), '###,###,###,###,###,###,###,##0') AS tempdb_allocations,
    FORMAT(COALESCE((CASE WHEN F.tempdb_allocations > F.tempdb_current THEN F.tempdb_allocations - F.tempdb_current ELSE 0 END), 0), '###,###,###,###,###,###,###,##0') AS tempdb_current,
    FORMAT(COALESCE(B.logical_reads, 0), '###,###,###,###,###,###,###,##0') AS reads,
    FORMAT(COALESCE(B.writes, 0), '###,###,###,###,###,###,###,##0') AS writes,
    FORMAT(COALESCE(B.reads, 0), '###,###,###,###,###,###,###,##0') AS physical_reads,
    FORMAT(COALESCE(B.granted_query_memory, 0), '###,###,###,###,###,###,###,##0') AS used_memory,
    NULLIF(B.blocking_session_id, 0) AS blocking_session_id,
    (CASE 
        WHEN B.[deadlock_priority] <= -5 THEN 'Low'
        WHEN B.[deadlock_priority] > -5 AND B.[deadlock_priority] < 5 AND B.[deadlock_priority] < 5 THEN 'Normal'
        WHEN B.[deadlock_priority] >= 5 THEN 'High'
    END) + ' (' + CAST(B.[deadlock_priority] AS VARCHAR(3)) + ')' AS [deadlock_priority],
    B.row_count,
    COALESCE(A.open_transaction_count, 0) AS open_tran_count,
    (CASE B.transaction_isolation_level
        WHEN 0 THEN 'Unspecified' 
        WHEN 1 THEN 'ReadUncommitted' 
        WHEN 2 THEN 'ReadCommitted' 
        WHEN 3 THEN 'Repeatable' 
        WHEN 4 THEN 'Serializable' 
        WHEN 5 THEN 'Snapshot'
    END) AS transaction_isolation_level,
    A.[status],
    NULLIF(B.percent_complete, 0) AS percent_complete,
    A.[host_name],
    COALESCE(DB_NAME(CAST(B.database_id AS VARCHAR)), 'master') AS [database_name],
    (CASE WHEN D.name IS NOT NULL THEN 'SQLAgent - TSQL Job (' + D.name + ')' ELSE A.[program_name] END) AS [program_name],
    COALESCE(B.start_time, A.last_request_end_time) AS start_time,
    A.login_time,
    COALESCE(B.request_id, 0) AS request_id,
    W.query_plan
FROM
    sys.dm_exec_sessions AS A WITH (NOLOCK)
    LEFT JOIN sys.dm_exec_requests AS B WITH (NOLOCK) ON A.session_id = B.session_id
    JOIN sys.dm_exec_connections AS C WITH (NOLOCK) ON A.session_id = C.session_id AND A.endpoint_id = C.endpoint_id
    LEFT JOIN msdb.dbo.sysjobs AS D WITH(NOLOCK) ON RIGHT(D.job_id, 10) = RIGHT(SUBSTRING(A.[program_name], 30, 34), 10)
    LEFT JOIN (
        SELECT DISTINCT session_id, resource_description, wait_type
        FROM sys.dm_os_waiting_tasks WITH(NOLOCK)
        WHERE resource_description IS NOT NULL
        AND wait_type LIKE 'PAGEIO%'
    ) E ON A.session_id = E.session_id
    LEFT JOIN (
        SELECT
            session_id,
            request_id,
            SUM(internal_objects_alloc_page_count + user_objects_alloc_page_count) AS tempdb_allocations,
            SUM(internal_objects_dealloc_page_count + user_objects_dealloc_page_count) AS tempdb_current
        FROM
            sys.dm_db_task_space_usage WITH(NOLOCK)
        GROUP BY
            session_id,
            request_id
    ) F ON B.session_id = F.session_id AND B.request_id = F.request_id
    LEFT JOIN sys.sysprocesses AS G WITH(NOLOCK) ON A.session_id = G.spid
    OUTER APPLY sys.dm_exec_sql_text(COALESCE(B.[sql_handle], G.[sql_handle])) AS X
    OUTER APPLY sys.dm_exec_query_plan(COALESCE(B.[sql_handle], G.[sql_handle])) AS W
WHERE
    A.session_id > 50
    AND A.session_id <> @@SPID
    AND (A.[status] != 'sleeping' OR (A.[status] = 'sleeping' AND A.open_transaction_count > 0))
ORDER BY
    COALESCE(B.start_time, A.login_time)
