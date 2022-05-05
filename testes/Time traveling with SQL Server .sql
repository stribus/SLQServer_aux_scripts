ALTER TABLE [dbo].[TABELA] ADD
                             [SysStartTime] datetime2(0) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT DF_Inventory_SysStartTime DEFAULT '1900-01-01 00:00:00',
                             [SysEndTime] datetime2(0) GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT DF_Inventory_SysEndTime DEFAULT '9999-12-31 23:59:59',
                             PERIOD FOR SYSTEM_TIME ([SysStartTime], [SysEndTime])
ALTER TABLE [dbo].[TABELA]
                             SET (SYSTEM_VERSIONING = ON);
                             
ALTER TABLE TABELA
DROP CONSTRAINT DF_Inventory_SysStartTime;                             
ALTER TABLE TABELA
DROP CONSTRAINT DF_Inventory_SysEndTime;                             