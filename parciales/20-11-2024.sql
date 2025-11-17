---------
-- SQL --
---------

/* 1. Consulta SQL para analizar clientes con patrones de compra especificos

Se debe identificar clientes que realizarion una compra inicial y luego volvieron a 
comprar despues de 5 meses o mas 

La consulta debe mostrar 
    - El numero de fila: identificador secuencial del resultado
    - el codigo del cliente id unico del cliente
    - el nombre del cliente: nombre asociado al cliente 
    - cantidad total comprada: total de productos distintos adquiridos por el cliente
    - total facturado: importe total factura al cliente 
El resultado debe estsr ordenado de forma descendente por la cantidad de productos 
adquiridos por cada cliente
*/ 

SELECT clie_codigo,
clie_razon_social,
count(distinct item_producto),
sum(item_cantidad*item_precio)
from Cliente
join Factura f on f.fact_cliente = clie_codigo
join Item_Factura on item_tipo+item_numero+item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
group by clie_codigo, clie_razon_social
HAVING DATEDIFF(MONTH, min(f.fact_fecha), (
                                            select top 1 fact_fecha
                                            from Factura 
                                            where fact_cliente = clie_codigo
                                            group by fact_fecha
                                            having fact_fecha <> (select min(fact_fecha) from Factura where fact_cliente = clie_codigo)
                                            order by fact_fecha ASC
                                           )) >= 5
order by sum(item_cantidad) desc

----------
-- TSQL --
----------
/* 2. Se detectó un error en el proceso de registro de ventas, donde se almacenaron productos compuestos
en lugar de sus componentes individuales. Para solucionar este problema, se debe:

    1. Diseñar e implmenetar los objetos necesarios para reoganizar las ventas tal como están registradas actualmente 
    2. Desagregar los productos compuestos vendidos en sus componenetes individuales, asegurando
    que cada venta refleje correctamente los elementos que la compronen
    3. Garantizar que la base de datos quede consistente y alineada con las especificaciones requeridas para el manejo de poductos
*/
select * from Item_Factura


GO
CREATE PROCEDURE fix_ventas
as
BEGIN
    declare @tipo char(1), @sucursal char(4), @numero char(8), @prod char(8), @cantidad numeric(12,2), @precio numeric(12,2)
    declare curs_compuestos cursor for select item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio from Item_Factura where item_producto in (select comp_producto from Composicion)
    open curs_compuestos 
    fetch curs_compuestos into @tipo, @sucursal, @numero, @prod, @cantidad, @precio
    while @@FETCH_STATUS=0
    BEGIN   
        declare @componente char(8), @comp_cantidad decimal(12,2), @precioItem numeric(12,2)
        declare curs_componentes cursor for select comp_componente, comp_cantidad, prod_precio from Composicion join Producto on prod_codigo = comp_componente where comp_producto = @prod
        open curs_componentes
        fetch curs_componentes into @componente, @comp_cantidad, @precioItem
        WHILE @@FETCH_STATUS=0
        BEGIN
            insert into Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
            VALUES(@tipo, @sucursal, @numero, @componente, @cantidad*@comp_cantidad, @precioItem*@comp_cantidad*@cantidad)
            fetch curs_componentes into @componente, @comp_cantidad
        END
        close curs_componentes
        DEALLOCATE curs_componentes
        delete from Item_Factura where item_producto = @prod and item_tipo+item_numero+item_sucursal = @tipo + @numero + @sucursal
        fetch curs_compuestos into @pk, @prod, @cantidad, @precio
    END
    close curs_compuestos
    DEALLOCATE curs_compuestos
END