---------
-- SQL --
---------

/*
Se solicita un listado con los 5 productos más vendidos y los 5
productos menos vendidos durante el 2012. Comparar la cantidad vendida de
cada uno de estos productos con la cantidad vendida del año anterior e indicar
el string 'Más ventas' o 'Menos ventas', según corresponda. Además indicar el
envase.
A) Producto
B) Comparación año anterior
C) Detalle de Envase
Armar una consulta SQL que retorne esta información.

NOTA: No se permite el uso de sub-selects en el FROM ni funciones definidas
por el usuario para este punto.

NOTA2: Si un producto no tuvo ventas en el año, también debe considerarse
como producto menos vendido. En caso de existir más de 5, solamente mostrar
los 5 primeros en orden alfabético.
*/

SELECT p.prod_codigo,
case 
    when
        (
            (
                select sum(item_cantidad) 
                from Item_Factura 
                join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal 
                where year(fact_fecha) = 2012
                and item_producto = prod_codigo
            ) 
            > 
            (
                select sum(item_cantidad)
                from Item_Factura
                join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
                where year(fact_fecha) = 2011
                and item_producto = prod_codigo
            )
        )
        then 'MAS VENTAS' 
    else 'MENOS VENTAS'
    end,
enva_detalle
from Producto p
join Envases on enva_codigo = p.prod_envase
WHERE p.prod_codigo in 
(
    select top 5 prod_codigo
    from Producto
    join Item_Factura on item_producto = prod_codigo
    join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    group by prod_codigo, prod_detalle
    order by sum(item_cantidad) DESC, prod_detalle
)
group by p.prod_codigo, enva_detalle

UNION

SELECT p.prod_codigo,
case 
    when
        (
            (
                select sum(item_cantidad) 
                from Item_Factura 
                join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal 
                where year(fact_fecha) = 2012
                and item_producto = prod_codigo
            ) 
            > 
            (
                select sum(item_cantidad)
                from Item_Factura
                join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
                where year(fact_fecha) = 2011
                and item_producto = prod_codigo
            )
        )
        then 'MAS VENTAS' 
    else 'MENOS VENTAS'
    end,
enva_detalle
from Producto p
join Envases on enva_codigo = p.prod_envase
WHERE p.prod_codigo in 
(
    select top 5 prod_codigo
    from Producto
    left join Item_Factura on item_producto = prod_codigo
    left join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    group by prod_codigo, prod_detalle
    order by sum(ISNULL(item_cantidad,0)) ASC, prod_detalle
)
group by p.prod_codigo, enva_detalle

----------
-- TSQL --
----------

/*
Se pide crear el/los objetos necesarios para que se imprima un cupón
con la leyenda "Recuerde solicitar su regalo sorpresa en su próxima compra" a
los clientes que, entre los productos comprados, hayan adquirido algún producto
de los siguientes rubros: PILAS y PASTILLAS y tengan un limite crediticio menor
a $ 15000
*/

GO
create TRIGGER impresion_cupon on Item_Factura for insert
as
BEGIN
    if exists 
    (
        select *
        from inserted
        join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
        join Cliente on fact_cliente = clie_codigo
        where item_producto in
        (
            select prod_codigo
            from Producto
            where prod_rubro = 'PILAS'
            or prod_rubro = 'PASTILLAS'
        )
        and clie_limite_credito < 15000
    )
    BEGIN
        PRINT 'Recuerde solicitar su regalo sorpresa en su proxima compra'
    END
END 

select * from Rubro