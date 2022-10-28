SELECT
    db.name AS DBName,
    type_desc AS FileType,
    Physical_Name AS Location
    , case 
    	when mf.[size]*8 < 1024 then cast(mf.[size]*8 as varchar)+ 'kb'
    	when mf.[size]*8/1024 < 1024 then cast(mf.[size]*8/1024 as varchar)+ 'mb'
    	when mf.[size]*8/1014/1024 < 1024 then cast(mf.[size]*8/1024/1024 as varchar)+ 'gb'
    	when mf.[size]*8/1014/1024/1024 < 1024 then cast(mf.[size]*8/1024/1024/1024 as varchar)+ 'tb'
    end tamanho     
FROM
    sys.master_files mf
INNER JOIN 
    sys.databases db ON db.database_id = mf.database_id
    
    
    
 ----- espaço livre em disco   
declare @svrName varchar(255)
declare @sql varchar(400)
--by default it will take the current server name, we can the set the server name as well
set @svrName = @@SERVERNAME
set @sql = 'powershell.exe -c "Get-WmiObject -ComputerName ' + QUOTENAME(@svrName,'''') + ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"'
--creating a temporary table
CREATE TABLE #output
(line varchar(255))
--inserting disk name, total space and free space value in to temporary table
insert #output
EXEC xp_cmdshell @sql
----script to retrieve the values in MB from PS Script output
--select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as drivename
--   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
--   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) as 'capacity(MB)'
--   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
--   (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float),0) as 'freespace(MB)'
--from #output
--where line like '[A-Z][:]%'
--order by drivename
--script to retrieve the values in GB from PS Script output
select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as drivename
   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float)/1024,0) as 'capacity(GB)'
   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
   (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float) /1024 ,0)as 'freespace(GB)'
from #output
where line like '[A-Z][:]%'
order by drivename
--script to drop the temporary table
drop table #output    



/*

--- MOVER ARQUIVOS 
USE master;
ALTER DATABASE novo_sgp_diario SET OFFLINE WITH ROLLBACK IMMEDIATE;
--ALTER DATABASE novo_sgp_diario MODIFY FILE (name='novo_sgp_diario',filename='T:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\novo_sgp_diario.mdf'); --Filename is new location
ALTER DATABASE novo_sgp_diario MODIFY FILE (name='novo_sgp_diario_log',filename='T:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\novo_sgp_diario_log.ldf');

ALTER DATABASE novo_sgp_diario SET ONLINE;
