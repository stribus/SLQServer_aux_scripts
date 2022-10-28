/**
 * sistema viagens tem uma SP que cria triggers de auditoria bem interessante
 * Sistema_Viagens \ SP_AUDITORIA_GERA_TRIGGERS
 */



/************************************************************************************************************
Inspired by: http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=84331
Created By:  Bryan Massey
Created On:  3/11/2007
Comments:  Stored proc performs the following actions:
	1) Queries system tables to retrieve table schema for @TableName parameter
	2) Creates a History table ( @TableName + '_History') to mimic the original table, plus include 
           additional history columns.
	3) If @CreateTrigger = 'Y' then it creates an Update/Delete trigger on the @TableName table, 
	   which is used to populate the History table.
        4) Writes simple script to pre-populate the Audit table with the current values of the Audited table.
Usage: 
EXEC [dbo].[AutoGenerateAuditTableAndTrigger] @TableName = N'tblBlah', @CreateTrigger = N'Y', @ExecuteProcedure = N'Y'
******************************************* MODIFICATIONS **************************************************
MM/DD/YYYY - Modified By - Description of Changes
************************************************************************************************************/
--CREATE PROCEDURE DBO.AutoGenerateAuditTableAndTrigger
--	@TableName VARCHAR(200),
--	@CreateTrigger CHAR(1) = 'Y', -- optional parameter; defaults to "Y"
--	@ExecuteProcedure CHAR(1) = 'N' 
--AS


DECLARE 	@TableName VARCHAR(200) = 'TES_PARCELARECORRENCIA',
	@CreateTrigger CHAR(1) = 'Y', -- optional parameter; defaults to "Y"
	@ExecuteProcedure CHAR(1) = 'N' ;

DECLARE @SQLTable VARCHAR(MAX), @SQLTrigger VARCHAR(MAX), @FieldList VARCHAR(6000), @FirstField VARCHAR(200), @HistoryTableName VARCHAR(MAX)
DECLARE @TAB CHAR(1), @CRLF CHAR(1), @SQL VARCHAR(1000), @Date VARCHAR(12)

SET @TAB = CHAR(9)
SET @CRLF = CHAR(13) + CHAR(10)
SET @Date = CONVERT(VARCHAR(12), GETDATE(), 101)
SET @FieldList = ''
SET @SQLTable = ''


DECLARE @FieldName VARCHAR(100), @DataType VARCHAR(50) 
DECLARE @FieldLength VARCHAR(10), @Precision VARCHAR(10), @Scale VARCHAR(10),  @FieldDescr VARCHAR(500), @AllowNulls VARCHAR(1)

DECLARE CurHistoryTable CURSOR FOR 

-- query system tables to get table schema
SELECT CONVERT(VARCHAR(100), SC.Name) AS FieldName, CONVERT(VARCHAR(50), ST.Name) AS DataType, 
	CONVERT(VARCHAR(10),SC.max_length) AS FieldLength, CONVERT(VARCHAR(10), SC.precision) AS FieldPrecision, 
	CONVERT(VARCHAR(10), SC.Scale) AS FieldScale, 
	CASE SC.Is_Nullable WHEN 1 THEN 'Y' ELSE 'N' END AS AllowNulls
FROM Sys.Objects SO
INNER JOIN Sys.Columns SC ON SO.object_ID = SC.object_ID
INNER JOIN Sys.Types ST ON SC.system_type_id = ST.system_type_id
WHERE SO.type = 'u' AND SO.Name = @TableName
ORDER BY SO.[name], SC.Column_Id ASC

OPEN CurHistoryTable

FETCH NEXT FROM CurHistoryTable INTO @FieldName, @DataType, 
	@FieldLength, @Precision, @Scale, @AllowNulls

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @HistoryTableName = @TableName + '_History'
	-- create list of table columns
	IF LEN(@FieldList) = 0
		BEGIN
			SET @FieldList = @FieldName
			SET @FirstField = @FieldName
		END
	ELSE
		BEGIN
			SET @FieldList = @FieldList + ', ' + @FieldName
		END

	if(@FieldLength = '-1')	
	BEGIN 
		SET @FieldLength = 'max';
	END
		
-- if we are at the start add the std audit columns in front
	IF LEN(@SQLTable) = 0
		BEGIN
			SET @SQLTable = 'CREATE TABLE [DBO].[' + @HistoryTableName + '] (' + @CRLF
			SET @SQLTable = @SQLTable + @TAB + '[ID] [INT] IDENTITY NOT NULL,' + @CRLF
			SET @SQLTable = @SQLTable + @TAB + '[Operation]' + @TAB + 'CHAR (1) NOT NULL,' + @CRLF
			SET @SQLTable = @SQLTable + @TAB + '[DateOfAction]' + @TAB + 'DATETIME NOT NULL,' + @CRLF
			SET @SQLTable = @SQLTable + @TAB + '['+ @TableName +'_ID]' + @TAB + '[INT] NOT NULL,' + @CRLF
		END

	-- SET @SQLTable = @TAB + @SQLTable + '/*@FieldName:'+ @FieldName +', @DataType: ' + @DataType +' @FieldLength: ' + @FieldLength +'*/' + @CRLF
	
	-- IGNORE 'sysname'
	IF UPPER(@DataType) IN ('SYSNAME')
		GOTO END_Gen
	
	-- IGNORE ID - we generate it ourselves.
	IF UPPER(@FieldName) IN ('ID')
		GOTO END_Gen
			
	SET @SQLTable = @SQLTable + @TAB + '[' + @FieldName + '] ' + '[' + @DataType + ']'
	
	IF UPPER(@DataType) IN ('CHAR', 'VARCHAR', 'NCHAR', 'NVARCHAR', 'BINARY')
		BEGIN
			-- //TODO: @FieldLength is double here - why?
			SET @SQLTable = @SQLTable + '(' + @FieldLength + ')'
		END
	ELSE IF UPPER(@DataType) IN ('DECIMAL', 'NUMERIC')
		BEGIN
			SET @SQLTable = @SQLTable + '(' + @Precision + ', ' + @Scale + ')'
		END
		
	SET @SQLTable = @SQLTable + ' NULL'

	SET @SQLTable = @SQLTable + ',' + @CRLF
		
	
	END_Gen:	

	
	


	FETCH NEXT FROM CurHistoryTable INTO @FieldName, @DataType, 
		@FieldLength, @Precision, @Scale, @AllowNulls
END

CLOSE CurHistoryTable
DEALLOCATE CurHistoryTable

-- finish history table script  and code for Primary key
SET @SQLTable = @SQLTable + ' )' + @CRLF + @CRLF
SET @SQLTable = @SQLTable + 'ALTER TABLE [dbo].[' + @HistoryTableName + ']' + @CRLF
SET @SQLTable = @SQLTable + @TAB + 'ADD CONSTRAINT [PK_' + @HistoryTableName + '_ID] PRIMARY KEY NONCLUSTERED ([ID] ASC)' + @CRLF
SET @SQLTable = @SQLTable + @TAB + 'WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF) ON [PRIMARY];' + @CRLF + @CRLF
-- ADD FOREIGN KEY
--SET @SQLTable = @SQLTable + 'ALTER TABLE [dbo].[' + @HistoryTableName + '] WITH CHECK ADD' + @CRLF
--SET @SQLTable = @SQLTable + @TAB + 'CONSTRAINT [FK_' + @HistoryTableName + '_' + @TableName + ']' + @CRLF
--SET @SQLTable = @SQLTable + @TAB + 'FOREIGN KEY ([' + @TableName + '_ID])' + @CRLF
--SET @SQLTable = @SQLTable + @TAB + 'REFERENCES [dbo].[' + @TableName + '] ([ID])' + @CRLF + @CRLF


PRINT @SQLTable

-- execute sql script to create history table
IF @ExecuteProcedure = 'Y'
	EXEC(@SQLTable)

SET @SQLTrigger = ''

IF @@ERROR <> 0
	BEGIN
		PRINT '******************** ERROR CREATING HISTORY TABLE FOR TABLE: ' + @TableName + ' **************************************'
		RETURN 
	END


IF @CreateTrigger = 'Y'
BEGIN
	-- create history trigger
	SET @SQLTrigger = '/************************************************************************************************************' + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'Created By: ' + SUSER_SNAME() + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'Created On: ' + @Date + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'Comments: Auto generated trigger' + @CRLF
	SET @SQLTrigger = @SQLTrigger + '***********************************************************************************************/' + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'CREATE TRIGGER [' + @TableName + '_UpdateTrigger] ON DBO.' + @TableName + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'AFTER INSERT, DELETE, UPDATE' + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'AS' + @CRLF 
	SET @SQLTrigger = @SQLTrigger + 'BEGIN' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + 'DECLARE @dtNow datetime,' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '        @DCount int,' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '        @ICount int' + @CRLF + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '-- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + 'SET NOCOUNT ON;' + @CRLF + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + 'SELECT @dtNow = GETDATE()' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + 'SELECT @DCount = Count(*) FROM deleted' + @CRLF
  SET @SQLTrigger = @SQLTrigger + @TAB + 'SELECT @ICount = Count(*) FROM inserted' + @CRLF + @CRLF
  SET @SQLTrigger = @SQLTrigger + @TAB + 'INSERT [dbo].[' + @HistoryTableName + ']'+ @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + 'SELECT [Operation] = CASE WHEN @DCount > 0 and @ICount > 0 THEN ''M''' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '            WHEN @ICount > 0 THEN ''A''' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '            ELSE ''D''' + ' END,' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '       [DateOfAction] = @dtNow, I.*' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + 'FROM   inserted AS I' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '       LEFT OUTER JOIN deleted AS D' + @CRLF
	SET @SQLTrigger = @SQLTrigger + @TAB + '                ON I.ID = D.ID' + @CRLF
	SET @SQLTrigger = @SQLTrigger + 'END' + @CRLF + @CRLF + @CRLF
	
	PRINT @SQLTrigger
	
	-- execute sql script to create update/delete trigger
	IF @ExecuteProcedure = 'Y'
		EXEC(@SQLTrigger)

	IF @@ERROR <> 0
		BEGIN
			PRINT '******************** ERROR CREATING HISTORY TRIGGER FOR TABLE: ' + @TableName + ' **************************************'
			RETURN 
		END

END





