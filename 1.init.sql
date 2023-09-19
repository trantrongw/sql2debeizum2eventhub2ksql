--Preparation	
CREATE USER [debezum-sqlcdc] WITH PASSWORD ='Abcd1234!'
GO
ALTER ROLE [db_owner] ADD MEMBER [debezum-sqlcdc]
GO
EXEC sys.sp_cdc_enable_db
GO
CREATE TABLE [dbo].[Stock](
	[Stock_Code] [varchar](10),
	[Price] [varchar](50) NULL,
CONSTRAINT [PK1] PRIMARY KEY CLUSTERED ([Stock_Code] ASC )
)
CREATE TABLE [dbo].[Customer](
	[Customer_Code] [varchar](10),
	[Name] [varchar](50)
CONSTRAINT [PK2] PRIMARY KEY CLUSTERED ([Customer_Code] ASC )
)
GO
EXEC sys.sp_cdc_enable_table N'dbo', N'Stock', @role_name = null, @supports_net_changes=0
EXEC sys.sp_cdc_enable_table N'dbo', N'Customer', @role_name = null, @supports_net_changes=0
GO
EXEC sys.sp_cdc_help_change_data_capture
GO
--remove cdc table
EXECUTE sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'SampleCDC',
    @capture_instance = N'dbo_SampleCDC';

--create data
INSERT INTO [dbo].[CUSTOMER]([Customer_Code],[Name]) VALUES('C001','Jame')
INSERT INTO [dbo].[CUSTOMER]([Customer_Code],[Name]) VALUES('C002','Dave')
INSERT INTO [dbo].[Stock]([Stock_Code],[Price]) VALUES('AAM',100)
INSERT INTO [dbo].[Stock]([Stock_Code],[Price]) VALUES('ABR',200)