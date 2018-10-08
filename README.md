# sqlserver_auditdb

Scripts para auditar cambios estructurales y en datos de bases de datos SQL Server

Debe establecer el nombre de estas variables y ejecutar

-- nombre de la base de datos de auditoria
DECLARE @db_audit_name VARCHAR(max) = 'AuditDB'

-- ruta para guardar la base de datos de auditoria
DECLARE @db_audit_path VARCHAR(max) = 'c:\Database\'

-- nombre de la base de datos donde se van a crear los trigger de auditoria
DECLARE @db_target     VARCHAR(max) = 'Config'

-- nombre de la tabla para guardar los cambios estructurales de la base de datos
DECLARE @ddl_events_table_name varchar(max) = 'DDLEvents' 

-- nombre de la tabla para guardar los cambios en los datos de la base de datos seleccionada
DECLARE @data_events_table_name varchar(max) = 'DataEvents' 
