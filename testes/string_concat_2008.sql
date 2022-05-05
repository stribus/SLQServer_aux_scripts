SELECT
	STUFF(
		(
			SELECT
				',' + V.String
			FROM
				(
				VALUES('7 > 5')
				,('Salt & pepper')
				,('2 lines')
				)V(String)
              FOR XML PATH('')
		)
		, 1
		, 1
		, ''
	);
	
SELECT
	STUFF(
		(
			SELECT
				',' + V.String
			FROM
				(
				VALUES('7 > 5',2)
				,('Salt & pepper',2)
				,('2
lines',2)
				)V(String)
              FOR XML PATH('')
				, TYPE
		).value(
			'(./text())[1]'
			, 'varchar(MAX)'
		)
		, 1
		, 1
		, ''
	);