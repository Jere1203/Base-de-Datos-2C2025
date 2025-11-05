/* 1. Realizar una consulta SQL que retorne para el último año, los 5 vendedores con menos clientes asignados, 
que más vendieron en pesos (si hay varios con menos clientes asignados debe traer el que más vendió), solo deben 
considerarse las facturas que tengan más de dos ítems facturados:

1)	Apellido y Nombre  del Vendedor.
2)	Total de unidades de Producto Vendidas.
3)	Monto promedio de venta por factura.
4)	Monto total de ventas.

El resultado deberá mostrar ordenado la cantidad de ventas descendente, en caso de igualdad de cantidades, 
ordenar por código de vendedor.
NOTA: No se permite el uso de sub-selects en el FROM. */

select fact_vendedor, sum(item_cantidad), avg(fact_total), sum(item_cantidad*item_precio)
from Factura join Item_Factura on item_sucursal+item_tipo+item_numero=fact_sucursal+fact_tipo+fact_numero
where fact_vendedor in 
                        (
                            select top 5 f.fact_vendedor
                            from Factura f
                            group by f.fact_vendedor
                            order by count(distinct f.fact_cliente) asc
                        )
group by fact_vendedor
having count(item_cantidad) > 2
order by count(fact_numero) desc

-- Creo que esta es la que va
select top 5 empl_nombre, empl_apellido, avg(fact_total), sum(item_cantidad*item_precio)
from Empleado join Factura on fact_vendedor = empl_codigo and year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
join Item_Factura on fact_tipo+fact_numero+fact_sucursal=item_tipo+item_numero+item_sucursal
where fact_numero in 
(
    select fact_numero
    from Factura
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    group by fact_numero
    having count(*) > 2
)
group by empl_nombre, empl_apellido, empl_codigo
order by (select count(*) from Cliente where clie_vendedor = empl_codigo) ASC, count(fact_numero) desc, empl_codigo



/* 2. Dado el contexto inflacionario se tiene que aplicar un control en el cual nunca se permita vender un producto a un 
precio que no esté entre 0%-5% del precio de venta del producto el mes anterior, ni tampoco que esté en más de un 50% el 
precio del mismo producto que hace 12 meses atrás. Aquellos productos nuevos, o que no tuvieron ventas en meses anteriores 
no debe considerar esta regla ya que no hay precio de referencia. */
GO
create trigger ej_parcial on Item_Factura for INSERT
as
BEGIN
    declare @prod char(8), @prec decimal(12,2)
    declare c_vendidos cursor for (select i.item_producto, i.item_precio from inserted i where i.item_producto not in (select item_producto from Item_Factura))
    open c_vendidos
    fetch c_vendidos into @prod
    while @@FETCH_STATUS = 0
    BEGIN
        IF (@prec - (select item_precio from Item_Factura join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero where item_producto = @prod and MONTH(fact_fecha) = month(fact_fecha)-1))*100 BETWEEN 0 and 5
        BEGIN
            IF (@prec - (select item_precio from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where item_producto=@prod and year(fact_fecha)=YEAR(fact_fecha)-1))*100 > 50
            BEGIN
                PRINT 'No se puede vender a este precio'
            END
        END
    END
END


GO
create function noSePuedeVender (@precio decimal(12,2), @producto char(8))
returns INT
BEGIN
    declare @precioMesAnterior decimal(12,2), @precioAnioPasado decimal(12,2)
    set @precioMesAnterior = (select item_precio from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where month(fact_fecha) = month(fact_fecha)-1 and item_producto = @producto)
    set @precioAnioPasado = (select item_precio from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where year(fact_fecha) = year(fact_fecha)-1 and item_producto = @producto)
    IF ABS(@precio - @precioAnioPasado) > 0.5*@precioAnioPasado or ABS(@precio - @precioMesAnterior) BETWEEN 0.05*@precioMesAnterior and 0
    BEGIN
        return 1
    END
    return 0
END


GO
create trigger ej_parcialv2 on Item_factura for INSERT
as
BEGIN
    IF (select count(*) 
        from inserted i 
        join Factura on i.item_tipo+i.item_numero+i.item_sucursal=fact_tipo+fact_numero+fact_sucursal
        where i.item_producto in (
            select item_producto
            from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
            where year(fact_fecha) = year(fact_fecha)-1
        )
        and i.item_producto in (
            select item_producto
            from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
            where month(fact_fecha) = month(fact_fecha)-1
        ))>0
    BEGIN
        IF (select count(*) from inserted i join Factura on i.item_tipo+i.item_numero+i.item_sucursal=fact_tipo+fact_numero+fact_sucursal
            where dbo.noSePuedeVender(i.item_precio, i.item_producto)=1) > 0
            BEGIN
                RAISERROR('No cumple la conidicion',1,1)
                ROLLBACK
            END
    END
END

-- === Clase 4/11 ===

/* 1.	Mostrar dos filas con los 2  empleados del mes: Estos son:

a)	El empleado que en el último año que haya ventas (en el cual se ejecuta la query) vendió 
más en dinero (fact_total)
b)	El segundo empleado del año, es aquel que en el mismo año (en el cual se ejecuta la query)
 tiene más facturas emitidas

Se deberá mostrar Apellido y nombre del empleado en una sola columna y para el primero
 un string que diga 
(Mejor Facturación y para el Segundo Vendió Más Facturas).

No se permiten sub select en el FROM.*/

SELECT top 1 rtrim(empl_nombre)+' '+RTRIM(empl_apellido) 'nombre y apellido', 'Mejor facturación'
from Empleado 
where empl_codigo in
(
    select top 1 empl_codigo
    from Empleado
    join Factura on fact_vendedor = empl_codigo and year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
    group by empl_codigo
    order by sum(fact_total) desc
)

UNION

select top 1 rtrim(empl_nombre)+' '+RTRIM(empl_apellido) 'nombre y apellido', 'Vendió más facturas'
from Empleado
where empl_codigo in
(
    select top 1 fact_vendedor
    from Factura where year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
    group by fact_vendedor
    order by count(*) desc
)

/* 2.	Realizar un stored procedure que reciba un código de producto y una fecha y devuelva la mayor cantidad de días 
consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el día, el sistema de ventas 
on line está habilitado 24-7 por lo que se deben evaluar todos los días incluyendo domingos y feriados*/

go
create or alter PROCEDURE ej_4nov @codigo char(8), @fecha smalldatetime, @maxDias int OUTPUT
as
BEGIN
    declare @producto char(8), @fechaSiguiente smalldatetime, @fecha_actual smalldatetime, @cantDias int
    declare c1 cursor for 
                           SELECT fact_fecha
                           from Factura
                           join Item_Factura on fact_tipo+fact_numero+fact_sucursal=item_tipo+item_numero+item_sucursal
                           where item_producto=@producto
                           group by fact_fecha
                           order by fact_fecha
    open c1
    FETCH c1 into @fecha_actual
    select @fechaSiguiente = @fecha
    WHILE @@FETCH_STATUS = 0
    BEGIN
        select @fecha = @fecha_actual
        select @cantDias = 0
        while @@FETCH_STATUS = 0 and @fecha + 1 = @fecha_actual
        BEGIN
            SELECT @cantDias = @cantDias+1
            FETCH c1 into @fecha_actual
        END
        if (@cantDias > @maxDias)
            select @maxDias=@cantDias
        if @cantDias=0
            fetch c1 into @fecha_actual
    END
    close c1
    DEALLOCATE c1
END

/* Sabiendo que si un producto no es vendido en un deposito determinado entonces no posee registros en el 
Se requiere una consulta SQL que para todos los productos que se quedaron sin stock en un deposito (cantidad 0 o nula) y
poseen un stock mayor al punto de resposicion en otro deposito devuelva:

1 - codigo de producto
2 - detalle de producto
3 - domicilio del deposito sin stock
4 - cantidad de depositos con un stock superior al punto de reposicion

la consulta debe ser ordenada por el codigo de producto.
*/

select prod_codigo, prod_detalle, depo_domicilio, count(*)
from Producto
join STOCK s1 on s1.stoc_producto = prod_codigo
join DEPOSITO on stoc_deposito = depo_codigo
join STOCK s2 on s2.stoc_producto = prod_codigo
where s1.stoc_cantidad = 0 or s1.stoc_cantidad is null and s2.stoc_cantidad > s2.stoc_punto_reposicion
group by prod_codigo, prod_detalle, depo_domicilio
order by 1