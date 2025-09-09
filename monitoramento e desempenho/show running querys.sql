--title:running query
select	
	S.SPID
	,CAST( Y.STATUSID AS VARCHAR)+' - ' +(S.STATUS) STATUS	
	, CONVERT(VARCHAR, DATEADD(SECOND, DATEDIFF(SECOND, R.START_TIME, GETDATE()), 0), 108) AS [TEMPO TOTAL (HH:MM:SS)] -- TEMPO TOTAL QUE A QUERY ESTÁ RODANDO EM FORMATO HH:MM:SS
	, CASE 
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
    , DB_NAME(S.DBID ) BASE
    , S.HOSTNAME
    , S.PROGRAM_NAME 
    , S.LOGINAME 
    , S.CPU 
    , S.MEMUSAGE --NÚMERO DE PÁGINAS NO CACHE DE PROCEDIMENTO QUE ESTÃO ATUALMENTE ALOCADAS PARA ESTE PROCESSO. UM NÚMERO NEGATIVO INDICA QUE O PROCESSO ESTÁ LIBERANDO A MEMÓRIA ALOCADA POR OUTRO PROCESSO.   
    , S.PHYSICAL_IO 
    , S.WAITTIME [WAITTIME (MS)] --TEMPO DE ESPERA ATUAL EM MILISSEGUNDOS
    , S.LASTWAITTYPE 
    , case 
            WHEN S.WAITTIME = 0X0000 THEN 'sem espera'
            WHEN S.WAITTYPE =0X006E THEN 'aguardando memoria'
            WHEN S.WAITTYPE =0X0061 THEN 'sessão está aguardando a liberação de memória.a sessão está tentando alocar ou acessar um recurso de memória, mas a quantidade disponível no momento está insuficiente.'
            WHEN S.WAITTYPE =0X02F2 THEN 'aguardando a conclusão de uma operação de E/S'
            WHEN S.WAITTYPE =0X00BF THEN 'sessão está aguardando a liberação de um spinlock'
            WHEN S.LASTWAITTYPE LIKE 'LCK_%' AND S.WAITTYPE <> 0X0000 THEN rtrim(S.LASTWAITTYPE)+' - bloqueio compartilhado "'+ISNULL(RES_ID.DESCRICAO,'') +'" em "'+ISNULL(RES_ID.TIPO,'')+'":'+ISNULL(RES_NAME.OBJECT_NAME,S.WAITRESOURCE) --bloqueio compartilhado em um recurso específico    		
            ELSE CONVERT(VARCHAR(64), S.WAITTYPE, 1)
    END ESPERA    
    , S.WAITRESOURCE 
    , M.REQUESTED_MEMORY_KB/1024 [MEMORIA REQUISITADA MB] --Quantidade total solicitada de memória em quilobytes.
    , M.GRANTED_MEMORY_KB/1024 	[TOTAL DE MEMÓRIA REALMENTE CONCEDIDO MB]		--Total de memória realmente concedido em quilobytes. Poderá ser NULL se a memória ainda não tiver sido concedida.
    , M.REQUIRED_MEMORY_KB/1024 [MEMÓRIA MÍNIMA EXIGIDA MB]
	,S.CMD
	,Y.DESCRICAO
	,BLOCK_SESSION.BLOCKED_SESSIONS_ID
	,BLOCK_SESSION.BLOCKING_SESSION_ID
	,RES_ID.[DATABASE_ID]
from  
	SYS.SYSPROCESSES S WITH(NOLOCK)
	OUTER APPLY (select text  scriptSQL from ::fn_get_sql(s.sql_handle)) X
	left join ( values (9,'dormant','SQL Server está redefinindo/resetting  a sessão.')
		,('1','running','A sessão está executando um ou mais lotes. Quando são habilitados MARS (Vários Conjuntos de Resultados Ativos), uma sessão pode executar vários lotes. Para obter mais informações, consulte Usando MARS (vários conjuntos de resultados ativos).')
		,('4','background','A sessão está executando uma tarefa em segundo plano, como a detecção de deadlock.')
		,('3','rollback ','A sessão tem uma reversão de transação em processo.')
		,('5','pending','A sessão está esperando um thread de trabalho ficar disponível.')
		,('2','runnable','A tarefa na sessão está na fila executável de um agendador enquanto aguarda um quantum de tempo.')
		,('7','spinloop','A tarefa na sessão está aguardando a liberação de um spinlock.')
		,('8','suspended','A sessão está aguardando a conclusão de um evento, como E/S, commit, rollback, liberação de lock ou reversão de transação.')	
		,('10','sleeping','There is no work to be done.')	
	) y(statusId,status,descricao) on  s.status = y.status
	LEFT JOIN SYS.DM_EXEC_QUERY_MEMORY_GRANTS M WITH(NOLOCK) ON  M.SESSION_ID = S.SPID
	LEFT JOIN SYS.DM_EXEC_REQUESTS R WITH(NOLOCK) ON R.SESSION_ID = S.SPID
	OUTER APPLY (
		select
			LEFT(a, pos - 2) AS tipo			
			, CASE  -- Extrair o object_id (aplicável apenas a TAB)
				WHEN LEFT(a, 3) = 'TAB' THEN 
					ltrim(SUBSTRING(a, pos+4 , 7)) 
				ELSE NULL
			END AS [object_id]
			, CAST(SUBSTRING(a, pos+1, CHARINDEX(':', a, pos) - CHARINDEX(':', a) - 2) AS INT) AS [DATABASE_ID]
			, CASE -- Extrair o index_ (apenas para TAB)
				WHEN LEFT(a, 3) = 'TAB' THEN
					CAST(RIGHT(a, CHARINDEX(':', REVERSE(a)) - 1) AS INT)
				ELSE NULL
			END AS [index_]
			, CASE -- Extrair o hobt_id (apenas para KEY) (https://kendralittle.com/2016/10/17/decoding-key-and-page-waitresource-for-deadlocks-and-blocking/)
				WHEN LEFT(a, 3) = 'KEY' THEN 
					CAST(SUBSTRING(a, CHARINDEX(':', a, CHARINDEX(':', a) + 1) + 2, 
					CHARINDEX(' ', a, CHARINDEX(':', a, CHARINDEX(':', a) + 1)) - 
					CHARINDEX(':', a, CHARINDEX(':', a) + 1) - 2) AS BIGINT)
				ELSE NULL
			END AS [hobt_id]
			, CASE -- Extrair o lockres (apenas para KEY)
				WHEN LEFT(a, 3) = 'KEY' THEN --'KEY: 5:72057594644070400 (9974e8bb7b0c)                                              '
					(
						select
							SUBSTRING(c, pos1, pos2 - pos1) as lockres
						FROM
							(
								VALUES
									(rtrim(ltrim(a)))
							) as b(c)
							OUTER APPLY (
								SELECT
									CHARINDEX('(', c) + 1 AS pos1
									, CHARINDEX(')', c) AS pos2
							) as d
					)
				ELSE NULL
			END AS [lockres]			
			, CASE-- Extrair o FileID (apenas para PAGE e RID)
				WHEN LEFT(a, 4) IN ('PAGE', 'RID') THEN
					CAST(SUBSTRING(a, CHARINDEX(':', a, CHARINDEX(':', a) + 1) + 2, 
					CHARINDEX(':', a, CHARINDEX(':', a, CHARINDEX(':', a) + 1) + 1) - 
					CHARINDEX(':', a, CHARINDEX(':', a) + 1) - 2) AS INT)
				ELSE NULL
			END AS [FileID]
			, CASE -- Extrair o PageID (apenas para PAGE e RID)
				WHEN LEFT(a, 4) IN ('PAGE', 'RID') THEN
					CAST(RIGHT(a, CHARINDEX(':', REVERSE(a)) - 1) AS INT)
				ELSE NULL
			END AS [PageID]
			, CASE S.LASTWAITTYPE
				WHEN 'LCK_M_X' THEN 'exclusivo'
				WHEN 'LCK_M_S' THEN 'compartilhado'
				WHEN 'LCK_M_U' THEN 'update'
				WHEN 'LCK_M_IS' THEN 'intenção compartilhada'
				WHEN 'LCK_M_IU' THEN 'intenção update'
				WHEN 'LCK_M_SCH_M' THEN 'schema modification'
				WHEN 'LCK_M_SCH_S' THEN 'schema stability'
				WHEN 'LCK_M_X' THEN 'exclusivo'
				WHEN 'LCK_M_U' THEN 'update'
				WHEN 'LCK_M_IS' THEN 'intenção compartilhada'
				WHEN 'LCK_M_IU' THEN 'intenção update'
				WHEN 'LCK_M_SCH_M' THEN 'schema modification'
				WHEN 'LCK_M_SCH_S' THEN 'schema stability'
				ELSE S.LASTWAITTYPE
			END AS DESCRICAO
			,A.A 
		FROM (
			SELECT 
				CHARINDEX(':', S.WAITRESOURCE) + 1 AS POS
				, S.WAITRESOURCE AS A
				, isnull(LEN(S.WAITRESOURCE),0) l
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
					and ISNUMERIC(res_id.object_id) = 1 
					and ISNUMERIC(res_id.database_id) = 1 then OBJECT_NAME(res_id.object_id, res_id.database_id)
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