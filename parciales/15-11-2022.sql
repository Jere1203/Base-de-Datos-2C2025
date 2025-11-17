---------
-- SQL --
---------

/*
0. Realizar una consulta SQL que permita saber 
los clientes que compraron todos los rubros disponibles del sistema en el 2012.

De estos clientes mostrar, siempre para el 2012:
1. El codigo del cliente !
2. Codigo de producto que en cantidades mas compro. !
3. El nombre del producto del punto 2. !
4. Cantidad de productos distintos comprados por el cliente. !
5. Cantidad de productos con composicion comprados por el cliente. !
6a. El resultado debera ser ordenado por razon social del cliente alfabeticamente primero !
6b.	y luego, los clientes que compraron entre un
	20 % y 30% del total facturado en el 2012 primero, luego, los restantes
*/

SELECT clie_codigo,
prod_codigo,
prod_detalle,
(
	select count(distinct item_producto)
	from Item_Factura
	join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
	where fact_cliente = clie_codigo
),
(
	select count(distinct comp_producto)
	from Composicion
	join Item_Factura on item_producto = comp_producto
	join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
	where fact_cliente = clie_codigo
)
from Cliente
join Factura f on f.fact_cliente = clie_codigo
join Item_Factura i on i.item_tipo+i.item_numero+i.item_sucursal = f.fact_tipo+f.fact_numero+f.fact_sucursal
join Producto on prod_codigo = i.item_producto
where prod_codigo = 
(
	select top 1 item_producto
	from Item_Factura
	join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
	where fact_cliente = clie_codigo
	group by item_producto
	order by sum(item_cantidad) desc
)
GROUP by clie_codigo, prod_codigo, prod_detalle, clie_razon_social
order by clie_razon_social, (
								select clie_codigo 
								from Cliente 
								join Factura on fact_cliente = clie_codigo 
								group by clie_codigo
								HAVING sum(fact_total) between 0.20 * (select sum(fact_total) from Factura where year(fact_fecha)=2012) 
								and 0.30*(select sum(fact_total) from Factura where year(fact_fecha)=2012)
							) desc


/*

. Implementar una regla de negocio en línea que al realizar una venta (SOLO INSERCION) permita componer los productos descompuestos,
	es decir, si se guardan en la factura 2 hamb, 2 papas 2 gaseosas se deberá guardar en la factura 2 (DOS) combo1, 
	. Si 1 combo1 equivale a: 1 hamb. 1 papa y 1 gaseosa.

.Nota: Considerar que cada vez que se guardan los items, se mandan todos los productos de ese item a la vez, y no de manera parcial.
*/
GO
CREATE TRIGGER compositor on Item_Factura for INSERT
as
BEGIN	
	declare @prod char(8)
	declare curs_componentes cursor for select item_producto from inserted where item_producto in (select comp_componente from Composicion) 
	open curs_componentes
	fetch curs_componentes into @prod
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--Que es esto meu deus

		fetch curs_componentes into @prod
	END
	close curs_componentes
	DEALLOCATE curs_componentes
END