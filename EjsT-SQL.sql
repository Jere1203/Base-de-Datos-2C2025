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

-- 15. Cree el/los objetos de base de datos necesarios para que el objeto principal
-- reciba un producto como parametro y retorne el precio del mismo.
-- Se debe prever que el precio de los productos compuestos sera la sumatoria de
-- los componentes del mismo multiplicado por sus respectivas cantidades. No se
-- conocen los nivles de anidamiento posibles de los productos. Se asegura que
-- nunca un producto esta compuesto por si mismo a ningun nivel. El objeto
-- principal debe poder ser utilizado como filtro en el where de una sentencia
-- select.

GO
CREATE FUNCTION ej15(@producto char(8)) 
RETURNS numeric(12,4)
AS
BEGIN
    IF (SELECT COUNT(*) FROM Composicion WHERE comp_producto = @producto) > 0 
    BEGIN 
        declare @suma numeric(12,4)
        declare @comp char(8)
        DECLARE cursorComponentes CURSOR FOR SELECT comp_componente FROM Composicion WHERE comp_producto = @producto
        OPEN cursorComponentes
        FETCH cursorComponentes INTO @comp
        SELECT @suma = (SELECT isnull(SUM(comp_cantidad * prod_precio),0) FROM Composicion JOIN Producto ON comp_componente = prod_codigo WHERE comp_producto = @producto)
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @suma = @suma + dbo.ej15(@comp)
            FETCH cursorComponentes INTO @comp
        END
        CLOSE cursorComponentes
        DEALLOCATE cursorComponentes
    END
    ELSE
        SELECT @suma = prod_precio FROM Producto WHERE prod_codigo = @producto
    
return @suma
END

GO
select prod_codigo, prod_detalle, dbo.ej15(prod_codigo), prod_precio
from Producto

-- 16. Desarrolle el/los elementos de base de datos necesarios para que ante una venta
-- automaticamante se descuenten del stock los articulos vendidos. Se descontaran
-- del deposito que mas producto poseea y se supone que el stock se almacena
-- tanto de productos simples como compuestos (si se acaba el stock de los
-- compuestos no se arman combos)
-- En caso que no alcance el stock de un deposito se descontara del siguiente y asi
-- hasta agotar los depositos posibles. En ultima instancia se dejara stock negativo
-- en el ultimo deposito que se desconto.

GO
CREATE OR ALTER TRIGGER venta_reduce_stock ON Item_Factura AFTER INSERT
AS
BEGIN
	DECLARE 
	@producto char(8),
	@cantidad decimal(12,2);
	DECLARE c_inserted CURSOR FOR
	SELECT i.item_producto, i.item_cantidad
	FROM Inserted i;
	OPEN c_inserted;
	FETCH NEXT FROM c_inserted INTO @producto, @cantidad;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC dbo.descontar_stock @producto, @cantidad;
		FETCH NEXT FROM c_inserted INTO @producto, @cantidad;
	END
	CLOSE c_inserted;
	DEALLOCATE c_inserted;
END

GO
CREATE OR ALTER PROCEDURE descontar_stock(@producto char(8), @cantidad decimal(12,2)) 
AS 
BEGIN
	DECLARE @depo char(2), 
	@restante decimal(12,2) = @cantidad,
	@deposito char(8),
	@stock_actual decimal(12,2);
	DECLARE c_depositos CURSOR FOR
	SELECT stoc_deposito, stoc_cantidad
	FROM STOCK
	WHERE stoc_producto = @producto
	ORDER BY stoc_cantidad DESC;
	OPEN c_depositos;
	FETCH NEXT FROM c_depositos INTO @deposito, @stock_actual;
	WHILE @@FETCH_STATUS = 0 AND @restante > 0
	BEGIN
		DECLARE @descuento decimal(12,2) = 
			CASE
			WHEN @stock_actual >= @restante THEN @restante
			ELSE @stock_actual
		END;
		UPDATE STOCK
		SET stoc_cantidad = stoc_cantidad - @descuento
		WHERE stoc_producto = @producto AND stoc_deposito = @deposito;
		SET @restante -= @descuento;
        select @depo = @deposito
        FETCH NEXT FROM c_depositos INTO @deposito, @stock_actual;
	END
	CLOSE c_depositos;
	DEALLOCATE c_depositos;
	IF @restante > 0
	BEGIN
		UPDATE STOCK
		SET stoc_cantidad = stoc_cantidad - @restante
		WHERE stoc_producto = @producto
		AND stoc_deposito = @depo
	END
END
GO

-- 17. Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto
-- que se debe almacenar en el deposito y que el stock maximo es la maxima
-- cantidad de ese producto en ese deposito, cree el/los objetos de base de datos
-- necesarios para que dicha regla de negocio se cumpla automaticamente. No se
-- conoce la forma de acceso a los datos ni el procedimiento por el cual se
-- incrementa o descuenta stock

GO
CREATE TRIGGER ej_t17 ON STOCK AFTER INSERT, UPDATE
AS
BEGIN
  IF (select count(*) from inserted where stoc_cantidad < stoc_punto_reposicion or stoc_cantidad > stoc_stock_maximo) > 0
  BEGIN
    PRINT 'NO CUMPLE LA REGLA DE NEGOCIO'
  END
END

-- 18. Sabiendo que el limite de credito de un cliente es el monto maximo que se le
-- puede facturar mensualmente, cree el/los objetos de base de datos necesarios
-- para que dicha regla de negocio se cumpla automaticamente. No se conoce la
-- forma de acceso a los datos ni el procedimiento por el cual se emiten las facturas

GO
CREATE TRIGGER ej_t18 ON Factura AFTER INSERT
AS
BEGIN
  IF exists (select fact_cliente from Cliente join inserted i on i.fact_cliente = clie_codigo
              where clie_limite_credito < (
                                            select sum(i.fact_total)+( 
                                                                      select sum(fact_total) 
                                                                      from Factura 
                                                                      where clie_codigo = fact_cliente 
                                                                      and year(fact_fecha) = year(i.fact_fecha) 
                                                                      and month(fact_fecha) = MONTH(i.fact_fecha)
                                                                    )
                                            from inserted i where i.fact_cliente = clie_codigo
                                            group by i.fact_fecha)
              )
  BEGIN
    PRINT 'SUPERA EL LIMITE DE CREDITO'
    ROLLBACK
  END
END

-- 19. Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente
-- regla de negocio automáticamente “Ningún jefe puede tener menos de 5 años de
-- antigüedad y tampoco puede tener más del 50% del personal a su cargo
-- (contando directos e indirectos) a excepción del gerente general”. Se sabe que en
-- la actualidad la regla se cumple y existe un único gerente general.
GO
CREATE TRIGGER ej_t19 ON Empleado FOR INSERT, UPDATE, DELETE
AS
BEGIN
  IF EXISTS (SELECT 1 FROM Empleado WHERE empl_codigo IN (
                                                            SELECT empl_jefe 
                                                            FROM Empleado
                                                          ) 
    AND DATEDIFF(year, empl_ingreso, GETDATE()) > 5 
    OR dbo.ej11(empl_codigo) > (SELECT count(*)/2 FROM Empleado))
  BEGIN
    PRINT 'NO CUMPLE LA REGLA'
  END
END

-- 20. Crear el/los objeto/s necesarios para mantener actualizadas las comisiones del
-- vendedor.
-- El cálculo de la comisión está dado por el 5% de la venta total efectuada por ese
-- vendedor en ese mes, más un 3% adicional en caso de que ese vendedor haya
-- vendido por lo menos 50 productos distintos en el mes.
GO
CREATE PROCEDURE ej_t20
AS
BEGIN
  UPDATE Empleado
  set empl_comision = 
  CASE
    WHEN (select count(distinct item_cantidad) from Item_Factura) >= 50 THEN (select sum(fact_total) from Empleado join Factura on empl_codigo = fact_vendedor where month(fact_fecha) = month(fact_fecha) - 30) * 0.08
    ELSE (select sum(fact_total) from Empleado join Factura on empl_codigo = fact_vendedor where month(fact_fecha) = month(fact_fecha) - 30) * 0.05
  END
END


-- PRACTICA DE PARCIAL EN CLASE --

/*
  2. Realizar un stored procedure que calcule e informe la comisión de un vendedor para un determinado mes.
Los parámetros de entrada es código de vendedor, mes y año.
El criterio para calcular la comisión es: 5% del total vendido tomando como importe base el valor de la factura
sin los impuestos del mes a comisionar, a esto se le debe sumar un plus de 3% más en el caso de que sea el vendedor
que más vendió los productos nuevos en comparación al resto de los vendedores, es decir este plus se le aplica solo
a un vendedor y en caso de igualdad se le otorga al que posea el código de vendedor más alto.

Se considera que un producto es nuevo cuando su primera venta en la empresa se produjo durante el mes en curso
o en alguno de los 4 meses anteriores. De no haber ventas de productos nuevos en ese periodo, ese plus nunca se aplica. */ 

GO
CREATE PROCEDURE calculo_comision @vendedor numeric(6), @mes smalldatetime, @anio smalldatetime, @comision numeric(12,2) OUTPUT
AS
BEGIN
  IF @vendedor = 
  (
    select top 1 fact_vendedor
    from Factura join Item_Factura on item_sucursal+item_tipo+item_numero=fact_sucursal+fact_tipo+fact_numero
    where fact_fecha >= GETDATE()-120 and item_producto not in (
      select distinct item_producto 
      from Item_Factura 
      join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
      where fact_fecha < GETDATE()-120
    )
    group by fact_vendedor
    order by sum(item_cantidad*item_precio) desc, fact_vendedor desc --Creo que se podria solo ordenar por item_cantidad porque solo pide cantidad de ventas
  )
  select @comision = 
                    (
                      select sum(fact_total-fact_total_impuestos) 
                      from Factura 
                      where YEAR(fact_fecha) = @anio 
                      and MONTH(fact_fecha) = @mes 
                      and fact_vendedor = @vendedor
                    )*0.8
  ELSE
  select @comision = 
                    (
                      select sum(fact_total-fact_total_impuestos) 
                      from Factura 
                      where YEAR(fact_fecha) = @anio 
                      and MONTH(fact_fecha) = @mes 
                      and fact_vendedor = @vendedor
                    )*0.5 
END

-- 21. Desarrolle el/los elementos de base de datos necesarios para que se cumpla
-- automaticamente la regla de que en una factura no puede contener productos de
-- diferentes familias. En caso de que esto ocurra no debe grabarse esa factura y
-- debe emitirse un error en pantalla
GO
create or alter trigger ej_t21 on item_factura for INSERT
AS
BEGIN
  if exists (
              select * 
              from inserted i
              where i.item_tipo+i.item_numero+i.item_sucursal in 
              (
                select item_tipo+item_numero+item_sucursal
                from Item_Factura
                join Producto on item_producto = prod_codigo
                group by item_tipo+item_numero+item_sucursal
                HAVING count(distinct prod_familia) > 1
              )
            )
    BEGIN
      RAISERROR('NO CUMPLE LA REGLA', 1, 1)
      DELETE from Factura where fact_tipo+fact_numero+fact_sucursal in 
      (
        select item_tipo+item_numero+item_sucursal
        from Item_Factura
        join Producto on item_producto = prod_codigo
        group by item_tipo+item_numero+item_sucursal
        HAVING count(distinct prod_familia) > 1
      )

      DELETE from Item_Factura where item_tipo+item_numero+item_sucursal in 
      (
        select item_tipo+item_numero+item_sucursal
        from Item_Factura
        join Producto on item_producto = prod_codigo
        group by item_tipo+item_numero+item_sucursal
        HAVING count(distinct prod_familia) > 1
      )
    END
END

-- 22. Se requiere recategorizar los rubros de productos, de forma tal que nigun rubro
-- tenga más de 20 productos asignados, si un rubro tiene más de 20 productos
-- asignados se deberan distribuir en otros rubros que no tengan mas de 20
-- productos y si no entran se debra crear un nuevo rubro en la misma familia con
-- la descirpción “RUBRO REASIGNADO”, cree el/los objetos de base de datos
-- necesarios para que dicha regla de negocio quede implementada.
GO
CREATE PROCEDURE ej22
AS
BEGIN
  declare @rubro char(4), @cantProductos int
  declare c1 cursor for select rubr_id, count(prod_codigo)  from Producto join Rubro on rubr_id = prod_rubro group by rubr_id
  open c1
  fetch c1 into @rubro, @cantProductos
  while @@FETCH_STATUS = 0
  BEGIN
    if @cantProductos > 20
    BEGIN
      EXEC reasignar_rubro @rubro, @cantProductos
    END
    fetch c1 into @rubro, @cantProductos
  END
END

GO
CREATE or ALTER PROCEDURE reasignar_rubro (@rubro char(4), @cantidadProductos int)
AS
BEGIN
declare @cant int, @prod char(8), @nuevoRubro char(4)
  declare cursor_productos cursor for select prod_codigo from Producto where prod_rubro = @rubro
  open cursor_productos
  fetch cursor_productos into @prod
  while @@FETCH_STATUS=0
  BEGIN
    select top 1 @nuevoRubro=rubr_id from Rubro join Producto on rubr_id=prod_rubro where rubr_detalle <> 'RUBRO REASIGNADAO' group by rubr_id having count(prod_codigo) < 20
    if @nuevoRubro is not NULL
    BEGIN
      update Producto set prod_rubro = @nuevoRubro where prod_codigo = @prod
    END
    ELSE
    if not exists (select rubr_id from Rubro where rubr_detalle = 'RUBRO REASIGNADO')
    BEGIN
      insert into Rubro (rubr_detalle)
      VALUES ('RUBRO REASIGNADO')
    update Producto set prod_rubro = (select rubr_id from Rubro where rubr_detalle = 'RUBRO REASIGNADO') where prod_codigo = @prod
    END
    set @cantidadProductos= @cantidadProductos - 1
    FETCH cursor_productos into @prod
  END
  close cursor_productos
  DEALLOCATE cursor_productos
END

-- 23. Desarrolle el/los elementos de base de datos necesarios para que ante una venta
-- automaticamante se controle que en una misma factura no puedan venderse más
-- de dos productos con composición. Si esto ocurre debera rechazarse la factura.

GO
create trigger ej_t23 on item_factura for insert
AS
BEGIN
  if exists ( select * 
              from inserted i 
              where i.item_tipo+i.item_numero+i.item_sucursal in 
              (
                select fact_tipo+fact_numero+fact_sucursal
                from Factura
                join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
                join Producto on prod_codigo=item_producto
                where prod_codigo in (select comp_producto from Composicion)
                group by fact_tipo+fact_numero+fact_sucursal
                having count(distinct prod_codigo) = 2
              )
            )
  BEGIN
    PRINT'Ya se encuentran 2 productos compuestos en la factura, se procede con la eliminacion'
    delete from Factura where fact_tipo+fact_numero+fact_sucursal in 
    (
      select fact_tipo+fact_numero+fact_sucursal
      from Factura
      join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
      join Producto on prod_codigo=item_producto
      where prod_codigo in (select comp_producto from Composicion)
      group by fact_tipo+fact_numero+fact_sucursal
      having count(distinct prod_codigo) = 2
    )
    delete from Item_Factura where item_tipo+item_numero+item_sucursal in
    (
      select fact_tipo+fact_numero+fact_sucursal
      from Factura
      join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
      join Producto on prod_codigo=item_producto
      where prod_codigo in (select comp_producto from Composicion)
      group by fact_tipo+fact_numero+fact_sucursal
      having count(distinct prod_codigo) = 2
    )
  END
END

-- 24. Se requiere recategorizar los encargados asignados a los depositos. Para ello
-- cree el o los objetos de bases de datos necesarios que lo resueva, teniendo en
-- cuenta que un deposito no puede tener como encargado un empleado que
-- pertenezca a un departamento que no sea de la misma zona que el deposito, si
-- esto ocurre a dicho deposito debera asignársele el empleado con menos
-- depositos asignados que pertenezca a un departamento de esa zona.

GO
create procedure ej_t24
AS
BEGIN
  declare @encargado numeric(6), @zona char(3), @nuevoEncargado numeric(6)
  declare curs_deposito cursor for select depo_encargado, depo_zona 
                                   from DEPOSITO 
                                   join Empleado on depo_encargado = empl_codigo
                                   join Departamento on depa_codigo = empl_departamento
                                   where depa_zona <> depo_zona

  open curs_deposito
  fetch curs_deposito into @encargado, @zona
  while @@FETCH_STATUS=0
  BEGIN
    select top 1 @nuevoEncargado=depo_encargado 
    from DEPOSITO 
    join Empleado on depo_encargado = empl_codigo 
    join Departamento on depa_zona = @zona
    group by depo_encargado
    order by count(*) desc

    update DEPOSITO set depo_encargado = @nuevoEncargado where depo_zona = @zona

    fetch curs_deposito into @encargado, @zona
  END
  close curs_deposito
  DEALLOCATE curs_deposito
END

-- 25. Desarrolle el/los elementos de base de datos necesarios para que no se permita
-- que la composición de los productos sea recursiva, o sea, que si el producto A
-- compone al producto B, dicho producto B no pueda ser compuesto por el
-- producto A, hoy la regla se cumple.

GO
CREATE FUNCTION validarRecursividad(@producto char(8)) 
returns int
AS
BEGIN
  declare cursor_componente cursor for select comp_componente from Composicion where comp_producto=@producto
  declare @componente char(8), @esRecursivo int
  open cursor_componente
  fetch cursor_componente into @componente
  while @@FETCH_STATUS = 0
  BEGIN
    if exists (select * from Composicion where comp_producto = @componente)
    BEGIN
      set @esRecursivo = 1
    END
    ELSE
    BEGIN
      set @esRecursivo = 0
    END
    FETCH cursor_componente into @componente
  END
  CLOSE cursor_componente 
  DEALLOCATE cursor_componente
END

GO
CREATE TRIGGER ej25 on Composicion for INSERT
AS
BEGIN
  if exists (select * from inserted i where dbo.validarRecursividad(i.comp_componente) = 1)
  ROLLBACK
END 

select * from Composicion
