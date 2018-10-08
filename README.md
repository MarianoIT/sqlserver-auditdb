Scripts para auditar cambios estructurales y en datos de bases de datos SQL Server

Debe establecer el nombre de estas variables y ejecutar

@db_audit_name: nombre de la base de datos de auditoria
@db_audit_path: ruta para guardar la base de datos de auditoria
@db_target: nombre de la base de datos donde se van a crear los trigger de auditoria

@ddl_events_table_name: nombre de la tabla para guardar los cambios estructurales de la base de datos
@data_events_table_name: nombre de la tabla para guardar los cambios en los datos de la base de datos seleccionada
