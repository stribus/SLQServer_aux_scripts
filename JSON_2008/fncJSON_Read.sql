CREATE FUNCTION dbo.fncJSON_Read ( 
	@JSON NVARCHAR(MAX) 
)
RETURNS @Retorno TABLE (
	Id_Elemento INT NULL,
	Nr_Sequencia [INT] NULL,
	Id_Objeto_Pai INT,
	Id_Objeto INT,
	Ds_Nome NVARCHAR(2000),
	Ds_String NVARCHAR(MAX) NOT NULL,
	Ds_Tipo VARCHAR(10) NOT NULL
)
AS
BEGIN
	DECLARE
		@FirstObject INT,
		@OpenDelimiter INT,
		@NextOpenDelimiter INT,
		@NextCloseDelimiter INT,
		@Type NVARCHAR(10),
		@NextCloseDelimiterChar CHAR(1),
		@Contents NVARCHAR(MAX),
		@Start INT,
		@end INT,
		@param INT,
		@EndOfDs_Nome INT,
		@token NVARCHAR(200),
		@value NVARCHAR(MAX),
		@Nr_Sequencia INT,
		@Ds_Nome NVARCHAR(200),
		@Id_Objeto_Pai INT,
		@lenJSON INT,
		@characters NCHAR(36),
		@result BIGINT,
		@index SMALLINT,
		@Escape INT
	DECLARE @Strings TABLE (
		String_ID INT IDENTITY(1, 1),
		Ds_String NVARCHAR(MAX)
	)
	SELECT
		@characters = '0123456789abcdefghijklmnopqrstuvwxyz',	@Nr_Sequencia = 0, 	@Id_Objeto_Pai = 0
		
WHILE (1 = 1)
BEGIN
	SELECT @Start = PATINDEX('%[^a-zA-Z]["]%', @JSON COLLATE SQL_Latin1_General_CP850_BIN)
IF (@Start = 0)
	BREAK
IF (SUBSTRING(@JSON, @Start + 1, 1) = '"')
BEGIN
	SET @Start = @Start + 1
	SET @end = PATINDEX('%[^\]["]%', RIGHT(@JSON, LEN(@JSON + '|') - @Start) COLLATE SQL_Latin1_General_CP850_BIN)
		END
		IF (@end = 0)
			BREAK
		SELECT
			@token = SUBSTRING(@JSON, @Start + 1, @end - 1)

		SELECT
			@token = REPLACE(@token, FromString, ToString)
		FROM (
			SELECT '\"' AS FromString, '"' AS ToString
	UNION ALL
	SELECT '\\', '\'
	UNION ALL
	SELECT '\/', '/'
	UNION ALL
	SELECT '\b', CHAR(08)
	UNION ALL
	SELECT '\f', CHAR(12)
	UNION ALL
	SELECT '\n', CHAR(10)
	UNION ALL
	SELECT '\r', CHAR(13)
	UNION ALL
	SELECT '\t', CHAR(09)
) substitutions

SELECT
	@result = 0,
	@Escape = 1
	
WHILE (@Escape > 0)
BEGIN
	SELECT
		@index = 0,
		@Escape = PATINDEX('%\x[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%', @token COLLATE SQL_Latin1_General_CP850_BIN)

			IF (@Escape > 0)
			BEGIN
				WHILE (@index < 4)
				BEGIN
					SELECT
						@result = @result + POWER(16, @index) * ( CHARINDEX(SUBSTRING(@token, @Escape + 2 + 3 - @index, 1), @characters) - 1 ),
						@index = @index + 1
				END
				SELECT @token = STUFF(@token, @Escape, 6, NCHAR(@result))
			END
		END

		INSERT INTO @Strings ( Ds_String )
		SELECT @token

		SELECT @JSON = STUFF(@JSON, @Start, @end + 1, '@string' + CONVERT(NVARCHAR(5), @@IDENTITY))
	END

	WHILE (1 = 1)
	BEGIN
 
		SELECT @Id_Objeto_Pai = @Id_Objeto_Pai + 1
		SELECT @FirstObject = PATINDEX('%[{[[]%', @JSON COLLATE SQL_Latin1_General_CP850_BIN)
		IF (@FirstObject = 0)
			BREAK

		IF ( SUBSTRING(@JSON, @FirstObject, 1) = '{' )
	SELECT @NextCloseDelimiterChar = '}', @Type = 'object'
ELSE
	SELECT @NextCloseDelimiterChar = ']', @Type = 'array'
			 
		SELECT @OpenDelimiter = @FirstObject
 
 
		WHILE (1 = 1)
		BEGIN
			SELECT @lenJSON = LEN(@JSON + '|') - 1
	SELECT @NextCloseDelimiter = CHARINDEX(@NextCloseDelimiterChar, @JSON, @OpenDelimiter + 1)
	SELECT @NextOpenDelimiter = PATINDEX('%[{[[]%', RIGHT(@JSON, @lenJSON - @OpenDelimiter) COLLATE SQL_Latin1_General_CP850_BIN)

			IF (@NextOpenDelimiter = 0)
				BREAK

			SELECT @NextOpenDelimiter = @NextOpenDelimiter + @OpenDelimiter

			IF (@NextCloseDelimiter < @NextOpenDelimiter)
				BREAK

			IF SUBSTRING(@JSON, @NextOpenDelimiter, 1) = '{'
		SELECT @NextCloseDelimiterChar = '}', @Type = 'object'
	ELSE
		SELECT @NextCloseDelimiterChar = ']', @Type = 'array'

			SELECT @OpenDelimiter = @NextOpenDelimiter

		END

		SELECT @Contents = SUBSTRING(@JSON, @OpenDelimiter + 1, @NextCloseDelimiter - @OpenDelimiter - 1)
		SELECT @JSON = STUFF(@JSON, @OpenDelimiter, @NextCloseDelimiter - @OpenDelimiter + 1, '@' + @Type + CONVERT(NVARCHAR(5), @Id_Objeto_Pai))

		WHILE (( PATINDEX('%[A-Za-z0-9@+.e]%', @Contents COLLATE SQL_Latin1_General_CP850_BIN) ) <> 0)
BEGIN
	IF (@Type = 'Object')
	BEGIN
		SELECT 
			@Nr_Sequencia = 0,
			@end = CHARINDEX(':', ' ' + @Contents)

				SELECT @Start = PATINDEX('%[^A-Za-z@][@]%', ' ' + @Contents COLLATE SQL_Latin1_General_CP850_BIN)--AAAAAAAA

				SELECT @token = SUBSTRING(' ' + @Contents, @Start + 1, @end - @Start - 1), @EndOfDs_Nome = PATINDEX('%[0-9]%', @token COLLATE SQL_Latin1_General_CP850_BIN), @param = RIGHT(@token, LEN(@token) - @EndOfDs_Nome + 1)

				SELECT @token = LEFT(@token, @EndOfDs_Nome - 1), @Contents = RIGHT(' ' + @Contents, LEN(' ' + @Contents + '|') - @end - 1)

				SELECT @Ds_Nome = Ds_String FROM 	@Strings WHERE 	String_ID = @param

			END
			ELSE
				SELECT 
					@Ds_Nome = NULL, 
					@Nr_Sequencia = @Nr_Sequencia + 1

			SELECT @end = CHARINDEX(',', @Contents)

			IF (@end = 0)
				SELECT @end = PATINDEX('%[A-Za-z0-9@+.e][^A-Za-z0-9@+.e]%', @Contents + ' ' COLLATE SQL_Latin1_General_CP850_BIN) + 1

			SELECT @Start = PATINDEX('%[^A-Za-z0-9@+.e][A-Za-z0-9@+.e]%', ' ' + @Contents COLLATE SQL_Latin1_General_CP850_BIN)

			SELECT
				@value = RTRIM(SUBSTRING(@Contents, @Start, @end - @Start)),
				@Contents = RIGHT(@Contents + ' ', LEN(@Contents + '|') - @end)

			IF (SUBSTRING(@value, 1, 7) = '@object')
	BEGIN
		INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Id_Objeto, Ds_Tipo )
		SELECT
			@Ds_Nome,
			@Nr_Sequencia,
			@Id_Objeto_Pai,
			SUBSTRING(@value, 8, 5),
			SUBSTRING(@value, 8, 5),
			'object'
	END
	ELSE BEGIN
		IF (SUBSTRING(@value, 1, 6) = '@array')
			INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Id_Objeto, Ds_Tipo )
			SELECT
				@Ds_Nome,
				@Nr_Sequencia,
				@Id_Objeto_Pai,
				SUBSTRING(@value, 7, 5),
				SUBSTRING(@value, 7, 5),
				'array'
		ELSE
			IF (SUBSTRING(@value, 1, 7) = '@string')
				INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Ds_Tipo )
				SELECT
					@Ds_Nome,
					@Nr_Sequencia,
					@Id_Objeto_Pai,
					Ds_String,
					'string'
				 FROM
					@Strings
				 WHERE
					String_ID = SUBSTRING(@value, 8, 5)
			ELSE
				 IF (@value IN ( 'true', 'false' ))
					INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Ds_Tipo )
					SELECT
						@Ds_Nome,
						@Nr_Sequencia,
						@Id_Objeto_Pai,
						@value,
						'boolean'
				 ELSE
				 
					IF (@value = 'null')
						INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Ds_Tipo )
						SELECT
							@Ds_Nome,
							@Nr_Sequencia,
							@Id_Objeto_Pai,
							@value,
							'null'
					ELSE
						IF (PATINDEX('%[^0-9]%', @value COLLATE SQL_Latin1_General_CP850_BIN) > 0)
							INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Ds_Tipo )
							SELECT
								@Ds_Nome,
								@Nr_Sequencia,
								@Id_Objeto_Pai,
								@value,
								'real'
						ELSE
							INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Ds_Tipo )
							SELECT
								@Ds_Nome,
								@Nr_Sequencia,
								@Id_Objeto_Pai,
								@value,
								'int'
		IF (@Contents = ' ')
					SELECT @Nr_Sequencia = 0
			END
		END
	END

	INSERT INTO @Retorno ( Ds_Nome, Nr_Sequencia, Id_Objeto_Pai, Ds_String, Id_Objeto, Ds_Tipo )
	SELECT 		'-',1,NULL,'',		@Id_Objeto_Pai - 1,		@Type

	DECLARE @Tabela_Final TABLE (
		Id_Elemento INT IDENTITY(1, 1) NOT NULL,
		Nr_Sequencia [INT] NULL,
		Id_Objeto_Pai INT,
		Id_Objeto INT,
		Ds_Nome NVARCHAR(2000),
		Ds_String NVARCHAR(MAX) NOT NULL,
		Ds_Tipo VARCHAR(10) NOT NULL
	)
	INSERT INTO @Tabela_Final
	SELECT 
		Nr_Sequencia,
		Id_Objeto_Pai,
		Id_Objeto,
		Ds_Nome,
		Ds_String,
		Ds_Tipo 
	FROM
		@Retorno
	ORDER BY 
		ISNULL(Id_Objeto, Id_Objeto_Pai) DESC,
		Id_Objeto_Pai DESC,
		Id_Elemento

	DELETE FROM @Retorno

	INSERT INTO @Retorno
	SELECT
		Id_Elemento,
		Nr_Sequencia,
		Id_Objeto_Pai,
		Id_Objeto,
		Ds_Nome,
		Ds_String,
		Ds_Tipo 
	FROM 
		@Tabela_Final

	RETURN

END