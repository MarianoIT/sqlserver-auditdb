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

DECLARE @exec varchar(max)

IF NOT EXISTS (select * from sys.databases where name = @db_audit_name) BEGIN
	SET @exec = '
/* CREACION DE BASE DE DATOS DE AUDITORIA */
CREATE DATABASE [' + @db_audit_name + ']
 	ON  PRIMARY ( 
		NAME = N''' + @db_audit_name + ''', FILENAME = N''C:\Database\' + @db_audit_name + '.mdf''
	)
	LOG ON ( 
		NAME = N''' + @db_audit_name + '_log'', FILENAME = N''C:\Database\' + @db_audit_name + '_log.ldf'' 
	)
	
'
	print @exec
	EXEC (@exec)
END


SET @exec = '
/* TABLA PARA AUDITAR LOS CAMBIOS EN LOS DATOS */
USE [' + @db_audit_name + ']
IF NOT EXISTS (select * from sys.tables where name = ''' + @data_events_table_name + ''') BEGIN
	CREATE TABLE [dbo].[' + @data_events_table_name + '](
		[Id] [bigint] IDENTITY(1,1) NOT NULL,
		[Date] [datetime2](7) NOT NULL,
		[TableName] [varchar](200) NOT NULL,
		[Operation] [char](1) NOT NULL,
		[Data] [xml] NOT NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];

	ALTER TABLE [dbo].[' + @data_events_table_name + '] ADD  CONSTRAINT [DF_' + @data_events_table_name + '_Date]  DEFAULT (getdate()) FOR [Date];
END

'
print @exec
EXEC (@exec)

SET @exec = '
/* TABLA PARA AUDITAR LOS CAMBIOS ESTRUCTURALES */
USE [' + @db_audit_name + ']
IF NOT EXISTS (select * from sys.tables where name = ''' + @ddl_events_table_name + ''') BEGIN
	CREATE TABLE [dbo].[' + @ddl_events_table_name + '](
		[Id] [bigint] IDENTITY(1,1) NOT NULL,
		[Date] [datetime] NOT NULL,
		[Type] [nvarchar](64) NULL,
		[DDL] [nvarchar](max) NULL,
		[DatabaseName] [nvarchar](255) NULL,
		[SchemaName] [nvarchar](255) NULL,
		[ObjectName] [nvarchar](255) NULL,
		[HostName] [varchar](64) NULL,
		[IPAddress] [varchar](48) NULL,
		[ProgramName] [nvarchar](255) NULL,
		[LoginName] [nvarchar](255) NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
	ALTER TABLE [dbo].[' + @ddl_events_table_name + '] ADD  CONSTRAINT [DF_' + @ddl_events_table_name + '_DATE]  DEFAULT (getdate()) FOR [Date];
END
'
print @exec
EXEC (@exec)

EXEC ('USE [' + @db_target +']')

SET @exec = '
/* TRIGGER DE BASE DE DATOS PARA AUDITAR LOS CAMBIOS ESTRUCTURALES*/

CREATE TRIGGER [' + @db_target + '_db_audit]  ON DATABASE FOR DDL_DATABASE_LEVEL_EVENTS AS BEGIN
    SET NOCOUNT ON;
    DECLARE
        @EventData XML = EVENTDATA();
 
    DECLARE @ip varchar(48) = CONVERT(varchar(48), 
        CONNECTIONPROPERTY(''client_net_address''));
 
    INSERT AuditDB.dbo.DDLEvents (
        [Type],
        DDL,
        DatabaseName,
        SchemaName,
        ObjectName,
        HostName,
        IPAddress,
        ProgramName,
        LoginName
    )
    SELECT
        @EventData.value(''(/EVENT_INSTANCE/EventType)[1]'',   ''NVARCHAR(100)''), 
        @EventData.value(''(/EVENT_INSTANCE/TSQLCommand)[1]'', ''NVARCHAR(MAX)''),
        DB_NAME(),
        @EventData.value(''(/EVENT_INSTANCE/SchemaName)[1]'',  ''NVARCHAR(255)''), 
        @EventData.value(''(/EVENT_INSTANCE/ObjectName)[1]'',  ''NVARCHAR(255)''),
        HOST_NAME(),
        @ip,
        PROGRAM_NAME(),
        SUSER_SNAME();
END;
'

print @exec
EXEC (@exec)

/* CREACION DE TRIGGER DE AUDITORIA DE DATOS EN TODAS LAS TABLAS DE LA BASE DE DATOS SELECCIONADA */

EXEC ('USE [' + @db_target +']')

DECLARE items CURSOR FOR SELECT table_name FROM information_schema.tables
DECLARE @name VARCHAR(max)				-- el cursor va a instanciar con el nombre de la tabla de la base de datos seleccionada

OPEN items 
FETCH NEXT FROM items INTO @name

WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT @name 
	IF NOT EXISTS (select * from sysobjects where name = @name + 'Audit') BEGIN
		SET @exec = '
CREATE TRIGGER [dbo].[' + @name + 'Audit] ON [dbo].[' + @name + '] AFTER DELETE, UPDATE, INSERT AS BEGIN
	SET NOCOUNT ON;
	DECLARE @COUNT INT 
	SELECT @COUNT = COUNT(*) FROM DELETED
	IF @COUNT > 0 BEGIN 
		INSERT INTO [' + @db_audit_name + '].dbo.[' + @data_events_table_name + '] (Operation, TableName, [Data])
			SELECT ''D'', 
			''' + @name + ''', 
			(SELECT * FROM deleted for xml path(''' + @name + '''), type, elements absent)
	END
	SELECT @COUNT = COUNT(*) FROM INSERTED
	IF @COUNT > 0 BEGIN 
		INSERT INTO [' + @db_audit_name + '].dbo.[' + @data_events_table_name + '] (Operation, TableName, [Data])
			SELECT ''I'', 
			''' + @name + ''', 
			(SELECT * FROM inserted for xml path(''' + @name + '''),type,elements absent)
	END
END'
		print @exec
		EXEC(@exec)

	END
	FETCH NEXT FROM items INTO @name
END

CLOSE items
DEALLOCATE items

