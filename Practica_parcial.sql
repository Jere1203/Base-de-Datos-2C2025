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

/* 1. Diseñar una consulta SQL que identificque a los vendedores cuya suma de ventas durantes los ultimos dos meses
consecuetivos ha sido inferior a la suma de ventas en los mismos dos meses consecutivos de la años anterior

    - el numero de fila
    - el nombre del vendedor
    - la cantidad de empleados a cargo de cada vendedor
    - la cantidad de clientes a los que vendio en total

El resultado debe estar ordenado en forma descendente segun el monto total de ventas 
del vendedor (de mayor a menor)

*/ 

SELECT e.empl_nombre, 
(
    select count(distinct empl_codigo)
    from Empleado
    where empl_jefe = e.empl_codigo
)'Empleados a cargo',
(
    select count(distinct fact_cliente)
    from Factura
    where fact_vendedor = e.empl_codigo
) 'Cant. clientes'
FROM Factura f
join Empleado e on e.empl_codigo=f.fact_vendedor
where e.empl_codigo in 
(
    select fact_vendedor
    from Factura
    where year(fact_fecha) = (select max(year(fact_fecha)) from factura)
    and 
    (
        (
            select sum(f2.fact_total)
            from Factura f2
            where MONTH(f2.fact_fecha) = MONTH(fact_fecha)-1
        )
        +
        (
            select sum(f2.fact_total)
            from Factura f2
            where MONTH(f2.fact_fecha) = MONTH(fact_fecha)-2
        )
    ) < 
    (
        (
            select sum(f3.fact_total)
            from Factura f3
            where MONTH(f3.fact_fecha) = MONTH(fact_fecha) -1
            and year(f3.fact_fecha) = year(fact_fecha) - 1
        )
        +
        (
            select sum(f3.fact_total)
            from Factura f3
            where MONTH(f3.fact_fecha) = MONTH(fact_fecha)-2
            and YEAR(f3.fact_fecha) = YEAR(fact_fecha)-1
        )
    )
)
group by e.empl_codigo, e.empl_nombre
order by sum(f.fact_total) desc




/* 2. Se requiere diseñar e implemetar los objetos necesarios para crear una regla que detecte inconsistencias en
las ventas en linea. En caso de detectar una incosistencia, deberá registrarse el detalle correspondiente en una estructura
adicional. POr el contrario, si no se encuentra ninguna incosistencia, se deberá registrar que la factura ha sido validada

Inconsistencias a considerar:
    1. Que el valor de fact_total no coincida con la suma de los precios multiplicados por la cantidades que los articulos
    2. Que se genere una factura con una fecha anterior al día actual
    3. Que se intente eliminar algun registro de una venta
*/

create table INCONSISTENCIAS(
    inconsistencias_key char(13),
    inconsistencias_estado VARCHAR
)


go
create trigger detector_inconsistencias on factura after INSERT
as
BEGIN
    declare @fecha smalldatetime, @total decimal(12,2), @tipo char(1), @numero char(8), @sucursal char(4), @sum_total int
    declare curs cursor for select fact_tipo, fact_numero, fact_sucursal, fact_fecha, fact_total from inserted join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    open curs 
    fetch curs into @tipo, @numero, @sucursal, @fecha, @total
    while @@FETCH_STATUS=0
    BEGIN
        select @sum_total=sum(item_precio*item_cantidad) from Item_Factura where item_tipo+item_numero+item_sucursal=@tipo+@numero+@sucursal
        if @total <> @sum_total or DAY(@fecha) = DAY(GETDATE())-1
        BEGIN
            insert into inconsistencias (inconsistencias_key, inconsistencias_estado)
            values (@tipo+@numero+@sucursal, 'INVALIDADO')
        END
        ELSE
        BEGIN
            insert into inconsistencias (inconsistencias_key, inconsistencias_estado)
            VALUES (@tipo+@numero+@sucursal, 'VALIDO')
        END
        FETCH curs into @tipo, @numero, @sucursal, @fecha, @total
    END 
    CLOSE curs
    DEALLOCATE curs
END

go  
create trigger detector_eliminaciones on Item_Factura for DELETE
as
BEGIN
    declare @pk char(13)
    declare curs cursor for select item_tipo+item_numero+item_sucursal from deleted
    open curs
    fetch curs into @pk
    while @@FETCH_STATUS=0
    BEGIN
        insert into inconsistencias (inconsistencias_key, inconsistencias_estado)
        values (@pk, 'INVALIDADO')
    END
END

/* 1. Sabiendo que si un producto no es vendido en un deposito determinado entonces no posee
registros en él.
Se requiere una consulta sql que para todos los productos que se quedaron sin stock en un deposito (cantidad 0 o nula) y
poseen un stock con mayor al punto de reposicion en otro deposito devuelva:

    - Codigo de producto 
    - Detalle de producto 
    - Domicilio del depósito sin stock 
    - Cantidad de depositos con un stock superior al punto de reposicion

La consulta debe ser ordenada por el codigo de producto 
*/ 

SELECT prod_codigo, 
prod_detalle,
d.depo_domicilio,
(
    select count(distinct depo_codigo)
    from DEPOSITO
    join STOCK on stoc_deposito = depo_codigo
    and stoc_producto = prod_codigo
    where stoc_cantidad > stoc_punto_reposicion
)
from Producto
join STOCK s on s.stoc_producto = prod_codigo and s.stoc_cantidad = 0 or s.stoc_cantidad is null
join DEPOSITO d on s.stoc_deposito = d.depo_codigo
where prod_codigo in 
(
    select stoc_producto
    from STOCK
    join DEPOSITO on depo_codigo = stoc_deposito
    where stoc_cantidad > stoc_punto_reposicion
)
group by prod_codigo, prod_detalle, d.depo_domicilio
order by prod_codigo

/* 2. Dado el contexto inflacionario se tieen que aplicar el control en el cual nunca se permita vender un producto
a un precio que no esté entre el 0%-5% del precio de venta del producto el mes anterior, ni tampoco que esté más de un 50%
el precio del mismo producto que hace 12 meses atrás. Aquellos productos nuevos, o que no estuvieron ventas en meses anteriores
no debe considerar esta regla ya que no hay precio de referencia
*/

GO
create trigger ej_inflacion on item_factura for INSERT
as
BEGIN
    if exists (
                select * 
                from inserted i
                join Factura f on i.item_tipo+i.item_numero+i.item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
                where i.item_precio > 0.05*(select item_precio from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where item_producto = i.item_producto and month(fact_fecha) = MONTH(f.fact_fecha)-1)
                and i.item_precio > 0.5*(select item_precio from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where item_producto = i.item_producto and year(fact_fecha) = year(f.fact_fecha)-1)
                and i.item_producto in (select item_producto from Item_Factura join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where month(fact_fecha) < month(f.fact_fecha))
            )
    BEGIN
        RAISERROR('SE ESTA INCUMPLIENDO LA REGLA DE PRECIOS',1,1)
        ROLLBACK
    END
END

-- == SQL == --
/* Dada la crisis que atraviesa la empresa, el directorio solicia un informe especial para poder analizar y definir
la nueva estrategia a adoptar
Este informe consta de un listado de aquellos productos cuyas ventas de lo que va del año 2012 fueron superiores
al 15% del promedio de ventas de los productos vendidos entre los años 2010 y 2011
En base a lo solicitado, armar una consulta SQL que retorne la siguiente informacion:

1) Detalle producto 
2) Mostrar la leyenda "Popular" si dicho producto figura en más de 100 facturas realizadas en el 2012. Caso contrario, mostrar la leyenda "SIN INTERES"
3) Cantidad de facturas en las que aparece el producto en el año 2012
4) Codigo del cliente que más compro dicho producto en el año 2012 (en caso de existi más de un cliente mostrar solamente el de menor codigo)*/

select p.prod_detalle,
case when count(distinct f.fact_tipo+f.fact_numero+f.fact_sucursal) > 100 then 'POPULAR' else 'SIN INTERES' end,
count(distinct fact_tipo+fact_numero+fact_sucursal) 'Cant. facturas',
(
    select top 1 clie_codigo
    from Cliente
    join Factura on fact_cliente = clie_codigo
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where item_producto = p.prod_codigo
    group by clie_codigo
    order by sum(item_cantidad) desc, clie_codigo asc
) 'Cliente que más compró'
from Producto p
join Item_Factura i on i.item_producto=prod_codigo
join Factura f on i.item_tipo+i.item_numero+i.item_sucursal = f.fact_tipo+f.fact_numero+f.fact_sucursal
where year(f.fact_fecha) = 2012
and i.item_producto in 
(
    select item_producto
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = 2012
    group by item_producto
    having sum(item_precio*item_cantidad) > (0.15*(
    (
        select sum(item_cantidad*item_precio)
        from Factura 
        join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
        where year(fact_fecha) = 2011
    ) + 
    (
        select sum(item_cantidad*item_precio)
        from Factura 
        join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
        where year(fact_fecha) = 2010
    ))/2)
)
group by p.prod_detalle, p.prod_codigo

-- == TSQL == --
/*
Realizar el o los objetos de base de datos necesarios para que dado un codigo de producto y una fecha devuelva
la mayor cantidad de dias consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el dia, 
el sistema de ventas on line esta habilitado 24-7 por lo que se deben evaluar tidos los dias incluyendo domingos y feriados
*/

GO
create function diasConsecutivos (@codigo char(8), @fecha smalldatetime)
returns int
as
BEGIN
    declare @maxFechas int, @nuevaFecha smalldatetime, @cantFechas int
    declare c1 cursor for select fact_fecha 
                            from Factura 
                            join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal 
                            where item_producto = @codigo 
                            and fact_fecha = @fecha
                            group by fact_fecha
                            order by fact_fecha
    open c1
    FETCH c1 into @nuevaFecha
    while @@FETCH_STATUS=0
    BEGIN
        select @fecha = @nuevaFecha
        select @maxFechas = 0
        WHILE @@FETCH_STATUS=0 and @fecha + 1 = @nuevaFecha
        BEGIN
            select @cantFechas += 1
            fetch c1 into @nuevaFecha
        END
        if @cantFechas > @maxFechas
        BEGIN
            select @maxFechas = @cantFechas
        END
        if @cantFechas = 0
        BEGIN
            fetch c1 into @nuevaFecha
        END
    END
    close c1
    DEALLOCATE c1
END

-- ==SQL==

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

SELECT prod_codigo,
prod_detalle,
(
    select sum(item_cantidad)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = 2012
    and item_producto in (select comp_componente from Composicion where comp_producto = prod_codigo)
),
(select sum(item_cantidad*item_precio) from Item_Factura where item_producto = prod_codigo)
from Producto
where prod_codigo in
(
    select prod_codigo
    from Producto
    join Composicion on comp_producto = prod_codigo
    GROUP by prod_codigo
    having count(distinct prod_rubro) > 2
    and count(comp_componente) = 3
)
group by prod_codigo, prod_detalle
order by (select count(distinct fact_numero) from Factura join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal where YEAR(fact_fecha) = 2012 and item_producto = prod_codigo)

-- ==T-SQL==
/*
1. Implementar una regla de negocio en linea donde se valide que nuncа
un producto compuesto pueda estar compuesto por componentes de rubros distintos a el.
*/

GO
create trigger validar_rubros on Composicion for INSERT
as
BEGIN 
    if exists 
    (
        select *
        from inserted i
        join Producto p1 on p1.prod_codigo = i.comp_producto
        join Producto p2 on p2.prod_codigo = i.comp_componente
        where p1.prod_rubro <> p2.prod_rubro
    )
    BEGIN
        ROLLBACK
    END
END 


-- ========== SQL ========== --

/* 1. Consulta SQL para analizar clientes con patrones de cmpra especificos

Se debe identificar clientes que realizarion una compra inicial y luego volvieron a 
comprar despues de 5 meses o más 

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
count(distinct item_producto) 'Cantidad comprada',
sum(item_cantidad*item_precio) 'Total facturado'
from Cliente
join Factura on fact_cliente = clie_codigo
join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
group by clie_codigo, clie_razon_social
having DATEDIFF(MONTH,min(fact_fecha),max(fact_fecha))>=5
order by count(distinct item_producto) desc

-- ========== T-SQL ========== --

/* 2. Se detectó un error en el proceso de registro de ventas, donde se almacenaron productos compuestos
en lugar de sus componentes individuales. Para solucionar este problema, se debe:

    1. Diseñar e implmenetar los objetos necesarios para reoganizar las ventas tal como están registradas actualmente 
    2. Desagregar los productos compuestos vendidos en sus componenetes individuales, asegurando
    que cada venta refleje correctamente los elementos que la compronen
    3. Garantizar que la base de datos quede consistente y alineada con las especificaciones requeridas para el manejo de poductos
*/
