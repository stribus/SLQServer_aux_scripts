
/**

	O QUE A PROCEDURE FAZ?		
		transforma os uma string json para XML, ela é uma solução de contorno para a falta de suporte a Json no SQL server anteriores ao 2016	
	--------------------------------------
	QUAIS PARAMETROS A PROCEDURE RECEBE?
		@json - varchar - String Json			
	--------------------------------------
	QUAL OS RETORNOS DADOS PELA PROCEDURES?
		ela ira retornar um objeto XML com as informaçoes do json passado	
	---------------------------------------
**/


CREATE FUNCTION dbo.fncJson2xml (
    @json VARCHAR(MAX)
)
RETURNS XML
AS
BEGIN

    DECLARE
        @output VARCHAR(MAX),
        @key VARCHAR(MAX),
        @value VARCHAR(MAX),
        @recursion_counter INT,
        @offset INT,
        @nested BIT,
        @array BIT,
        @tab CHAR(1) = CHAR(9),
        @cr CHAR(1) = CHAR(13),
        @lf CHAR(1) = CHAR(10);

    SET @json=LTRIM(RTRIM( REPLACE(REPLACE(REPLACE(@json, @cr, ''), @lf, ''), @tab, '')));

    IF (LEFT(@json, 1)<>'{' OR RIGHT(@json, 1)<>'}')
        RETURN '';

    SET @json=LTRIM(RTRIM(SUBSTRING(@json, 2, LEN(@json)-2)));

    SELECT @output = '';

    WHILE (@json <> '') 
    BEGIN;

        IF (LEFT(@json, 1)<>'"')
            RETURN 'Expected quote (start of key name). Found "' + LEFT(@json, 1)+'"';

        SET @key=SUBSTRING(@json, 2, PATINDEX('%[^\\]"%', SUBSTRING(@json, 2, LEN(@json))+' "'))
        SET @json=LTRIM(SUBSTRING(@json, LEN(@key)+3, LEN(@json)));

        IF (LEFT(@json, 1)<>':')
            RETURN 'Expected ":" after key name, found "' + LEFT(@json, 1)+'"!';

        SET @json=LTRIM(SUBSTRING(@json, 2, LEN(@json)));

        IF (LEFT(@json, 1)='[')
            SELECT @array=1, @json=LTRIM(SUBSTRING(@json, 2, LEN(@json)));

        IF (@array IS NULL) 
            SET @array=0;

        WHILE (@array IS NOT NULL) 
        BEGIN

            SELECT @value=NULL, @nested=0;
            
            IF (@value IS NULL AND LEFT(@json, 1)='{') 
            BEGIN;

                SELECT @recursion_counter=1, @offset=1;

                WHILE (@recursion_counter<>0 AND @offset<LEN(@json)) 
                BEGIN
                    SET @offset=@offset+ PATINDEX('%[{}]%', SUBSTRING(@json, @offset+1, LEN(@json)));
                    SET @recursion_counter=@recursion_counter + (CASE SUBSTRING(@json, @offset, 1) WHEN '{' THEN 1 WHEN '}' THEN -1 END);
                END

                SET @value=CAST( dbo.fncJson2xml(LEFT(@json, @offset)) AS varchar(max));
                SET @json=SUBSTRING(@json, @offset+1, LEN(@json));
                SET @nested=1;

            END

            IF (@value IS NULL AND LEFT(@json, 2)='""')
                SELECT @value='', @json=LTRIM(SUBSTRING(@json, 3, LEN(@json)));

            IF (@value IS NULL AND LEFT(@json, 1)='"') 
            BEGIN
                SET @value=SUBSTRING(@json, 2, PATINDEX('%[^\\]"%', SUBSTRING(@json, 2, LEN(@json))+' "'));
                SET @json=LTRIM(SUBSTRING(@json, LEN(@value)+3, LEN(@json)));
            END

            IF (@value IS NULL AND LEFT(@json, 1)=',')
                SET @value='';

            IF (@value IS NULL) 
            BEGIN
                SET @value=LEFT(@json, PATINDEX('%[,}]%', REPLACE(@json, ']', '}')+'}')-1);
                SET @json=SUBSTRING(@json, LEN(@value)+1, LEN(@json));
            END;

            SET @output = @output + @lf + @cr + REPLICATE(@tab, @@NESTLEVEL-1)+ '<' + REPLACE(@key, '@', '') + '>'+ ISNULL(REPLACE( REPLACE(@value, '\"', '"'), '\\', '\'), '')+ (CASE WHEN @nested=1 THEN @lf+@cr+REPLICATE(@tab, @@NESTLEVEL-1) ELSE '' END) + '</' + REPLACE(@key, '@', '') + '>'

            IF (@array=0 AND @json <> '' AND LEFT(@json, 1) <> ',')
                RETURN @output+'Expected "," after value, found "'+ LEFT(@json, 1)+'"!';

            IF (@array=1 AND LEFT(@json, 1) NOT IN (',', ']'))
                RETURN @output+'In array, expected "]" or "," after '+ 'value, found "'+LEFT(@json, 1)+'"!';

            IF (@array=1 AND LEFT(@json, 1)=']') 
            BEGIN
                SET @array=NULL;
                SET @json=LTRIM(SUBSTRING(@json, 2, LEN(@json)));

                IF (LEFT(@json, 1) NOT IN ('', ',')) 
                BEGIN
                    RETURN 'Closed array, expected ","!';
                END
            END

            
            SET @json=LTRIM(SUBSTRING(@json, 2, LEN(@json)+1));
            IF (@array=0) SET @array=NULL;

        END;
    END;

    RETURN CAST(@output AS XML);

END;
GO