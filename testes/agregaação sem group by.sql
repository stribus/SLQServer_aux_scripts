SELECT 
	*,
	sum(v.valor) OVER (PARTITION BY v.cor) soma,
	max(v.valor) OVER (PARTITION BY v.cor ) maximo
FROM
(
	VALUES
		(1,'nomoononon',52),
		(2,'Crimson',827),
		(3,'Turquoise',114),
		(4,'Goldenrod',984),
		(5,'Puce',218),
		(6,'Puce',446),
		(7,'Crimson',600),
		(8,'Crimson',446),
		(9,'Red',804)
) v(id,cor,valor)
order by id