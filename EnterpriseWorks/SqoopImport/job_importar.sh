#!/bin/bash

# With this script,the connection to MSServer is done using jdbc:sqlserver driver. First, I need the complete structure of the database on hive, therefor I import 
# and truncate the tables. The first execution of the jobs brings all the records from MSServer to hive database, then incremental import is executed, and just 
#new records added by checking the id column for every table

cd /usr/local/sqoop/bin

# Tables
lista_tablas=("CausaCancelacion" "CausasRefacturacion" "CierreVentas" "Configuracion" "ConsecutivoFactura" "ConsecutivoPerdidasTransportacion" "ConsecutivoPreFactura" "EstadoCicloVidaFactura" "EstadoContabilidadFactura" "EstadoFinancieroFactura" "EstadoPrincipalFactura" "Factura" "FacturaCalculosSecundarios" "FacturaProducto" "FacturaProductoProgramaciones" "FacturaResumen" "FacturaServicio" "FacturaTasa" "HistoricoCancelacionFactura" "Inventario" "InventarioMedicion" "InventarioTanque" "PerdidasTransportacion" "PerdidasTransportacionFactura" "Reglas" "TipoFactura" "TipoFacturacion")

# Columns to check with check-column parameter in sqoop job command
lista_columnas=("idCausaCancelacion" "idCausaRefacturacion" "idCierreVentas" "idConfiguracion" "consecutivoFactura" "consecutivoPerdidasTransportacion" "consecutivoPreFactura" "idEstadoCicloVidaFactura" "idEstadoContabilidad" "idEstadoFinanciero" "idEstadoPrincipal" "idFactura" "idFacturaCalculosSecundarios" "idFacturaProducto" "idProgramacion" "idFacturaResumen" "idFacturaServicio" "idTasa" "idHistoricoCancelacionFactura" "idInventario" "idMedicion" "idInventarioTanque" "idPerdidasTransportacion" "idPerdidasTransportacionFactura" "idReglaNegocioFactura" "idTipoFactura" "idTipoFacturacion")

# target dir
target=hdfs://localhost:54310/user/hive/warehouse/facturacion.db/

: '
for((i=0;i<${#lista_tablas[@]};i++))
do
   tabla=${lista_tablas[$i]}
   tabla1=${tabla,,} # to lower case 
   
   # Import and truncate the tables in hive
   ./sqoop import --bindir ./ --connect "jdbc:sqlserver://172.18.200.75;database=SIOC" \
			   --driver com.microsoft.sqlserver.jdbc.SQLServerDriver \
			   --username sa --password-file file:///home/hduser/sqoop.password \
			   --table Facturacion.$tabla \
			   --target-dir $target$tabla1 \
			   --hive-import -m 1 --fields-terminated-by ','
		   
   cd /usr/local/hive/bin
   #./hive -e "use facturacion;"  
   ./hive -e "use facturacion; truncate table $tabla;"   
    
   # Creating one job for every table 
   cd /usr/local/sqoop/bin
   ./sqoop job --create job.$tabla -- import --bindir ./ --connect "jdbc:sqlserver://172.18.200.75;database=SIOC" \
			   --driver com.microsoft.sqlserver.jdbc.SQLServerDriver \
			   --username sa --password-file file:///home/hduser/sqoop.password \
			   --table Facturacion.$tabla --check-column ${lista_columnas[$i]} --incremental append -m 1 \
			   --target-dir $target$tabla1 \
			   --fields-terminated-by ','   		

   ./hive -e "use facturacion; Alter table $tabla SET TBLPROPERTIES('EXTERNAL'='TRUE');"
			   			  
done
'

# Executing the jobs
#for((i=0;i<${#lista_tablas[@]};i++))
#do
#   tabla=${lista_tablas[$i]}   
#  ./sqoop job --exec job.$tabla
#  ./sqoop job --exec job.Inventario
#done 

# If necessary delete the jobs
#for((i=0;i<${#lista_tablas[@]};i++))
#do
   #./sqoop job --delete "job"."${lista_tablas[$i]}" 
#done

# --------------------------------------------------------- Algunos comentarios ------------------------------------------------------------------------------

# Si en la primera importacion son muchos datos (Gigas), lo mejor es hacer una copia de la base de datos e importar las tablas truncadas. Luego crear los jobs y 
# ejecutarlos para importar los datos. Asi no se repite el trabajo de importar todos los datos y se ahorra tiempo.
# Otra variante a lo anterior, es dejarlo como esta e importar la tabla no completa, sino con select usando un TOP 1
# Usar last-modified en caso de que las filas de una tabla del origen sean modificadas.

# Definir mejor como se modificaran los Id para identificar a que provincia pertenecen los datos. Es mejor hacerlo en el RDMS, no en Hive

			   
