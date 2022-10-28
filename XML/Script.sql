-- fonte: http://www.sqlfromhell.com/xquery-lendo-xml-no-sql-server/


DECLARE @XML XML
SET @XML = '
<note>
    <id>1</id>
    <to mail="maria@email.com">maria</to>
    <from mail="ana@email.com">ana</from>
    <heading>Reminder</heading>
    <body>Happy Birthday</body>
    <date>2011-01-01</date>
</note>
<note>
    <id>2</id>
    <to mail="ana@email.com">ana</to>
    <from mail="maria@email.com">maria</from>
    <heading>RE: Reminder</heading>
    <body>Thanks</body>
    <date>2011-01-01</date>
</note>
<note>
    <id>3</id>
    <to mail="maria@email.com">maria</to>
    <from mail="ana@email.com">ana</from>
    <heading>RE: RE: Reminder</heading>
    <body>Party?</body>
    <date>2011-01-02</date>
</note>
'


--1. Recuperando XML de um caminho simples
SELECT @XML.query('note/to')
 
--Resultado:
--<to mail="maria@email.com">maria</to><to mail="ana@email.com">ana</to><to mail="maria@email.com">maria</to>
 
--
 
--2. Recuperando XML de um caminho específico
-- , no caso, o primeiro caso da tag "note"
SELECT @XML.query('note[1]/to')
 
--Resultado:
--<to mail="maria@email.com">maria</to>
 
--
 
--3. Recuperando XML de um caminho específico
-- , onde from possui o texto "maria"
SELECT @XML.query('note[from=''maria'']/to')
 
--Resultado:
--<to mail="ana@email.com">ana</to>
 
--
 
--4. O mesmo caso anterior, especificando o termo "text()"
SELECT @XML.query('note[from/text()=''maria'']/to')
 
--Resultado:
--<to mail="ana@email.com">ana</to>
 
--
 
--5. O mesmo caso anterior, filtrando por um atributo
SELECT @XML.query('note[from/@mail=''maria@email.com'']/to')
 
--Resultado:
--<to mail="ana@email.com">ana</to>



--1. Recuperando o valor de um "id", do tipo INT
SELECT @XML.value('(note/id)[1]', 'int')
 
--Resultado:
--1
 
--
 
--2. Recuperando o valor de um atributo mail, do tipo "varchar"
SELECT @XML.value('(note/to)[1]/@mail', 'varchar(45)')
 
--Resultado:
--maria@email.com
 
--
 
--3. Recuperando o valor de um atributo mail, do tipo "varchar"
SELECT @XML.value('(note[from/@mail=''maria@email.com'']/to)[1]/@mail', 'varchar(45)')
 
--Resultado:
--ana@email.com
 
--
 
--4. Recuperando datas de uma caminho específico
SELECT @XML.value('(note/date)[1]', 'date')
UNION ALL
SELECT @XML.value('(note/date)[3]', 'date')
UNION ALL
SELECT @XML.value('(note/date)[5]', 'date')
 
--Resultado:
--2011-01-01
--2011-01-02
--NULL



--1. Verificando a existência de um caminho específico
SELECT @XML.exist('note/date')
 
--Resultado
--1 (Existe)
 
--
 
--2. Verificando a existência de um caminho específico
SELECT @XML.exist('(note/date)[3]')
 
--Resultado
--1 (Existe)
 
--
 
--3. Verificando a existência de um caminho específico
SELECT @XML.exist('(note/date)[5]')
 
--Resultado
--0 (Não existe)


--1. Consulta simples
SELECT C.query('.')
FROM @XML.nodes('note/to') AS T(C)
 
--Resultado
--<to mail="maria@email.com">maria</to>
--<to mail="ana@email.com">ana</to>
--<to mail="maria@email.com">maria</to>
 
--
 
--2. Consulta com mais critérios
SELECT
 C.value('id[1]', 'int'),
 C.value('date[1]', 'date'),
 C.value('from[1]/@mail', 'varchar(25)'),
 C.query('to')
 
FROM @XML.nodes('note') AS T(C)
 
WHERE C.exist('to') = 1
 
--Resultado
--1 2011-01-01  ana@email.com   <to mail="maria@email.com">maria</to>
--2 2011-01-01  maria@email.com <to mail="ana@email.com">ana</to>
--3 2011-01-02  ana@email.com   <to mail="maria@email.com">maria</to>
…