SELECT f.fact_vendedor,
p.prod_familia,
count(distinct p.prod_envase) 'CANT. ENVASES',
sum(i.item_cantidad) 'CANT. VENDIDOS'
from Factura f
join Item_Factura i on i.item_tipo+i.item_numero+i.item_sucursal=fact_tipo+fact_numero+fact_sucursal
join Producto p on p.prod_codigo = i.item_producto
where prod_familia =    (
                            select top 1 prod_familia
                            from Producto
                            join Item_Factura on item_producto = prod_codigo
                            join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
                            where fact_vendedor = f.fact_vendedor
                            group by prod_familia
                            order by sum(item_cantidad*item_precio) desc
                        )
and f.fact_vendedor in
(
    select fact_vendedor
    from Factura
    group by fact_vendedor
    having count(distinct fact_cliente) > 100   
)
GROUP by f.fact_vendedor, p.prod_familia
order by count(distinct f.fact_cliente)


GO
create TRIGGER validar_vendedor on Factura for insert
as
BEGIN
    declare @cliente char(6), @vendedor numeric(6), @mejorVendedor numeric(6)
    declare c1 cursor for select i.fact_cliente, i.fact_vendedor from inserted i
    open c1
    FETCH c1 into @cliente, @vendedor
    while @@FETCH_STATUS=0
    BEGIN
        select top 1 @mejorVendedor = fact_vendedor from Factura where fact_cliente = @cliente group by fact_vendedor order by count(distinct fact_numero)
        IF @vendedor <> @mejorVendedor
        BEGIN
            RAISERROR('NO SE CUMPLE LA REGLA',1,1)
            DELETE Factura where fact_vendedor = @vendedor and fact_cliente = @cliente
        END
        FETCH c1 into @cliente, @vendedor
    END
    close c1
    DEALLOCATE c1
END

