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