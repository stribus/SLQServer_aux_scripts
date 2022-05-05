SELECT 
	encrip
	,DecryptByPassphrase('teste teste teste',encrip,1) decr
	,HASHBYTES('SHA2_256','nononononon nonononn noonon')
	,CHECKSUM(*) chs
	,BINARY_CHECKSUM(*) bchs
from 
(
	SELECT 
		EncryptByPassPhrase('teste teste teste',' nononononon nonononn noonon',1) as encrip
) x		
	
	


SELECT *,
	BINARY_CHECKSUM(*) bchsum,
	CHECKSUM(*) ch,
	 CONVERT(NVARCHAR(64),HASHBYTES('MD5',string),2) hs,
	HASHBYTES('SHA1', (select x.* FOR XML RAW)) hash,
	BINARY_CHECKSUM(HASHBYTES('SHA1', (select x.* FOR XML RAW))) hsbchsum
from (
	values
		('Clifton House, Thornaby Place, Teesdale South, Stockton-On-Tees, Cleveland, TS17 6SD')
		,('Clifton House, Teesdale South, Thornaby Place, Stockton-On-Tees, Cleveland, TS17 6SD')
		,('Glenfield Hospital, Groby Road, , Leicester, Leicestershire, LE3 9DZ')
		,('Glenfield Hospital, Groby Road, , Leicester, Leicestershire, LE3 9EJ')
 ) x(string)
