# sqlserver_auditdb

Scripts para auditar cambios estructurales y en datos de bases de datos SQL Server


CREATE DATABASE [AuditDB]
 	ON  PRIMARY ( 
		NAME = N'AuditDB', FILENAME = N'C:\Database\AuditDB.mdf'
	)
	LOG ON ( 
		NAME = N'AuditDB_log', FILENAME = N'C:\Database\AuditDB_log.ldf' 
	)
GO

/* TABLA PARA AUDITAR LOS CAMBIOS EN LOS DATOS */
USE [AuditDB]
GO

CREATE TABLE [dbo].[DataEvents](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[EventDate] [datetime2](7) NOT NULL,
	[TableName] [varchar](200) NOT NULL,
	[Operation] [char](1) NOT NULL,
	[Data] [xml] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[DataEvents] ADD  CONSTRAINT [DF__Log_Fecha]  DEFAULT (getdate()) FOR [EventDate]
GO

/* TABLA PARA AUDITAR LOS CAMBIOS ESTRUCTURALES */

CREATE TABLE [dbo].[DDLEvents](
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
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[DDLEvents] ADD  CONSTRAINT [DF__DDLEvents__Event__36B12243]  DEFAULT (getdate()) FOR [Date]
GO

/* TRIGGER DE BASE DE DATOS PARA AUDITAR LOS CAMBIOS ESTRUCTURALES*/

USE [Config]
GO

CREATE TRIGGER [DDLTrigger]  ON DATABASE FOR DDL_DATABASE_LEVEL_EVENTS AS BEGIN
    SET NOCOUNT ON;
    DECLARE
        @EventData XML = EVENTDATA();
 
    DECLARE @ip varchar(48) = CONVERT(varchar(48), 
        CONNECTIONPROPERTY('client_net_address'));
 
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
        @EventData.value('(/EVENT_INSTANCE/EventType)[1]',   'NVARCHAR(100)'), 
        @EventData.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'NVARCHAR(MAX)'),
        DB_NAME(),
        @EventData.value('(/EVENT_INSTANCE/SchemaName)[1]',  'NVARCHAR(255)'), 
        @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]',  'NVARCHAR(255)'),
        HOST_NAME(),
        @ip,
        PROGRAM_NAME(),
        SUSER_SNAME();
END
GO

ENABLE TRIGGER [DDLTrigger] ON DATABASE
GO


/* CREACION DE TRIGGER DE AUDITORIA DE DATOS EN TODAS LAS TABLAS DE LA BASE DE DATOS SELECCIONADA */

USE [NAME]

declare items cursor for SELECT table_name FROM information_schema.tables
declare @name varchar(max)
declare @dbName varchar(max)
select @dbName = DB_NAME() 

print 'CREACION DE TRIGGERS EN: ' + @dbName

OPEN items 
FETCH NEXT FROM items INTO @name

WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT @name
	IF NOT EXISTS (select * from sysobjects where name = @name + 'Audit') BEGIN
		DECLARE @trigger varchar(MAX)

		SELECT @trigger = '
			CREATE TRIGGER [dbo].[' + @name + 'Audit] ON [dbo].[' + @name + '] AFTER DELETE, UPDATE, INSERT AS BEGIN
				SET NOCOUNT ON;
				DECLARE @COUNT INT 
				SELECT @COUNT = COUNT(*) FROM DELETED
				IF @COUNT > 0 BEGIN 
					INSERT INTO AuditDB.dbo.dataevents (Operation, TableName, [Data])
						SELECT ''D'', 
						''' + @name + ''', 
						(SELECT * FROM deleted for xml path(''' + @name + '''), type, elements absent)
				END
				SELECT @COUNT = COUNT(*) FROM INSERTED
				IF @COUNT > 0 BEGIN 
					INSERT INTO AuditDB.dbo.dataevents (Operation, TableName, [Data])
						SELECT ''I'', 
						''' + @name + ''', 
						(SELECT * FROM inserted for xml path(''' + @name + '''),type,elements absent)
				END
			END'
		print @trigger

		EXEC(@trigger)

	END
	FETCH NEXT FROM items INTO @name
END

CLOSE items
DEALLOCATE items
