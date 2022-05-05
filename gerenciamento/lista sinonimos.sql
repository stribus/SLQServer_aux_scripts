select 
	name
     , base_object_name
from 
	sys.synonyms
WHERE
	name like '%SINOMIMO%'

-- 
--DROP SYNONYM [DBO].SYNONYMO;
--go;
--CREATE SYNONYM SYNONYMO
--FOR [LINK].[BASE].[DBO].[TABELA];
--go;




EXEC sp_linkedservers  