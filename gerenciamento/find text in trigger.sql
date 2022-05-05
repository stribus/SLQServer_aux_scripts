DECLARE @Search varchar(255)
SET @Search=''

SELECT DISTINCT
    o.name AS Object_Name
	,o.type_desc
	, m.definition
	,o.create_date 
	,o.modify_date
	,SUBSTRING(m.definition,charindex(@search,m.definition)-50, 200) trexo
    FROM 
		sys.sql_modules        m 
        INNER JOIN sys.objects  o ON m.object_id=o.object_id
    WHERE 
    	 m.definition Like '%'+@Search+'%'
    ORDER BY 2,1

