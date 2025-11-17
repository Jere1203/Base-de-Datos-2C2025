---------
-- SQL --
---------

/* 1. Realizar una consulta que muestre, para los clientes que compraron 
únicamente en años pares, la siguiente información: 
    - El numero de fila
    - el codigo de cliente
    - el nombre del producto más comprado por el cliente
    - la cantidad total comprada por el cliente en el último año

El resultado debe estar ordenado en función de la cantidad máxima comprada por cliente
de mayor a menor    
*/ 

SELECT
f.fact_cliente,
(
    select top 1 prod_detalle
    from Producto
    join Item_Factura on prod_codigo = item_producto
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where fact_cliente = f.fact_cliente
    group by prod_detalle
    order by sum(item_cantidad)
),
(
    select sum(item_cantidad)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
    and fact_cliente = f.fact_cliente
)
from Factura f
join Item_Factura i on i.item_tipo+i.item_numero+i.item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
where year(f.fact_fecha) % 2 = 0
group by f.fact_cliente
order by sum(i.item_cantidad) desc

----------
-- TSQL --
----------

/*
Implementar un sistema de auditoria para registrar cada operacion realizada en la tabla 
cliente. El sistema debera almacenar, como minimo, los valores(campos afectados), el tipo 
de operacion a realizar, y la fecha y hora de ejecucion. SOlo se permitiran operaciones individuales
(no masivas) sobre los registros, pero el intento de realizar operaciones masivas deberá ser registrado
en el sistema de auditoria
*/

--Crearia una tabla AUDITORIA con los valores 
CREATE TABLE AUDITORIA(
    audi_operacion VARCHAR,
    audi_fecha_operacion smalldatetime,
    audi_cliente char(6),
    audi_razon_social char(100),
    audi_telefono char(100),
    audi_domicilio char(100),
    audi_limite_credito decimal(12,2),
    audi_vendedor numeric(6)
)

select * from Cliente


GO
CREATE TRIGGER auditoria on Cliente for INSERT,UPDATE,DELETE
AS
BEGIN
    declare @operacion VARCHAR
    declare @fechaActual smalldatetime = GETDATE()
    if exists (select * from inserted)
    BEGIN
        --En inserted puedo tener una operacion DELETE como UPDATE
        if exists (select * from deleted)
        BEGIN
            select @operacion = 'UPDATE'
            insert into AUDITORIA(
                audi_operacion,
                audi_fecha_operacion,
                audi_cliente,
                audi_razon_social,
                audi_telefono,
                audi_domicilio,
                audi_limite_credito,
                audi_vendedor
            ) select @operacion, @fechaActual, clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor from inserted

            insert into AUDITORIA(
                audi_operacion,
                audi_fecha_operacion, 
                audi_cliente,
                audi_razon_social,
                audi_telefono,
                audi_domicilio,
                audi_limite_credito,
                audi_vendedor
            ) select @operacion, @fechaActual, clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor from deleted
        END

        select @operacion = 'INSERT'
        insert into AUDITORIA(
            audi_operacion,
            audi_fecha_operacion,
            audi_cliente,
            audi_razon_social,
            audi_telefono,
            audi_domicilio,
            audi_limite_credito,
            audi_vendedor
        ) select @operacion, @fechaActual, clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor from inserted
    END
    ELSE
    BEGIN
        select @operacion = 'DELETE'
        insert into AUDITORIA(
            audi_operacion,
            audi_fecha_operacion, 
            audi_cliente,
            audi_razon_social,
            audi_telefono,
            audi_domicilio,
            audi_limite_credito,
            audi_vendedor
        ) select @operacion, @fechaActual, clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor from deleted
    END
END
