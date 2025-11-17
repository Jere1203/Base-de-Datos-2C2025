---------
-- SQL --
---------

/*Armar una consulta que muestre para todos los productos:

- Producto

- Detalle del producto

- Detalle composiciOn (si no es compuesto un string SIN COMPOSICION, si es compuesto un string CON COMPOSICION

- Cantidad de Componentes (si no es compuesto, tiene que mostrar 0)

- Cantidad de veces que fue comprado por distintos clientes

Nota: No se permiten sub select en el FROM.*/

select prod_codigo,
prod_detalle,
case when prod_codigo in (select comp_producto from Composicion) then 'CON COMPOSICION' else 'SIN COMPOSICION' end,
case when prod_codigo in (select comp_producto from Composicion) then (select count(comp_componente) from Composicion where comp_producto = prod_codigo) end,
count(distinct fact_cliente)
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
group by prod_codigo, prod_detalle

----------
-- TSQL --
----------

/*Implementar el/los objetos necesarios para implementar la siguiente restriccion en linea:
Cuando se inserta en una venta un COMBO, nunca se debera guardar el producto COMBO, sino, la descomposicion de sus componentes.

Nota: Se sabe que actualmente todos los articulos guardados de ventas estan descompuestos en sus componentes.*/

GO
CREATE TRIGGER control_combos ON Item_Factura FOR INSERT
AS
BEGIN
    declare @producto char(8), @cantidad decimal(12,2), @precio decimal(12,2)
    declare c1 cursor for select i.item_producto, i.item_cantidad, i.item_precio from inserted i where i.item_producto in (select comp_producto from Composicion)
    open c1
    fetch c1 into @producto, @cantidad, @precio
    while @@FETCH_STATUS=0
    BEGIN
        declare @componente char(8), @comp_prod char(8), @comp_cant decimal(12,2)
        declare c2 cursor for select comp_producto, comp_componente, comp_cantidad from Composicion where comp_producto = @producto
        open c2
        fetch c2 into @comp_prod, @componente, @comp_cant
        while @@FETCH_STATUS = 0
        BEGIN
            insert into Item_Factura (item_producto, item_cantidad, item_precio)
            VALUES(@componente, @comp_cant*@cantidad, @precio*@comp_cant)
            fetch c2 into @componente
        END
        delete Item_Factura where item_tipo+item_numero+item_sucursal in (select i.item_tipo+i.item_numero+i.item_sucursal from inserted i) and item_producto = @producto
        fetch c1 into @producto, @cantidad, @precio
    END
    close c1
    DEALLOCATE c1
END 
