
-- =======
-- = SQL =
-- =======

SELECT rubr_detalle,
count(distinct p.prod_codigo) '#CANT. PRODUCTOS DEL RUBRO',
(
    select count(distinct item_producto)
    from Item_Factura
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    join Producto on item_producto = prod_codigo
    where prod_rubro = rubr_id
    and year(fact_fecha) = 2011
)'#PROD. VENDIDOS EN 2011 DEL RUBRO',
(
    select count(distinct fact_numero)
    from Factura
    join Item_Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    join Producto on prod_codigo = item_producto
    where prod_rubro = rubr_id
) '#FACTURAS CON PRODUCTOS DEL RUBRO',
(
    select top 1 prod_codigo
    from Producto
    join Item_Factura on item_producto = prod_codigo
    join Factura on item_tipo+item_numero+item_sucursal=fact_tipo+fact_numero+fact_sucursal
    where prod_rubro = rubr_id
    group by prod_codigo
    order by sum(item_cantidad) DESC
)'PROD. MAS VENDIDO DEL RUBRO'
from Rubro
join Producto p on p.prod_rubro = rubr_id
join Item_Factura i on i.item_producto = p.prod_codigo
join Factura f on i.item_tipo+i.item_numero+i.item_sucursal = f.fact_tipo+f.fact_numero+f.fact_sucursal
group by rubr_detalle, rubr_id
HAVING rubr_id IN
(
    select rubr_id
    from Rubro
    join Producto on prod_rubro = rubr_id
    group by rubr_id
    having count(prod_codigo) > 100
)
order by count(f.fact_cliente) DESC


-- =========
-- = T-SQL =
-- =========

CREATE TABLE composiciones (
    FILA int,
    PROD1 char(8),
    DETALLE1 char(50),
    COMP1 int,
    COMP2 int,
    VECES int
)

GO
create PROCEDURE completar_composiciones
as
BEGIN
    declare @prod char(8), @componente char(8), @cont_componentes int, @compuesto_detalle char(50), @cont_fila int = 0
    
    DECLARE curs_composiciones cursor for select comp_producto, comp_componente from Composicion
    
    open curs_composiciones 
    FETCH curs_composiciones into @prod, @componente
    while @@FETCH_STATUS=0
    BEGIN
        select @cont_componentes = (select count(comp_componente) from Composicion where comp_producto = @prod)
        select @compuesto_detalle = (select prod_detalle from Producto where prod_codigo = @prod)
        
        declare @componente_del_componente char(8), @cont_composiciones int, @veces_facturado int
        declare curs_componentes cursor for select comp_componente from Composicion where comp_producto = @componente
        
        open curs_componentes
        FETCH curs_componentes into @componente_del_componente
        while @@FETCH_STATUS=0
        BEGIN
            select @cont_composiciones = count(distinct comp_producto) from Composicion where comp_componente = @componente_del_componente
            select @veces_facturado = sum(item_cantidad) from Item_Factura where item_producto = @prod
            select @cont_fila += 1
            
            insert into composiciones(FILA, PROD1, DETALLE1, COMP1, COMP2, VECES)
            VALUES (@cont_fila, @prod, @compuesto_detalle, @cont_componentes, @cont_composiciones, @veces_facturado)
        END
        close curs_componentes
        DEALLOCATE curs_componentes
    END
    close curs_composiciones
    DEALLOCATE curs_composiciones
END
