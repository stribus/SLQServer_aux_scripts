SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  
GO  
BEGIN
	TRANSACTION;

GO

/*coloque select aquui */


SELECT
	count(1)
FROM
	(
		SELECT
			nome, Endereco, count(DISTINCT PES.id) AS Total
		FROM
			Pessoa PES
		JOIN Email MAI ON
			MAI.Contato_Id = PES.Contato_Id
			AND Ativo = 1
			AND Principal = 1
		GROUP BY
			nome, Endereco
		HAVING
			Count(DISTINCT PES.id) > 1
	) x
GO
ROLLBACK TRANSACTION;

GOSET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  
GO  
BEGIN
	TRANSACTION;

GO

/*coloque select aquui */
SELECT name FROM tempdb.sys.objects WHERE name LIKE N'#TEMP_DADOS_PRODUCAO[_]%';

select * from tempdb.sys.objects

--select COUNT(1) from #TEMP_DADOS_PRODUCAO 
--
--SELECT
--	count(1)
--FROM
--	(
--		SELECT
--			nome, Endereco, count(DISTINCT PES.id) AS Total
--		FROM
--			Pessoa PES
--		JOIN Email MAI ON
--			MAI.Contato_Id = PES.Contato_Id
--			AND Ativo = 1
--			AND Principal = 1
--		GROUP BY
--			nome, Endereco
--		HAVING
--			Count(DISTINCT PES.id) > 1
--	) x
GO
ROLLBACK TRANSACTION;

GO