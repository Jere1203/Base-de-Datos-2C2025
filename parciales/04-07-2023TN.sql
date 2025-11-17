---------
-- SQL --
---------

/*
Realizar una consulta SQL que retorne para todas las zonas que tengan
3 (tres) o más depósitos.
    1) Detalle Zona
    2) Cantidad de Depósitos x Zona
    3) Cantidad de Productos distintos compuestos en sus depósitos
    4) Producto mas vendido en el año 2012 que tenga stock en al menos
    uno de sus depósitos.
    5) Mejor encargado perteneciente a esa zona (El que mas vendió en la
        historia).
El resultado deberá ser ordenado por monto total vendido del encargado
descendiente.
NOTA: No se permite el uso de sub-selects en el FROM ni funciones
definidas por el usuario para este punto.
*/

SELECT zona_detalle,
count(distinct depo_codigo),
ISNULL(count(distinct comp_producto),0),
(
    select top 1 item_producto
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    where year(fact_fecha) = 2012 
    and item_producto in
    (
        select stoc_producto
        from STOCK
        where stoc_deposito = depo_codigo
    )
    group by item_producto
    order by sum(item_cantidad) DESC
),
(
    select top 1 fact_vendedor
    from Factura
    join Empleado on empl_codigo = fact_vendedor
    join Departamento on empl_departamento = depa_codigo
    where depa_zona = zona_codigo
    group by fact_vendedor
    order by sum(fact_total) desc
)
from Zona
join DEPOSITO on zona_codigo = depo_zona
join STOCK s on s.stoc_deposito = depo_codigo
left join Composicion on comp_producto = stoc_producto
group by zona_detalle, depo_codigo, zona_codigo
having count(distinct depo_codigo) > 3
order by 5

----------
-- TSQL --
----------

/*2. Actualmente el campo fact_vendedor representa al empleado que vendió
la factura. Implementar el/los objetos necesarios para respetar
integridad referenciales de dicho campo suponiendo que no existe una
foreign key entre ambos.

NOTA: No se puede usar una foreign key para el ejercicio, deberá buscar
otro método */

/*
Si alguien intenta insertar una factura con un fact_vendedor que no existe en la tabla Empleado, no debería permitirse.

Y si alguien intenta borrar un empleado que todavía tiene facturas asociadas, tampoco debería permitirse.
*/

GO
create trigger verificar_fk_on_insert on Factura for INSERT
as
BEGIN
    if exists (select * from inserted where fact_vendedor not in (select empl_codigo from Empleado))
    BEGIN
        ROLLBACK
    END
END

GO
CREATE TRIGGER verificar_fk_on_delete on Factura for DELETE
AS
BEGIN
    if exists (select * from deleted where fact_vendedor not in (select empl_codigo from Empleado))
    BEGIN
        ROLLBACK
    END
END