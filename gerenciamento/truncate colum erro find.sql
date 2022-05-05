SELECT 
	'NONOO'													IdUO
	, 'NONON DASDAADSADDDD'                           		 Nome
	, 'NONOON SADDS DASDSD '                          		 Endereco
	, '56454'                                       		 IdMunicipio
	, 'RS'                                          		IdUF
	, 'Anchieta'                                    		 Bairro
	, '90200-500'                                   		 Cep
	, '(51) 987654321'                              		 Fone
	, '2'                                           		 IdPredio
	, '1'                                           		 IdUoTipo
	, '20030527'                                    		 Inaugura
	, 'MDASDS ASDSDA DADSAS'                          		 Diretor
	, ''                                            		 IdDiretor
	, 'F'                                           		 Sexo
	, '0'                                           		 IdCivil
	, '00000000000'                                 		 Cpf
	, 'B'                                           		 Nacional
	, '000000000000000'                              		 Cgc
	, '00'                                          		 UOMatriz
	, 'GERÊNCIA DE SAÚDE'                           		 Nomenclatura
	, 1                                             		 NrParcelas
	, 2                                             		 DiaDescFolha
	, '/DD'                                         		 Diretorio
	, 'N'                                           		 ConfirmaMatricula
	, '00000'                                       		 SeqCertificacao
	, 'A'                                           		 Status
	, 10                                            		 NrMesesAtuAluno
	, 'N'                                           		 RecebeAtu
	, 'ASDDAS DAS AS DDDD'                           		 NomeApresentacao
	, 'N'                                           		 ProgramaTurmas
	, '001'                                         		 IdRegiao
	, '99'                                          		 GrupoSeguranca
	, null                                          		 Site
	, '999999'                                      		 IdUsuario2
	, '99'                                          		 IdUoResponsavel
	, 9                                             		 AtivoSite
into #temp;

--select OBJECT_ID('tempdb.dbo.#temp');
--
--select * FROM  tempdb.dbo.#temp;

WITH CTE_Dev
AS (
    SELECT C.column_id
        ,ColumnName = C.NAME
        ,C.max_length
        ,C.user_type_id
        ,C.precision
        ,C.scale
        ,DataTypeName = T.NAME
    FROM sys.columns C
    INNER JOIN sys.types T ON T.user_type_id = C.user_type_id
    WHERE OBJECT_ID = OBJECT_ID('BANCO.dbo.TABELA')
    )
    ,CTE_Temp
AS (
    SELECT C.column_id
        ,ColumnName = C.NAME
        ,C.max_length
        ,C.user_type_id
        ,C.precision
        ,C.scale
        ,DataTypeName = T.NAME
    FROM tempdb.sys.columns C
    INNER JOIN tempdb.sys.types T ON T.user_type_id = C.user_type_id
    WHERE OBJECT_ID = OBJECT_ID('tempdb.dbo.#temp')
    )
SELECT d.column_id,d.columnName,d.DataTypeName,d.max_length tamDestino,t.max_length tamOrigem,*
FROM CTE_Dev D
FULL OUTER JOIN CTE_Temp T ON D.ColumnName collate database_default = T.ColumnName collate database_default
WHERE ISNULL(D.max_length, 0) < ISNULL(T.max_length, 999)



