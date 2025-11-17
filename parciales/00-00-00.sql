---------
-- SQL --
---------

/*
Realizar una consulta SQL que retorne para todas las zonas que tengan
2 (dos) o mas depositos.
Detalle Zona
Cantidad de Depositos x Zona
Cantidad de Productos distintos en los depositos de esa zona.
Cantidad de Productos distintos vendidos de esos depositos y zona.
El resultado debera ser ordenado por la zona que mas empleados tenga
NOTA: No se permite el uso de sub-selects en el FROM.
*/

select depo_zona,
count(distinct depo_codigo),
count(distinct stoc_producto),
count(distinct item_producto)
from Zona z
join DEPOSITO on z.zona_codigo = depo_zona
join STOCK on stoc_deposito = depo_codigo --Aca preguntaria si los productos que se cuentan tienen que contar con stock o no, si se consideran los que no tienen stock se tiene que hacer un left join.
join Item_Factura on item_producto = stoc_producto
group by depo_zona, z.zona_codigo
having count(distinct depo_codigo) > 2
order by (select count(empl_codigo) from Departamento join Empleado on depa_codigo = empl_departamento where depa_zona = z.zona_codigo)


----------
-- TSQL --
----------

/* 2. Cree el o los objetos necesarios para que controlar que un producto no pueda tener asignado 
un rubro que tenga mas de 20 productos asignados, 
si esto ocurre, hay que asignarle el rubro que menos productos tenga asignado e informar a que producto y que rubro se le asigno.
En la actualidad la regla se cumple y no se sabe la forma en que se accede a la Base de Datos.*/

GO
create trigger ej_parcial on producto for insert
as
BEGIN
    declare @prod char(8), @rubroConMenosProductos char(4), @rubro char(4)
    declare c1 cursor for select i.prod_codigo, i.prod_rubro from inserted i
    open c1
    fetch c1 into @prod, @rubro
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @rubro in (select rubr_id from Rubro join Producto on prod_rubro = rubr_id group by rubr_id having count(*) > 20)
        BEGIN
            select top 1 @rubroConMenosProductos = rubr_id from Rubro join Producto on rubr_id = prod_rubro group by rubr_id order by count(*) asc
            UPDATE Producto set prod_rubro = @rubroConMenosProductos where prod_codigo = @prod
            print('SE REASIGNA EL RUBRO' + @rubroConMenosProductos + 'AL PRODUCTO ' + @prod)
        END 
        FETCH c1 into @prod
    END 
    close c1
    DEALLOCATE c1
END
