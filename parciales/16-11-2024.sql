---------
-- SQL --
---------

/* 1. Realizar una consulta SQL que muestre la siguiente informacion para los clientes que hayan
comprado productos en mas de tres rubros diferentes en 2012 y que no compro en años impares   
    - El numero de fila
    - El codigo del cliente 
    - el nombre del cliente
    - la cantidad total comprada por el cliente
    - la categoria en la que más compro en 2012
El resultado debe estar ordenado por la cantidad total comprada de mayor a menor 
*/ 

select clie_codigo,
clie_razon_social,
sum(i.item_cantidad),
(
    select top 1 prod_familia
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    join Producto on item_producto = prod_codigo
    where YEAR(fact_fecha) = 2012
    and fact_cliente = clie_codigo
    group by prod_familia
    order by sum(item_cantidad) desc
)
from Cliente
join Factura f on f.fact_cliente = clie_codigo
join Item_Factura i on i.item_tipo+i.item_numero+i.item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
where year(f.fact_fecha) = 2012
and clie_codigo not in 
(
    select fact_cliente
    from Factura
    where year(fact_fecha) % 2 <> 0
)
and clie_codigo in 
(
    select fact_cliente
    from Factura
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    join Producto on item_producto = prod_codigo
    where year(fact_fecha) = 2012
    group by fact_cliente
    HAVING count(distinct prod_rubro) > 3
)
group by clie_codigo, clie_razon_social
order by sum(item_cantidad) desc

----------
-- TSQL --
----------

/* 2. Implementar los objetos necesarios para registrar, en tiempo real, los 10 productos
mas vendidos por anio en una tabla especifica. Esta tabla debe contener exclusivamente la info requerida
sin incluir filas adicionales. 

Los mas vendidos se define como aquellos productos con el mayor numero de unidades vendidas.
*/

create table mas_vendidos(
    año smalldatetime,
    prod_codigo char(8),
    cantidad_vendida numeric(12,2)
)

GO
CREATE PROCEDURE generar_estadistica @año smalldatetime
as
BEGIN
    insert into mas_vendidos(año, prod_codigo, cantidad_vendida)
    select top 10 @año, prod_codigo, sum(item_cantidad) 
    from Factura 
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    join Producto on prod_codigo = item_producto
    where year(fact_fecha) = @año
    group by item_producto
    order by sum(item_cantidad) desc
END