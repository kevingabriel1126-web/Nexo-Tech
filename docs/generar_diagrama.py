# Diagrama entidad-relación de la base EcommerceBanfield (Graphviz)
T={
'Roles':[('IdRol','PK'),('Nombre',''),('Descripcion','')],
'RolPermisos':[('IdRol','PK,FK'),('Permiso','PK')],
'Empleados':[('IdEmpleado','PK'),('Usuario',''),('NombreCompleto',''),('IdRol','FK'),('ClaveSalt / ClaveHash',''),('Activo','')],
'Categorias':[('IdCategoria','PK'),('Nombre','')],
'TiposProducto':[('IdTipo','PK'),('Codigo',''),('Nombre','')],
'Productos':[('IdProducto','PK'),('Nombre',''),('IdCategoria','FK'),('IdTipo','FK'),('Marca / Anio',''),('PrecioNeto / CostoNeto',''),('IvaPorcentaje',''),('DescuentoPorcentaje',''),('Stock',''),('Activo',''),('PrecioPublico, PrecioFinal (calculados)','')],
'Versiones':[('IdVersion','PK'),('Nombre',''),('Orden','')],
'Colores':[('IdColor','PK'),('Nombre','')],
'ProductoVersiones':[('IdProducto','PK,FK'),('IdVersion','PK,FK')],
'ProductoColores':[('IdProducto','PK,FK'),('IdColor','PK,FK')],
'Clientes':[('IdCliente','PK'),('Nombre',''),('Email',''),('ClaveSalt / ClaveHash (opcional)',''),('FechaCuenta','')],
'Pedidos':[('IdPedido','PK'),('IdCliente','FK'),('Fecha',''),('Estado',''),('Retiro / DireccionEntrega',''),('Subtotal, Descuento, Envio',''),('Neto, Iva, Total','')],
'DetallePedido':[('IdDetalle','PK'),('IdPedido','FK'),('IdProducto','FK'),('IdVersion','FK'),('IdColor','FK'),('Cantidad',''),('PrecioNetoUnitario',''),('CostoUnitario',''),('IvaPorcentaje',''),('TotalLinea (calculado)','')],
'Suscriptores':[('IdSuscriptor','PK'),('Email',''),('Fecha','')],
'Arrepentimientos':[('IdArrepentimiento','PK'),('Nombre / Email',''),('MontoReembolso',''),('NumeroCompra',''),('IdPedido','FK'),('Estado',''),('Fecha','')],
'Parametros':[('Clave','PK'),('Valor',''),('Descripcion','')],
}
GRP={'Roles':'a','RolPermisos':'a','Empleados':'a','Categorias':'c','TiposProducto':'c','Productos':'c','Versiones':'c','Colores':'c','ProductoVersiones':'c','ProductoColores':'c','Clientes':'v','Pedidos':'v','DetallePedido':'v','Suscriptores':'o','Arrepentimientos':'o','Parametros':'o'}
HEAD={'a':'#0A2A18','c':'#0A6B36','v':'#0E8A47','o':'#4B5F53'}
EDGES=[('RolPermisos','Roles'),('Empleados','Roles'),('Productos','Categorias'),('Productos','TiposProducto'),('ProductoVersiones','Productos'),('ProductoVersiones','Versiones'),('ProductoColores','Productos'),('ProductoColores','Colores'),('Pedidos','Clientes'),('DetallePedido','Pedidos'),('DetallePedido','Productos'),('DetallePedido','Versiones'),('DetallePedido','Colores'),('Arrepentimientos','Pedidos')]
def node(n):
    rows=''.join('<TR><TD ALIGN="LEFT" PORT="%s"><FONT POINT-SIZE="11">%s</FONT></TD><TD ALIGN="RIGHT"><FONT POINT-SIZE="9" COLOR="#0A6B36"><B>%s</B></FONT></TD></TR>'%(c.split()[0].replace(',',''),c,(k or '&nbsp;')) for c,k in T[n])
    return '  %s [label=<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="4" BGCOLOR="white" COLOR="#9BB0A2"><TR><TD COLSPAN="2" BGCOLOR="%s"><FONT COLOR="white" POINT-SIZE="13"><B>%s</B></FONT></TD></TR>%s</TABLE>>];'%(n,HEAD[GRP[n]],n,rows)
dot='digraph ER {\n  graph [rankdir=TB, bgcolor="white", nodesep=0.45, ranksep=0.7, pad=0.3, fontname="Helvetica"];\n  node [shape=plain, fontname="Helvetica"];\n  edge [color="#5D6E63", arrowhead=tee, arrowtail=crow, dir=both, penwidth=1.2];\n'
dot+='\n'.join(node(n) for n in T)+'\n'
for a,b in EDGES: dot+='  %s -> %s;\n'%(a,b)
dot+='}\n'
open('er.dot','w').write(dot)
