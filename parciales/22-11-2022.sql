---------
-- SQL --
---------

/*
Realizar una consulta SQL que muestre aquellos productos que tengan
3 componentes a nivel producto y cuyos componentes tengan 2 rubros
distintos.
De estos productos mostrar:
    i) El código de producto.
    ii) El nombre del producto.
    iii) La cantidad de veces que fueron vendidos sus componentes en el 2012.
    iv) Monto total vendido del producto.

El resultado deberá ser ordenado por cantidad de facturas del 2012 en
las cuales se vendieron los componentes.
Nota: No se permiten select en el from, es decir, select... from (select ...) as T....
*/

SELECT p.prod_codigo,
p.prod_detalle,
(
    select sum(item_cantidad)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = 2012
    and item_producto in (select comp_componente from Composicion where comp_producto = prod_codigo)
),
sum(i.item_cantidad*i.item_precio)
from Producto p
join Item_Factura i on i.item_producto = p.prod_codigo
join Factura f on i.item_tipo+i.item_numero+i.item_sucursal = f.fact_tipo+f.fact_numero+f.fact_sucursal
where p.prod_codigo in
(
    select comp_producto
    from Composicion
    join Producto on comp_componente = prod_codigo
    group by comp_producto
    having count(distinct comp_componente) = 3 and count(distinct prod_rubro) = 2
)
and year(f.fact_fecha) = 2012
group by p.prod_codigo, p.prod_detalle
order by count(distinct f.fact_numero) desc

----------
-- TSQL --
----------

/*
Implementar una regla de negocio en linea donde se valide que nuncа
un producto compuesto pueda estar compuesto por componentes de rubros distintos a el.
*/

GO
CREATE TRIGGER validar_composicion on Composicion for insert
as
BEGIN
    if exists 
    (
        select *
        from inserted
        join Producto p1 on p1.prod_codigo = comp_producto
        join Producto p2 on p2.prod_codigo = comp_componente
        where p1.prod_rubro <> p2.prod_rubro
    )
    BEGIN
        ROLLBACK
    END
END