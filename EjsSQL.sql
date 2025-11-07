/*
1. Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea mayor o
igual a $ 1000 ordenado por código de cliente.
*/

SELECT clie_codigo, clie_razon_social
FROM Cliente
WHERE clie_limite_credito >= 1000
ORDER BY clie_codigo

/*
2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados por
cantidad vendida.
*/

SELECT prod_codigo, prod_detalle
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE year(fact_fecha) = '2012'
ORDER BY item_cantidad

/*
3. Realizar una consulta que muestre código de producto, nombre de producto y el stock
total, sin importar en que deposito se encuentre, los datos deben ser ordenados por
nombre del artículo de menor a mayor.
*/
SELECT prod_codigo, prod_detalle, SUM(ISNULL(stoc_cantidad,0))
FROM Producto LEFT JOIN STOCK ON prod_codigo = stoc_producto
GROUP BY prod_codigo, prod_detalle
ORDER BY prod_detalle ASC

/*
4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de
artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock
promedio por depósito sea mayor a 100.
*/
SELECT prod_codigo, prod_detalle
FROM Producto LEFT JOIN Composicion ON prod_codigo = comp_producto
WHERE prod_codigo IN (
    SELECT stoc_producto
    FROM STOCK
    GROUP BY stoc_producto
    HAVING AVG(stoc_cantidad) > 100
)
GROUP BY prod_codigo, prod_detalle

/*
5. Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos de
stock que se realizaron para ese artículo en el año 2012 (egresan los productos que
fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el 2011.
*/
SELECT prod_codigo, prod_detalle
FROM Producto LEFT JOIN Item_Factura on prod_codigo = item_producto JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE year(fact_fecha) = '2012'
GROUP BY prod_codigo, prod_detalle
HAVING SUM(item_cantidad) > (
    SELECT SUM(item_cantidad)
    FROM Item_Factura LEFT JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
    WHERE year(fact_fecha) = '2011'
    and item_producto = prod_codigo
)

/*
6. Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de ese
rubro y stock total de ese rubro de artículos. Solo tener en cuenta aquellos artículos que
tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’.
*/
SELECT rubr_id, rubr_detalle, COUNT(distinct stoc_producto) stockArticulo, sum(isnull(stoc_cantidad,0)) stockRubro
FROM Rubro LEFT JOIN Producto on prod_rubro = rubr_id and prod_codigo IN (
    SELECT stoc_producto
    FROM STOCK
    GROUP BY stoc_producto
    HAVING SUM(stoc_cantidad) > (
        select stoc_cantidad
        from STOCK
        WHERE stoc_deposito = '00' and stoc_producto = '00000000'
    )
    
) LEFT JOIN STOCK on stoc_producto = prod_codigo
GROUP BY rubr_id, rubr_detalle
ORDER BY rubr_id ASC

/*
7. Generar una consulta que muestre para cada artículo código, detalle, mayor precio
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio =
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean
stock.
*/

SELECT prod_codigo, prod_detalle, MAX(item_precio) precioMaximo, MIN(item_precio) precioMinimo,
CONVERT(NUMERIC(5,2), (MAX(item_precio)-MIN(item_precio))/MIN(item_precio)*100) porcentajeDiferencia
FROM Producto JOIN Item_Factura on item_producto = prod_codigo
WHERE prod_codigo in (select stoc_producto from STOCK)
GROUP BY prod_codigo, prod_detalle


/*
8. Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del
artículo, stock del depósito que más stock tiene.
*/

SELECT prod_detalle, MAX(stoc_cantidad) maxCantidadStock
FROM Producto join STOCK on prod_codigo = stoc_producto
GROUP BY prod_detalle
HAVING COUNT(*) = (SELECT COUNT(*) FROM DEPOSITO)

/*
9. Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del
mismo y la cantidad de depósitos que ambos tienen asignados.
*/

select empl_jefe, empl_codigo, RTRIM(empl_apellido)+ ' '+RTRIM(empl_nombre), count(*)
from Empleado join DEPOSITO on depo_encargado = empl_codigo or depo_encargado = empl_jefe
GROUP by empl_codigo, empl_jefe, empl_apellido, empl_nombre

/*
10. Mostrar los 10 productos más vendidos en la historia y también los 10 productos menos
vendidos en la historia. Además mostrar de esos productos, quien fue el cliente que
mayor compra realizo.
*/

select prod_codigo, prod_detalle,
            (select TOP 1 f1.fact_cliente from Item_Factura i1 join Factura f1 on (f1.fact_tipo+f1.fact_sucursal+f1.fact_numero = i1.item_tipo+i1.item_sucursal+i1.item_numero)
             where i1.item_producto = prod_codigo
             group by f1.fact_cliente
             order by SUM(i1.item_cantidad) desc
            ) CLIENTE_QUE_MAS_COMPRO
from Producto
where prod_codigo in (SELECT TOP 10 item_producto
    from Producto join Item_Factura on (item_producto = prod_codigo)
    group by item_producto
    order by SUM(item_cantidad) asc)
OR prod_codigo in (select top 10 item_producto from Producto join Item_Factura on item_producto = prod_codigo
                    group by item_producto
                    order by sum(item_cantidad) desc)
group by prod_codigo, prod_detalle

/*
11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán
ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga,
solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para
el año 2012.
*/

SELECT fami_detalle, count(distinct item_producto), sum(item_precio* item_cantidad)
from Familia join Producto on prod_familia = fami_id join Item_Factura on item_producto = prod_codigo
where (select sum(item_cantidad * item_precio) 
       from Item_Factura join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
       join Producto on item_producto = prod_codigo
       where prod_familia = fami_id and year(fact_fecha) = '2012') > 20000
group by fami_detalle
order by 2 desc

/*
12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron, importe
promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del
producto y stock actual del producto en todos los depósitos. Se deberán mostrar
aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán
ordenarse de mayor a menor por monto vendido del producto.
*/

SELECT prod_detalle, count(distinct fact_cliente) cantidadClientesQueCompraron, AVG(item_precio) precioPromedio,
(SELECT count(stoc_deposito) FROM STOCK WHERE stoc_producto = prod_codigo),
(SELECT sum(stoc_cantidad) FROM STOCK WHERE stoc_producto = prod_codigo)
FROM Producto join Item_Factura ON item_producto = prod_codigo join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
WHERE prod_codigo in (
                      SELECT distinct item_producto 
                      FROM Item_Factura
                      JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero 
                      WHERE year(fact_fecha) = 2012 
                    )
GROUP BY prod_detalle, prod_codigo
ORDER BY sum(item_cantidad * item_precio) DESC

/*
13. Realizar una consulta que retorne para cada producto que posea composición nombre
del producto, precio del producto, precio de la sumatoria de los precios por la cantidad 
de los productos que lo componen. Solo se deberán mostrar los productos que estén
compuestos por más de 2 productos y deben ser ordenados de mayor a menor por
cantidad de productos que lo componen.
*/

SELECT p2.prod_detalle, p2.prod_precio, sum(p1.prod_precio*comp_cantidad), comp_producto
FROM Composicion JOIN Producto p1 ON p1.prod_codigo = comp_componente 
                 JOIN Producto p2 ON p2.prod_codigo = comp_producto
GROUP BY p2.prod_detalle, p2.prod_precio, comp_producto
HAVING count(*) >= 2
ORDER BY count(*) DESC

/*
14. Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que
debe retornar son:
[x] Código del cliente
[x] Cantidad de veces que compro en el último año
[x] Promedio por compra en el último año
[x] Cantidad de productos diferentes que compro en el último año
[x] Monto de la mayor compra que realizo en el último año

Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en
el último año.
No se deberán visualizar NULLs en ninguna columna
*/

select clie_codigo, count(fact_cliente) cantidadCompras, isnull(avg(fact_total),0) promedioCompras, isnull(max(fact_total),0),
    (select count(distinct item_producto)
     from Item_Factura join Factura on item_numero+item_sucursal+item_tipo = fact_numero+fact_sucursal+fact_tipo
     where year(fact_fecha) = (select MAX(YEAR(fact_fecha)) from Factura) and fact_cliente = clie_codigo
     ) cantidadProductosDistintosEnElAnio, 
isnull(max(fact_total),0)

from Cliente left join Factura on fact_cliente = clie_codigo AND year(fact_fecha) = (select MAX(YEAR(fact_fecha)) from Factura)
group by clie_codigo
order by cantidadCompras desc

/*
15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos
(en la misma factura) más de 500 veces. El resultado debe mostrar el código y
descripción de cada uno de los productos y la cantidad de veces que fueron vendidos
juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron
juntos dichos productos. Los distintos pares no deben retornarse más de una vez.

Ejemplo de lo que retornaría la consulta:
PROD1 DETALLE1 PROD2 DETALLE2 VECES
1731 MARLBORO KS 1718 PHILIPS MORRIS KS 507
1718 PHILIPS MORRIS KS 1705 PHILIPS MORRIS BOX 10 562
*/

SELECT p1.prod_codigo PROD1, p1.prod_detalle DETALLE1, p2.prod_codigo PROD2, p2.prod_detalle DETALLE2, count(*) VECES
FROM Producto p1 JOIN Item_Factura i1 ON p1.prod_codigo = i1.item_producto 
JOIN Item_Factura i2 ON i2.item_tipo+i2.item_sucursal+i2.item_numero = i1.item_tipo+i1.item_sucursal+i1.item_numero
JOIN Producto p2 ON i2.item_producto = p2.prod_codigo
WHERE p1.prod_codigo >p2.prod_codigo
GROUP BY p2.prod_codigo, p2.prod_detalle, p1.prod_codigo, p1.prod_detalle
HAVING count(*) > 500
ORDER BY VECES ASC

/*
16. Con el fin de lanzar una nueva campaña comercial para los clientes que menos compran
en la empresa, se pide una consulta SQL que retorne aquellos clientes cuyas compras
son inferiores a 1/3 del monto de ventas del producto que más se vendió en el 2012.
Además mostrar
1. Nombre del Cliente
2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1,
mostrar solamente el de menor código) para ese cliente.
*/

select clie_razon_social, sum(item_cantidad), 
    (select top 1 item_producto
    from Factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
    where fact_cliente = clie_codigo and year(fact_fecha) = 2012 
    GROUP by item_producto
    order by sum(item_cantidad) desc
    )
from Cliente join Factura on fact_cliente = clie_codigo join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero and year(fact_fecha) = 2012
group by clie_codigo, clie_razon_social
having (select sum(fact_total) from Factura where fact_cliente = clie_codigo and year(fact_fecha) = 2012) < ((select top 1 sum(item_cantidad*item_precio) 
                                                                                  from Item_Factura join Factura on fact_tipo+fact_numero+fact_sucursal = item_tipo+item_numero+item_sucursal 
                                                                                  where year(fact_fecha) = 2012 
                                                                                  group by item_producto 
                                                                                  order by sum(item_cantidad) desc)
                                                                                  /3)

/*
17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada
producto.
La consulta debe retornar:

PERIODO: Año y mes de la estadística con el formato YYYYMM

PROD: Código de producto

DETALLE: Detalle del producto

CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo

VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo
pero del año anterior

CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el
periodo

La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
por periodo y código de producto.
*/

-- (select count(*) from Factura f2 where year(f1.fact_fecha) = year(f2.fact_fecha) and month(f1.fact_fecha) = MONTH(f2.fact_fecha)) 'Cantidad vendida en el periodo',
SELECT str(year(fact_fecha),4) +' ' + str(MONTH(fact_fecha),2) 'Periodo', prod_codigo, prod_detalle,
sum(item_cantidad)'Unidades vendidas en el periodo',
    isnull((
        select sum(item_cantidad)
        from Item_Factura join Factura f2 on item_numero + item_sucursal + item_tipo = f2.fact_numero + f2.fact_sucursal + f2.fact_tipo where year(f1.fact_fecha)-1 = year(f2.fact_fecha) and month(f1.fact_fecha) = month(f2.fact_fecha)
    ),0) 'Vendidas en periodo anterior',
count(fact_numero) 'Cantidad de facturas'
from Producto join Item_Factura on item_producto = prod_codigo join Factura f1 on f1.fact_tipo + f1.fact_sucursal + f1.fact_numero = item_tipo + item_sucursal + item_numero
group by fact_fecha, prod_codigo, prod_detalle
order by Periodo, prod_codigo


-- 18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
-- La consulta debe retornar:
-- DETALLE_RUBRO: Detalle del rubro
-- VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
-- PROD1: Código del producto más vendido de dicho rubro
-- PROD2: Código del segundo producto más vendido de dicho rubro
-- CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30
-- días
-- La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
-- por cantidad de productos diferentes vendidos del rubro.

SELECT rubr_detalle, isnull(sum(item_cantidad*item_precio), 0) 'VENTAS EN PESOS', 
isnull((
    select top 1 prod_codigo 
    from Producto 
    join Item_Factura on item_producto = prod_codigo 
    where prod_rubro = rubr_id
    group by prod_codigo
    order by sum(item_cantidad) DESC
),0)'PROD1',
isnull((
    select top 1 prod_codigo 
    from Producto 
    join Item_Factura on item_producto = prod_codigo and prod_rubro = rubr_id
    where prod_codigo in (
                                select top 2 prod_codigo
                                from Producto 
                                join Item_Factura on item_producto = prod_codigo and prod_rubro = rubr_id
                                group by prod_codigo
                                order by sum(item_cantidad) desc
                             )
    group by prod_codigo
    order by sum(item_cantidad) ASC
),0) 'PROD2',
isnull((
    select top 1 fact_cliente 
    from Factura join Item_Factura on item_numero+item_tipo+item_sucursal = fact_numero+fact_tipo+fact_sucursal and fact_fecha >= (select max(fact_fecha) - 30 from Factura)
    join Producto on item_producto = prod_codigo and prod_rubro = rubr_id
    group by fact_cliente
    order by sum(item_cantidad) desc
),0) 'CLIENTE'
FROM Rubro join Producto on prod_rubro = rubr_id left join Item_Factura on item_producto = prod_codigo
group by rubr_detalle, rubr_id
order by count(distinct prod_codigo) DESC

-- 19. En virtud de una recategorizacion de productos referida a la familia de los mismos se
-- solicita que desarrolle una consulta sql que retorne para todos los productos:
--  Codigo de producto
--  Detalle del producto
--  Codigo de la familia del producto
--  Detalle de la familia actual del producto
--  Codigo de la familia sugerido para el producto
--  Detalle de la familia sugerido para el producto

-- La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo
-- detalle coinciden en los primeros 5 caracteres.

-- En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor
-- codigo. Solo se deben mostrar los productos para los cuales la familia actual sea
-- diferente a la sugerida
-- Los resultados deben ser ordenados pr detalle de producto de manera ascendente

SELECT p1.prod_codigo, p1.prod_detalle, p1.prod_familia, fami_detalle,
(
    select top 1 p2.prod_familia
    from Producto p2
    where left(p2.prod_detalle, 5) = LEFT(p1.prod_detalle, 5)
    group by p2.prod_familia
    order by count(*) desc
) 'Familia sugerida',
(
    select top 1 f2.fami_detalle
    from Producto p2
    join Familia f2 on f2.fami_id = p2.prod_familia
    where left(p2.prod_detalle, 5) = LEFT(p1.prod_detalle, 5)
    group by f2.fami_detalle
    order by count(*) desc
) 'Detalle Flia. sugerida'
FROM Producto p1 JOIN Familia ON fami_id = prod_familia
group by prod_codigo, prod_detalle, prod_familia, fami_detalle
having p1.prod_familia <> 
                        (    
                            select top 1 p2.prod_familia
                            from Producto p2
                            where left(p2.prod_detalle, 5) = LEFT(p1.prod_detalle, 5)
                            group by p2.prod_familia
                            order by count(*) desc
                        )
order by p1.prod_detalle asc

-- 20. Escriba una consulta sql que retorne un ranking de los mejores 3 empleados del 2012
-- Se debera retornar legajo, nombre y apellido, anio de ingreso, puntaje 2011, puntaje
-- 2012. El puntaje de cada empleado se calculara de la siguiente manera: para los que
-- hayan vendido al menos 50 facturas el puntaje se calculara como la cantidad de facturas
-- que superen los 100 pesos que haya vendido en el año, para los que tengan menos de 50
-- facturas en el año el calculo del puntaje sera el 50% de cantidad de facturas realizadas
-- por sus subordinados directos en dicho año.

select empl_codigo, empl_nombre, empl_apellido, year(empl_ingreso)'INGRESO',
(
    select
    CASE WHEN count(distinct fact_numero) >= 50
    THEN (select count(*) from Factura where fact_vendedor = empl_codigo and year(fact_fecha) = 2011 and fact_total > 100)
    ELSE (select count(*)/2 from Factura join Empleado e2 on fact_vendedor = e2.empl_codigo and e2.empl_jefe = empl_codigo and YEAR(fact_fecha) = 2011 group by fact_vendedor)
    END
    from Factura
    where fact_vendedor = empl_codigo
    group by fact_vendedor
) 'Puntaje 2011',
(
    select
    CASE WHEN count(distinct fact_numero) >= 50
    THEN (select count(*) from Factura where fact_vendedor = empl_codigo and year(fact_fecha) = 2012 and fact_total > 100)
    ELSE (select count(*)/2 from Factura join Empleado e2 on fact_vendedor = e2.empl_codigo and e2.empl_jefe = empl_codigo and YEAR(fact_fecha) = 2012 group by fact_vendedor)
    END
    from Factura
    where fact_vendedor = empl_codigo
    group by fact_vendedor
)
from Empleado

-- 21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al
-- menos una factura, la cantidad de clientes a los que se les facturo de manera incorrecta
-- al menos una factura y que cantidad de facturas se realizaron de manera incorrecta. Se
-- considera que una factura es incorrecta cuando la diferencia entre el total de la factura
-- menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de
-- los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar
-- son:
--  Año
--  Clientes a los que se les facturo mal en ese año
--  Facturas mal realizadas en ese año

select year(f1.fact_fecha), 
(
    select count(*)
    from Factura f2
    where year(f2.fact_fecha) = year(f1.fact_fecha)
    and ((f2.fact_total - f2.fact_total_impuestos) - (
                                                        select sum(item_cantidad * item_precio) 
                                                        from Item_Factura 
                                                        where item_tipo = f2.fact_tipo and item_numero = f2.fact_numero and item_sucursal = f2.fact_sucursal
                                                    ) > 1)
) 'Facturas mal realizadas',
(
    select count(distinct f2.fact_cliente)
    from Factura f2
    where year(f2.fact_fecha) = year(f1.fact_fecha)
    and ((f2.fact_total - f2.fact_total_impuestos) - (
                                                        select sum(item_cantidad * item_precio)
                                                        from Item_Factura
                                                        where item_tipo = f2.fact_tipo and item_numero = f2.fact_numero and item_sucursal = f2.fact_sucursal
                                                    ) > 1)
) 'Clientes mal facturados'
from Factura f1
group by year(f1.fact_fecha)

-- 22. Escriba una consulta sql que retorne una estadistica de venta para todos los rubros por
-- trimestre contabilizando todos los años. Se mostraran como maximo 4 filas por rubro (1
-- por cada trimestre).
-- Se deben mostrar 4 columnas:
-- [X] Detalle del rubro
-- [X] Numero de trimestre del año (1 a 4)
-- [X] Cantidad de facturas emitidas en el trimestre en las que se haya vendido al
-- menos un producto del rubro
-- [X] Cantidad de productos diferentes del rubro vendidos en el trimestre
-- 
-- El resultado debe ser ordenado alfabeticamente por el detalle del rubro y dentro de cada
-- rubro primero el trimestre en el que mas facturas se emitieron.
-- No se deberan mostrar aquellos rubros y trimestres para los cuales las facturas emitiadas
-- no superen las 100.
-- En ningun momento se tendran en cuenta los productos compuestos para esta
-- estadistica.

SELECT rubr_detalle, DATEPART(quarter, fact_fecha)'TRIMESTRE', count(*)'CANT Facturas', count(distinct prod_codigo) 'CANT PRODUCTOS'
FROM Rubro 
join Producto on prod_rubro = rubr_id
join Item_Factura on prod_codigo = item_producto
join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
group by rubr_detalle, DATEPART(quarter, fact_fecha)
having count(*) > 100
order by rubr_detalle ASC

-- 23. Realizar una consulta SQL que para cada año muestre :
-- [X] Año
-- [X] El producto con composición más vendido para ese año.
-- [X] Cantidad de productos que componen directamente al producto más vendido
-- [X] La cantidad de facturas en las cuales aparece ese producto.
-- [X] El código de cliente que más compro ese producto.
-- [X] El porcentaje que representa la venta de ese producto respecto al total de venta
-- del año.
-- El resultado deberá ser ordenado por el total vendido por año en forma descendente.

select year(f1.fact_fecha), 
i1.item_producto,
count(distinct comp_producto),
count(distinct fact_tipo+fact_sucursal+fact_numero),
(
    select top 1 fact_cliente
    from Factura
    join Item_Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    where i1.item_producto = item_producto and year(fact_fecha) = year(f1.fact_fecha)
    group by fact_cliente
    order by sum(item_cantidad)
),
AVG(item_cantidad*item_precio)
from Factura f1
join Item_Factura i1 on i1.item_numero+i1.item_sucursal+i1.item_tipo = f1.fact_numero+f1.fact_sucursal+f1.fact_tipo
join Composicion on item_producto = comp_producto
group by year(f1.fact_fecha), item_producto
having item_producto in (
                            select top 1 item_producto
                            from Item_Factura 
                            join Composicion on comp_producto = item_producto
                            join Factura f2 on f2.fact_tipo+f2.fact_sucursal+f2.fact_numero = item_tipo+item_sucursal+item_numero
                            where year(f2.fact_fecha) = year(f1.fact_fecha)
                            group by item_producto
                            order by sum(item_cantidad) desc
                        )

-- 24. Escriba una consulta que considerando solamente las facturas correspondientes a los
-- dos vendedores con mayores comisiones, retorne los productos con composición
-- facturados al menos en cinco facturas,
-- La consulta debe retornar las siguientes columnas:
--  Código de Producto
--  Nombre del Producto
--  Unidades facturadas
-- El resultado deberá ser ordenado por las unidades facturadas descendente.

SELECT prod_codigo, prod_detalle, count(item_cantidad)
FROM Factura
JOIN Item_Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
AND fact_vendedor IN (
                        select top 2 empl_codigo
                        from Empleado
                        order by empl_comision desc
                     )
JOIN Producto on item_producto = prod_codigo
JOIN Composicion on comp_producto = prod_codigo
group by prod_codigo, prod_detalle
having count(fact_numero) > 5

-- 25. Realizar una consulta SQL que para cada año y familia muestre :
-- a. Año
-- b. El código de la familia más vendida en ese año.
-- c. Cantidad de Rubros que componen esa familia.
-- d. Cantidad de productos que componen directamente al producto más vendido de
-- esa familia.
-- e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa
-- familia.
-- f. El código de cliente que más compro productos de esa familia.
-- g. El porcentaje que representa la venta de esa familia respecto al total de venta
-- del año.
-- El resultado deberá ser ordenado por el total vendido por año y familia en forma
-- descendente.
SELECT year(f.fact_fecha),
p.prod_familia,
(
    select count(distinct prod_rubro)
    from Producto
    where p.prod_familia = prod_familia
)'Rubros de la familia',
(
    select count(*)
    from Composicion
    where comp_producto in 
                            (
                                select top 1 item_producto
                                from Item_Factura
                                join Producto on item_producto = prod_codigo
                                where p.prod_familia = prod_familia and year(f.fact_fecha) = year(fact_fecha)
                                group by item_producto
                                order by sum(item_cantidad)
                            )
),
count(distinct fact_numero),
(
    select top 1 fact_cliente
    from Factura
    join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
    join Producto on prod_codigo = item_producto
    where p.prod_familia = prod_familia and year(f.fact_fecha) = year(fact_fecha)
    group by fact_cliente
    order by sum(item_cantidad) desc
)'Cliente que mas compro',
(sum(item_precio*item_cantidad) / (select sum(fact_total) from Factura where year(fact_fecha) = year(f.fact_fecha)))*100 'Porcentaje de ventas de la familia'
from Factura f
join Item_Factura on f.fact_tipo+f.fact_sucursal+f.fact_numero=item_tipo+item_sucursal+item_numero
join Producto p on item_producto = p.prod_codigo
where p.prod_familia in 
                    (
                        select top 1 p.prod_familia
                        from Producto p join Item_Factura i on p.prod_codigo=i.item_producto
                        join Factura f on f.fact_tipo+f.fact_numero+f.fact_sucursal=i.item_tipo+i.item_numero+i.item_sucursal
                        where year(f.fact_fecha) = year(fact_fecha)
                        group by p.prod_familia
                        order by count(f.fact_numero) desc
                    )
group by year(f.fact_fecha), p.prod_familia
order by sum(f.fact_total), p.prod_familia

-- 26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las
-- siguientes columnas:
--  Empleado
--  Depósitos que tiene a cargo
--  Monto total facturado en el año corriente
--  Codigo de Cliente al que mas le vendió
--  Producto más vendido
--  Porcentaje de la venta de ese empleado sobre el total vendido ese año.
-- 
-- Los datos deberan ser ordenados por venta del empleado de mayor a menor.

SELECT empl_codigo, (select count(*) from DEPOSITO where depo_encargado = empl_codigo), sum(fact_total),
(
    select top 1 clie_codigo
    from Cliente
    where clie_vendedor = empl_codigo
    order by count(fact_numero)
),
(
    select top 1 item_producto
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal and fact_vendedor = empl_codigo
    group by item_producto
    order by count(item_cantidad)
),
(sum(fact_total)/(select sum(fact_total) from Factura where year(fact_fecha) = (select max(year(fact_fecha)) from Factura)))*100
from Empleado
join Factura on fact_vendedor=empl_codigo and year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
group by empl_codigo

-- 27. Escriba una consulta sql que retorne una estadística basada en la facturacion por año y
-- envase devolviendo las siguientes columnas:
--  Año
--  Codigo de envase
--  Detalle del envase
--  Cantidad de productos que tienen ese envase
--  Cantidad de productos facturados de ese envase
--  Producto mas vendido de ese envase
--  Monto total de venta de ese envase en ese año
--  Porcentaje de la venta de ese envase respecto al total vendido de ese año
-- 
-- Los datos deberan ser ordenados por año y dentro del año por el envase con más
-- facturación de mayor a menor

SELECT year(f.fact_fecha),
enva_codigo,
enva_detalle,
(
    select count(*)
    from Producto
    where prod_envase = enva_codigo
)'Productos con envase',
count(distinct prod_codigo) 'Productos facturados',
(
    select top 1 prod_codigo
    from Producto
    join Item_Factura on item_producto = prod_codigo
    join Factura on fact_tipo+fact_numero+fact_sucursal=item_tipo+item_numero+item_sucursal
    where prod_envase = enva_codigo 
    and year(fact_fecha) = YEAR(f.fact_fecha)
    group by prod_codigo
    order by count(prod_codigo) desc
)'Prod. mas vendido',
sum(item_precio*item_cantidad)'Monto total',
(sum(item_precio*item_cantidad) / (select sum(fact_total) from Factura where year(f.fact_fecha) = year(fact_fecha)))*100 '% Del año'
from Factura f
join Item_Factura on item_tipo+item_sucursal+item_numero=f.fact_tipo+f.fact_sucursal+f.fact_numero
join Producto on prod_codigo = item_producto
join Envases on enva_codigo = prod_envase
group by year(fact_fecha), enva_detalle, enva_codigo
order by year(fact_fecha), sum(item_precio*item_cantidad) DESC

-- 28. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
-- siguientes columnas:
--  Año.
--  Codigo de Vendedor
--  Detalle del Vendedor
--  Cantidad de facturas que realizó en ese año
--  Cantidad de clientes a los cuales les vendió en ese año.
--  Cantidad de productos facturados con composición en ese año
--  Cantidad de productos facturados sin composicion en ese año.
--  Monto total vendido por ese vendedor en ese año
-- Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
-- vendido mas productos diferentes de mayor a menor.

select year(f.fact_fecha)'Año',
f.fact_vendedor 'Codigo vendedor',
RTRIM(empl_nombre) + ' ' + RTRIM(empl_apellido) 'Nombre y apellido',
COUNT(distinct f.fact_numero)'Cant. facturas',
count(distinct f.fact_cliente)'Cant. Clientes',
(
    select count(*)
    from Factura
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = YEAR(f.fact_fecha)
    and fact_vendedor = empl_codigo
    and item_producto in (select comp_producto from Composicion)
)'Productos con compo.',
(
    select count(*)
    from Factura
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = YEAR(f.fact_fecha)
    and fact_vendedor = empl_codigo
    and item_producto not in (select comp_producto from Composicion)
)'Productos sin compo.',
sum(item_cantidad*item_precio) 'Total facturado'
from Factura f join Empleado on empl_codigo = fact_vendedor
join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
group by YEAR(f.fact_fecha), f.fact_vendedor, empl_nombre, empl_apellido, empl_codigo
order by year(f.fact_fecha), count(distinct item_producto) desc

-- 29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para
-- los productos que pertenezcan a las familias que tengan más de 20 productos asignados
-- a ellas, la cual deberá devolver las siguientes columnas:
-- a. Código de producto
-- b. Descripción del producto
-- c. Cantidad vendida
-- d. Cantidad de facturas en la que esta ese producto
-- e. Monto total facturado de ese producto
-- Solo se deberá mostrar un producto por fila en función a los considerandos establecidos
-- antes. El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.

select prod_codigo, 
prod_detalle,
sum(item_cantidad),
count(distinct fact_numero),
sum(item_cantidad*item_precio)
from Factura f
join Item_Factura on item_tipo+item_numero+item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
join Producto on prod_codigo=item_producto
where year(f.fact_fecha) = 2011
and prod_familia in 
(
    select prod_familia
    from Producto
    group by prod_familia
    having count(*) > 20
)
group by prod_codigo, prod_detalle
order by sum(item_cantidad) DESC

-- 30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean
-- jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la
-- consulta que retorne las siguientes columnas:
--  Nombre del Jefe
--  Cantidad de empleados a cargo
--  Monto total vendido de los empleados a cargo
--  Cantidad de facturas realizadas por los empleados a cargo
--  Nombre del empleado con mejor ventas de ese jefe
-- Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese
-- necesario.
-- Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se
-- deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas.

select rtrim(j.empl_nombre) 'Nombre Jefe',
count(distinct e.empl_codigo) 'Cant. Empleados',
sum(fact_total)'Total vendido',
count(fact_numero) 'Cant. Facturas',
(
    select top 1 RTRIM(empl_nombre)
    from Empleado
    join Factura on fact_vendedor=empl_codigo
    where empl_jefe = j.empl_codigo
    group by empl_nombre
    order by sum(fact_total) desc
) 'Empleado con mejores ventas'
from Empleado j
join Empleado e on e.empl_jefe = j.empl_codigo
join Factura on fact_vendedor = e.empl_codigo
and year(fact_fecha) = 2012
group by j.empl_nombre, j.empl_codigo
having count(fact_numero) > 10
order by sum(fact_total) desc

-- 31. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
-- siguientes columnas:
--  Año.
--  Codigo de Vendedor
--  Detalle del Vendedor
--  Cantidad de facturas que realizó en ese año
--  Cantidad de clientes a los cuales les vendió en ese año.
--  Cantidad de productos facturados con composición en ese año
--  Cantidad de productos facturados sin composicion en ese año.
--  Monto total vendido por ese vendedor en ese año
-- Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
-- vendido mas productos diferentes de mayor a menor.

select year(f.fact_fecha) 'Año',
f.fact_vendedor 'Cod. vendedor',
rtrim(empl_nombre)+' '+rtrim(empl_apellido) 'Detalle vendedor',
count(f.fact_numero) 'Cant. Facturas',
count(distinct f.fact_cliente) 'Clientes atendidos',
(
    select count(*)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = YEAR(f.fact_fecha)
    and fact_vendedor = empl_codigo
    and item_producto in (select comp_producto from Composicion)
) 'Prods. con Compo.',
(
    select count(*)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = YEAR(f.fact_fecha)
    and fact_vendedor = empl_codigo
    and item_producto not in (select comp_producto from Composicion)
) 'Prods. sin Compo.',
sum(item_cantidad*item_precio) 'Total facturado'
from Factura f
join Empleado on empl_codigo = f.fact_vendedor
join Item_Factura on item_tipo+item_numero+item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
group by year(f.fact_fecha), f.fact_vendedor, empl_nombre, empl_apellido, empl_codigo
order by year(f.fact_fecha), count(distinct item_producto) desc

-- 32. Se desea conocer las familias que sus productos se facturaron juntos en las mismas
-- facturas para ello se solicita que escriba una consulta sql que retorne los pares de
-- familias que tienen productos que se facturaron juntos. Para ellos deberá devolver las
-- siguientes columnas:
--  Código de familia
--  Detalle de familia
--  Código de familia
--  Detalle de familia
--  Cantidad de facturas
--  Total vendido
-- Los datos deberan ser ordenados por Total vendido y solo se deben mostrar las familias
-- que se vendieron juntas más de 10 veces.

select f1.fami_id, f1.fami_detalle, f2.fami_id, f2.fami_detalle, count(distinct fact_numero) 'Cant. Facturas', sum(i1.item_cantidad*i1.item_precio+i2.item_cantidad+i2.item_precio) 'Total vendido'
from Factura
join Item_Factura i1 on i1.item_tipo+i1.item_numero+i1.item_sucursal=fact_tipo+fact_numero+fact_sucursal
join Item_Factura i2 on i2.item_tipo+i2.item_numero+i2.item_sucursal=fact_tipo+fact_numero+fact_sucursal
join Producto p1 on p1.prod_codigo=i1.item_producto
join Producto p2 on p2.prod_codigo=i2.item_producto
join Familia f1 on f1.fami_id = p1.prod_familia
join Familia f2 on f2.fami_id = p2.prod_familia
where f1.fami_id = f2.fami_id
group by f1.fami_id, f1.fami_detalle, f2.fami_id, f2.fami_detalle
having count(distinct fact_numero) > 10
order by 6 


-- 33. Se requiere obtener una estadística de venta de productos que sean componentes. Para
-- ello se solicita que realiza la siguiente consulta que retorne la venta de los
-- componentes del producto más vendido del año 2012. Se deberá mostrar:
-- a. Código de producto
-- b. Nombre del producto
-- c. Cantidad de unidades vendidas
-- d. Cantidad de facturas en la cual se facturo
-- e. Precio promedio facturado de ese producto.
-- f. Total facturado para ese producto
-- El resultado deberá ser ordenado por el total vendido por producto para el año 2012.

SELECT prod_codigo,
prod_detalle,
sum(item_cantidad)'Cant. vedidas',
count(distinct fact_numero) 'Cant. facts.',
avg(item_precio)'Precio promedio',
sum(item_precio*item_cantidad)'Total Facturado'
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on fact_tipo+fact_numero+fact_sucursal=item_tipo+item_numero+item_sucursal
where prod_codigo in 
(
    select comp_componente
    from Composicion
    where comp_producto in 
    (
        select top 1 item_producto
        from Item_Factura
        join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
        where year(fact_fecha) = 2012
        group by item_producto
        order by sum(item_cantidad) desc
    )
)
group by prod_codigo, prod_detalle
order by sum(item_cantidad*item_precio)

-- 34. Escriba una consulta sql que retorne para todos los rubros la cantidad de facturas mal
-- facturadas por cada mes del año 2011 Se considera que una factura es incorrecta cuando
-- en la misma factura se factutan productos de dos rubros diferentes. Si no hay facturas
-- mal hechas se debe retornar 0. Las columnas que se deben mostrar son:
-- 1- Codigo de Rubro
-- 2- Mes
-- 3- Cantidad de facturas mal realizadas.

SELECT rubr_id, 
month(fact_fecha) 'MES',
isnull(count(distinct fact_numero), 0) '# FACTURAS MALAS'
from Rubro
join Producto on rubr_id = prod_rubro
join Item_Factura on item_producto = prod_codigo
join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
where year(fact_fecha) = 2011
and fact_numero in 
(
    select fact_numero
    from Factura
    join Item_Factura i1 on i1.item_tipo+i1.item_numero+i1.item_sucursal=fact_tipo+fact_numero+fact_sucursal
    join Item_Factura i2 on i2.item_tipo+i2.item_numero+i2.item_sucursal=fact_tipo+fact_numero+fact_sucursal
    join Producto p1 on p1.prod_codigo = i1.item_producto
    join Producto p2 on p2.prod_codigo = i2.item_producto
    where p1.prod_rubro <> p2.prod_rubro
    group by fact_numero
)
group by rubr_id, month(fact_fecha)
order by 2

-- 35. Se requiere realizar una estadística de ventas por año y producto, para ello se solicita
-- que escriba una consulta sql que retorne las siguientes columnas:
--  Año
--  Codigo de producto
--  Detalle del producto
--  Cantidad de facturas emitidas a ese producto ese año
--  Cantidad de vendedores diferentes que compraron ese producto ese año.
--  Cantidad de productos a los cuales compone ese producto, si no compone a ninguno
-- se debera retornar 0.
--  Porcentaje de la venta de ese producto respecto a la venta total de ese año.
-- Los datos deberan ser ordenados por año y por producto con mayor cantidad vendida.

select year(f.fact_fecha), 
prod_codigo, 
prod_detalle,
count(distinct f.fact_numero) 'CANT. FACTURAS',
count(distinct f.fact_cliente) 'CANT. DE CLIENTES',
(
    select count(distinct comp_producto)
    from Composicion
    where comp_componente = prod_codigo
),
(sum(item_cantidad*item_precio) / (select sum(item_cantidad*item_precio) from Item_Factura join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal where year(fact_fecha) = year(f.fact_fecha)))*100 '% del total del año'
from Factura f
join Item_Factura on item_tipo+item_numero+item_sucursal=f.fact_tipo+f.fact_numero+f.fact_sucursal
join Producto on prod_codigo = item_producto
group by year(f.fact_fecha), prod_codigo, prod_detalle
order by year(f.fact_fecha), sum(item_cantidad) desc