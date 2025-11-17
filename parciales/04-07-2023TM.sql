---------
-- SQL --
---------

/*
0. Realizar una consulta SQL que retorne para los 10 clientes que más compraron en el 2012 y 
que fueron atendidos por más de 3 vendedores distintos:

1. Apellido y Nombre del Cliente. !
2. Cantidad de Productos distintos comprados en el 2012. !
3. Cantidad de unidades compradas dentro del primer semestre del 2012. !

4a. El resultado deberá mostrar ordenado la cantidad de ventas descendente del 2012 de cada cliente, 
4b.	en caso de igualdad de ventas, ordenar por código de cliente.
*/

select top 10
clie_razon_social,
count(distinct i.item_producto),
(
    select count(distinct item_cantidad)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    where MONTH(fact_fecha) BETWEEN 1 and 6
    and fact_cliente = clie_codigo
)
from Cliente
join Factura f on f.fact_cliente = clie_codigo
join Item_Factura i on i.item_tipo+i.item_numero+i.item_sucursal = f.fact_tipo+f.fact_numero+f.fact_sucursal
WHERE year(fact_fecha) = 2012
group by clie_razon_social, f.fact_fecha, clie_codigo
HAVING count(distinct f.fact_vendedor) > 3
order by sum(item_cantidad*item_precio) desc, clie_codigo 

----------
-- TSQL --
----------

/*
Realizar un stored procedure que reciba un código de producto y una
	fecha y devuelva la mayor cantidad de días consecutivos a partir de esa
	fecha que el producto tuvo al menos la venta de una unidad en el día, el
	sistema de ventas on line está habilitado 24-7 por lo que se deben evaluar
	todos los días incluyendo domingos y feriados.
*/

GO
CREATE OR ALTER PROCEDURE contadorDiasConsecutivos @codigo char(8), @fechaInicial smalldatetime, @cantDiasConsecutivos int OUT
AS
BEGIN
    declare @fechaSiguiente smalldatetime, @contador int = 0
    set @cantDiasConsecutivos = @contador
    declare curs_fechas cursor for 
    select fact_fecha 
    from Factura 
    join Item_Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal 
    where item_producto = @codigo 
    and fact_fecha > @fechaInicial
    group by fact_fecha
    order by fact_fecha

    open curs_fechas
    fetch curs_fechas into @fechaSiguiente
    while @@FETCH_STATUS=0
    BEGIN
        if DATEDIFF(DAY, @fechaInicial, @fechaSiguiente) = 1
        BEGIN
            set @contador += 1
        END
        ELSE
        BEGIN
            if(@contador > @cantDiasConsecutivos)
            BEGIN
                set @cantDiasConsecutivos = @contador
                set @contador = 0
            END
        END
        set @fechaInicial = @fechaSiguiente
        fetch curs_fechas into @fechaSiguiente
    END
    IF (@contador > @cantDiasConsecutivos)
    BEGIN
        set @cantDiasConsecutivos = @contador
    END
    close curs_fechas
    DEALLOCATE curs_fechas
    return @cantDiasConsecutivos
END