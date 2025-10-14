/*
1. Hacer una función que dado un artículo y un deposito devuelva un string que
indique el estado del depósito según el artículo. Si la cantidad almacenada es
menor al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el
% de ocupación. Si la cantidad almacenada es mayor o igual al límite retornar
“DEPOSITO COMPLETO”.
*/

CREATE FUNCTION ej1(@articulo char(8), @deposito char(2))
RETURNS char(50)
BEGIN
    DECLARE  @maximo numeric(12,2), @stock numeric(12,2)
    select @stock=stoc_cantidad, @maximo=ISNULL(stoc_stock_maximo,0) from STOCK where stoc_producto = @articulo and stoc_deposito = @stock
    if @stock <= @maximo AND @maximo <> 0
        RETURN 'OCUPACION DEL DEPOSITO '+@deposito+' '+STR(@stock/@maximo*100,5,2)
    RETURN 'DEPOSITO COMPLETO'
END
GO


/*
2. Realizar una función que dado un artículo y una fecha, retorne el stock que
existía a esa fecha
*/

ALTER FUNCTION ej2(@articulo char(8), @fecha smalldatetime)
RETURNS NUMERIC(12,2)
BEGIN
    RETURN (SELECT ISNULL(SUM(stoc_cantidad),0) FROM STOCK WHERE stoc_producto = @articulo) + 
    (SELECT ISNULL(SUM(item_cantidad),0) FROM item_factura JOIN factura ON item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
    WHERE fact_fecha >= @fecha AND item_producto = @articulo)
END
GO

select prod_codigo, dbo.ej2(prod_codigo, '10/01/2011')
FROM Producto
GO

select SUM(stoc_cantidad)
FROM STOCK WHERE stoc_producto = '00001121'

/*
3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado
en caso que sea necesario. Se sabe que debería existir un único gerente general
(debería ser el único empleado sin jefe). Si detecta que hay más de un empleado
sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por
mayor salario. Si hay más de uno se seleccionara el de mayor antigüedad en la
empresa. Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla
de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad
de empleados que había sin jefe antes de la ejecución.
*/
GO
ALTER procedure ej3 @cantidad int OUTPUT
AS
BEGIN
	SELECT @cantidad = COUNT(*) FROM EMPLEADO WHERE empl_jefe is null
	if @cantidad > 1 
	begin
		update Empleado
		set empl_jefe = (SELECT TOP 1 EMPL_CODIGO 
						 FROM EMPLEADO 
						 WHERE empl_jefe is null 
						 ORDER BY empl_salario DESC, empl_ingreso ASC)
		WHERE empl_jefe is null and 
			  empl_codigo not in (SELECT TOP 1 EMPL_CODIGO 
								  FROM EMPLEADO  
								  where empl_jefe is null 
								  ORDER BY empl_salario DESC, empl_ingreso ASC)
	end
END


BEGIN 
declare @cantidad_emp int 
exec dbo.ej3 @cantidad_emp output 
PRINT @cantidad_emp
END
-- select * from Empleado

-- 4. Cree el/los objetos de base de datos necesarios para actualizar la columna de
-- empleado empl_comision con la sumatoria del total de lo vendido por ese
-- empleado a lo largo del último año. Se deberá retornar el código del vendedor
-- que más vendió (en monto) a lo largo del último año.
GO
CREATE PROCEDURE ej4 @vendedorConMayorMonto int OUTPUT
AS
BEGIN
  UPDATE Empleado
  set empl_salario = empl_salario + (select sum(fact_total) 
                                      from Factura
                                      where fact_vendedor = empl_codigo and year(fact_fecha) = (select max(year(fact_fecha)) from Factura)+empl_comision)
  set @vendedorConMayorMonto = (select top 1 fact_vendedor 
                                from Factura
                                group by fact_vendedor
                                order by sum(fact_total)desc)
END
/*
8. Realizar un procedimiento que complete la tabla Diferencias de precios, para los
productos facturados que tengan composición y en los cuales el precio de
facturación sea diferente al precio del cálculo de los precios unitarios por
cantidad de sus componentes, se aclara que un producto que compone a otro,
también puede estar compuesto por otros y así sucesivamente, la tabla se debe
crear y está formada por las siguientes columnas.
*/

GO
create PROCEDURE ej8
as
BEGIN
  insert diferencias
  select distinct p1.prod_codigo, prod_detalle, (select count (*) from Composicion where comp_producto = p1.prod_codigo), 
    (select sum(comp_cantidad*p2.prod_precio) from Composicion join Producto p2 on comp_componente = p2.prod_codigo
      where comp_producto = p1.prod_codigo), item_precio
  from Item_Factura join Producto p1 on p1.prod_codigo = item_producto
  where p1.prod_codigo in (select comp_producto from Composicion)
  and item_precio <> (select sum(comp_cantidad*p2.prod_precio) from Composicion join Producto p2 on comp_componente = p2.prod_codigo
                            where comp_producto = p1.prod_codigo)
  RETURN
END

/*
9. Crear el/los objetos de base de datos que ante alguna modificación de un ítem de
factura de un artículo con composición realice el movimiento de sus
correspondientes componentes.
*/

GO
CREATE TRIGGER ej9 ON ITEM_FACTURA FOR UPDATE 
AS 
BEGIN
	DECLARE @COMPONENTE char(8),@CANTIDAD decimal(12,2)
	DECLARE cursorComponentes CURSOR FOR SELECT comp_componente, (I.item_cantidad - d.item_cantidad)*comp_cantidad FROM Composicion 
								JOIN inserted I on comp_producto = i.item_producto JOIN deleted d on comp_producto = d.item_producto
								WHERE i.item_cantidad != d.item_cantidad
	OPEN cursorComponentes
	FETCH NEXT FROM cursorComponentes 
	INTO @COMPONENTE,@CANTIDAD
	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE STOCK SET stoc_cantidad = stoc_cantidad - @CANTIDAD
		WHERE stoc_producto = @COMPONENTE AND STOC_DEPOSITO = (SELECT TOP 1 STOC_DEPOSITO FROM STOCK
									 WHERE STOC_PRODUCTO = @COMPONENTE ORDER BY STOC_CANTIDAD DESC)
		FETCH NEXT FROM cursorComponentes
		INTO @COMPONENTE,@CANTIDAD
	END
	CLOSE cursorComponentes
	DEALLOCATE cursorComponentes
END

/*
10. Crear el/los objetos de base de datos que ante el intento de borrar un artículo
verifique que no exista stock y si es así lo borre en caso contrario que emita un
mensaje de error.
*/
GO
CREATE TRIGGER ej10 ON Producto INSTEAD OF DELETE
AS
BEGIN
  IF exists(select * from STOCK join deleted d on stoc_producto = d.prod_codigo where stoc_cantidad > 0)
  BEGIN
    RAISERROR('El articulo posee stock',1,1)
  END
  delete from STOCK where stoc_producto in (select prod_codigo from deleted)
  delete from Composicion where comp_producto in (select prod_codigo from deleted)
  delete from Producto where prod_codigo in (select prod_codigo from deleted)
END

-- 11. Cree el/los objetos de base de datos necesarios para que dado un código de
-- empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o
-- indirectamente). Solo contar aquellos empleados (directos o indirectos) que
-- tengan un código mayor que su jefe directo.
GO
ALTER FUNCTION ej11 (@jefe numeric(6))
returns int 
AS
BEGIN
  declare @empleado numeric(6), @cantidad int
  select @cantidad = 0
  declare c1 cursor for select empl_codigo from Empleado where empl_jefe = @jefe
  OPEN c1
  fetch c1 into @empleado
  while @@FETCH_STATUS = 0
  BEGIN
    select @cantidad = @cantidad + 1 + dbo.ej11(@empleado)

    fetch c1 into @empleado
  END
  CLOSE c1
  DEALLOCATE c1
  return @cantidad
END

go
select empl_codigo, dbo.ej11(empl_codigo) from Empleado

-- 12. Cree el/los objetos de base de datos necesarios para que nunca un producto
-- pueda ser compuesto por sí mismo. Se sabe que en la actualidad dicha regla se
-- cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos
-- y tecnologías. No se conoce la cantidad de niveles de composición existentes.

GO
create trigger ej12 ON Composicion for insert
AS
BEGIN
  IF exists (select * from inserted where dbo.composicionRecursiva(comp_producto, comp_componente) = 1)
    ROLLBACK
END

go
create function composicionRecursiva (@producto char(8), @componente char(8))
returns int 
as
begin  
  declare @comp char(8)
  IF @producto = @componente
    return 1
  declare c1 cursor for (select comp_componente from Composicion where comp_producto = @componente)
  open c1
  fetch c1 into @comp
  while @@FETCH_STATUS = 0
  BEGIN
    IF dbo.composicionRecursiva(@producto, @comp) = 1
      return 1
    fetch c1 into @comp
  END
  close c1
  DEALLOCATE c1
  return 0
END

-- 13. Cree el/los objetos de base de datos necesarios para implantar la siguiente regla
-- “Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de
-- sus empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha
-- regla se cumple y que la base de datos es accedida por n aplicaciones de
-- diferentes tipos y tecnologías

GO
CREATE TRIGGER ej13 ON Empleado for DELETE, UPDATE
AS
BEGIN
  IF (select count(*) from inserted) = 0 
    BEGIN
    IF EXISTS (select * from deleted d where (select empl_salario from Empleado where empl_jefe = d.empl_jefe) 
                                              > dbo.ej13(d.empl_jefe) * 0.2)
      ROLLBACK
    END
  ELSE
    BEGIN
    IF EXISTS (select * from inserted i where (select empl_salario from Empleado where empl_jefe = i.empl_jefe) 
                                              > dbo.ej13(i.empl_jefe) * 0.2)
      ROLLBACK
    END
END

GO
CREATE FUNCTION ej13 (@jefe numeric(6))
returns numeric(12,2) 
AS
BEGIN
  declare @empleado numeric(6), @salarios numeric(12,2)
  select @salarios = 0
  declare c1 cursor for select empl_codigo from Empleado where empl_jefe = @jefe
  OPEN c1
  fetch c1 into @empleado
  while @@FETCH_STATUS = 0
  BEGIN
    select @salarios = @salarios + (select empl_salario from Empleado where empl_codigo = @empleado) + dbo.ej13(@empleado)

    fetch c1 into @empleado
  END
  CLOSE c1
  DEALLOCATE c1
  return @salarios
END

go
select distinct empl_jefe, dbo.ej13(empl_jefe) from Empleado

-- 14. Agregar el/los objetos necesarios para que si un cliente compra un producto
-- compuesto a un precio menor que la suma de los precios de sus componentes
-- que imprima la fecha, que cliente, que productos y a qué precio se realizó la
-- compra. No se deberá permitir que dicho precio sea menor a la mitad de la suma
-- de los componentes.

GO
CREATE TRIGGER ej_t14 ON Item_Factura INSTEAD OF INSERT
AS
BEGIN
  declare @tipo char(1), @sucursal char(4), @numero char(8), @cliente char(6), @fecha DATETIME, @producto char(8), @cantidad numeric(12,2), @precio numeric(12,4)
  declare c1 cursor for (select item_tipo, item_sucursal, item_numero, fact_cliente, fact_fecha, item_producto, item_precio, item_cantidad
                        from inserted join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero)
  OPEN C1
  FETCH c1 into @tipo, @sucursal, @numero, @cliente, @fecha, @producto, @precio, @cantidad
  WHILE @@FETCH_STATUS = 0
  BEGIN
    if @precio < (dbo.ej14(@producto)) / 2
    BEGIN
    IF @precio < dbo.ej14(@producto)
      BEGIN
        PRINT('FECHA: '+ @fecha + ' CLIENTE: ' + @cliente + ' PRODUCTO: ' + @producto + ' PRECIO: ' + @precio)
        INSERT Item_Factura values (@tipo, @sucursal, @numero, @producto, @cantidad, @precio)
      END
    ELSE
      INSERT Item_Factura values (@tipo, @sucursal, @numero, @producto, @cantidad, @precio)
    END
    FETCH c1 into @tipo, @sucursal, @numero, @cliente, @fecha, @producto, @precio, @cantidad
  END
  CLOSE c1
  DEALLOCATE c1
END

GO
ALTER FUNCTION ej14 (@producto char(8))
returns numeric(12,4)
AS
BEGIN  
  declare @suma numeric(12,4), @comp char(8)
  declare c1 cursor for (select comp_componente from Composicion where comp_producto = @producto)
  open c1
  fetch c1 into @comp
  select @suma = (select isnull(sum(comp_cantidad*prod_precio),0) from Composicion join Producto on prod_codigo = comp_componente 
                          where comp_producto = @producto)
  while @@FETCH_STATUS = 0
  BEGIN
    select @suma = @suma + dbo.ej14(@comp)
    fetch c1 into @comp
  END
  CLOSE c1
  DEALLOCATE c1
  RETURN @suma
END