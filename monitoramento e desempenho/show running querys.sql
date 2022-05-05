

select
	CONCAT( y.statusId,' - ' ,s.status) status
	, case 
		when y.statusId in (10) then null
		else SUBSTRING(  scriptSQL,
            COALESCE(NULLIF(stmt_start / 2, 0), 1),
            CASE stmt_end
                WHEN -1
                    THEN DATALENGTH(scriptSQL)
                ELSE
                    (stmt_end / 2 - COALESCE(NULLIF(stmt_start / 2, 0), 1))
                END
        )
     end   rodando    
    ,scriptSQL
    , s.HOSTNAME
    , s.PROGRAM_NAME 
    , s.LOGINAME 
    , s.CPU 
    , s.MEMUSAGE --Número de páginas no cache de procedimento que estão atualmente alocadas para este processo. Um número negativo indica que o processo está liberando a memória alocada por outro processo.   
    , s.physical_io 
    , s.waittime
	, DB_NAME(s.DBID ) base
	,s.cmd
	,s.spid
	,y.descricao
from  
	sys.sysprocesses s
	OUTER apply (select text  scriptSQL from ::fn_get_sql(s.sql_handle)) x
	left join ( values (9,'dormant','SQL Server está redefinindo/resetting  a sessão.')
,('1','running','A sessão está executando um ou mais lotes. Quando são habilitados MARS (Vários Conjuntos de Resultados Ativos), uma sessão pode executar vários lotes. Para obter mais informações, consulte Usando MARS (vários conjuntos de resultados ativos).')
,('4','background','A sessão está executando uma tarefa em segundo plano, como a detecção de deadlock.')
,('3','rollback ','A sessão tem uma reversão de transação em processo.')
,('5','pending','A sessão está esperando um thread de trabalho ficar disponível.')
,('2','runnable','A tarefa na sessão está na fila executável de um agendador enquanto aguarda um quantum de tempo.')
,('7','spinloop','A tarefa na sessão está aguardando a liberação de um spinlock.')
,('8','suspended','A sessão está aguardando a conclusão de um evento, como E/S.')	
,('10','sleeping','There is no work to be done.')	
	) y(statusId,status,descricao) on  s.status = y.status
where   
	spid > 50
	and spid <> @@spid --remove a propria consulta
	and stmt_end <> 0
order by y.statusId


--SELECT @@spid