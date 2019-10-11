/****** Object:  PartitionFunction [pf_af]     ******/
CREATE PARTITION FUNCTION [pf_af](int) AS RANGE LEFT FOR VALUES (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24)
GO
/****** Object:  PartitionScheme [ps_af]     ******/
CREATE PARTITION SCHEME [ps_af] AS PARTITION [pf_af] TO ([PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY])
GO
/****** Object:  UserDefinedTableType [dbo].[payloadType]     ******/
CREATE TYPE [dbo].[payloadType] AS TABLE(
	[EventId] [uniqueidentifier] NOT NULL,
	[ComplexData] [nvarchar](max) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[Type] [varchar](10) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL,
	PRIMARY KEY NONCLUSTERED 
(
	[EventId] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
/****** Object:  UserDefinedTableType [dbo].[payloadType_mo]     ******/
CREATE TYPE [dbo].[payloadType_mo] AS TABLE(
	[EventId] [uniqueidentifier] NOT NULL,
	[ComplexData] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[DeviceId] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[Type] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL,
	 PRIMARY KEY NONCLUSTERED HASH 
(
	[EventId]
)WITH ( BUCKET_COUNT = 128)
)
WITH ( MEMORY_OPTIMIZED = ON )
GO
/****** Object:  Table [dbo].[rawdata_cs_mo]     ******/
CREATE TABLE [dbo].[rawdata_cs_mo]
(
	[BatchId] [uniqueidentifier] NOT NULL,
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeviceId] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL,

/****** Object:  Index [ixcc]     ******/
INDEX [ixcc] CLUSTERED COLUMNSTORE WITH (COMPRESSION_DELAY = 0),
 CONSTRAINT [pk__rawdata_cs_mo]  PRIMARY KEY NONCLUSTERED HASH 
(
	[EventId]
)WITH ( BUCKET_COUNT = 1048576)
)WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_AND_DATA )
GO
/****** Object:  StoredProcedure [dbo].[stp_WriteData_cs_mo]     ******/
create procedure [dbo].[stp_WriteData_cs_mo] 
@payload as dbo.payloadType_mo readonly
with native_compilation, schemabinding, execute as owner  
as 
begin atomic with (transaction isolation level = snapshot,  language = 'english')  
 
declare @buid uniqueidentifier = newId() 

insert into dbo.rawdata_cs_mo
	([BatchId], [EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId], [StoredAt])
select
	@buid as BatchId, 	
	[EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId],
	sysutcdatetime() as StoredAt
from
	@payload

end
GO
/****** Object:  Table [dbo].[rawdata_mo]     ******/
CREATE TABLE [dbo].[rawdata_mo]
(
	[BatchId] [uniqueidentifier] NOT NULL,
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeviceId] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL,

INDEX [ixnc1] NONCLUSTERED 
(
	[ProcessedAt] DESC
),
 CONSTRAINT [pk__rawdata_mo]  PRIMARY KEY NONCLUSTERED HASH 
(
	[EventId]
)WITH ( BUCKET_COUNT = 1048576)
)WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_AND_DATA )
GO
/****** Object:  StoredProcedure [dbo].[stp_WriteData_mo]     ******/


create procedure [dbo].[stp_WriteData_mo] 
@payload as dbo.payloadType_mo readonly
with native_compilation, schemabinding, execute as owner  
as 
begin atomic with (transaction isolation level = snapshot,  language = 'english')  
 
declare @buid uniqueidentifier = newId() 

insert into dbo.rawdata_mo
	([BatchId], [EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId], [StoredAt])
select
	@buid as BatchId, 	
	[EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId],
	sysutcdatetime() as StoredAt
from
	@payload

end
GO
/****** Object:  Table [dbo].[rawdata]     ******/
CREATE TABLE [dbo].[rawdata](
	[BatchId] [uniqueidentifier] NOT NULL,
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](max) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL,
 CONSTRAINT [pk__rawdata] PRIMARY KEY NONCLUSTERED 
(
	[EventId] ASC,
	[PartitionId] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [ps_af]([PartitionId])
) ON [ps_af]([PartitionId])
GO
/****** Object:  Table [dbo].[rawdata_cs]     ******/
CREATE TABLE [dbo].[rawdata_cs](
	[BatchId] [uniqueidentifier] NOT NULL,
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](max) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL,
 CONSTRAINT [pk__rawdata_cs] PRIMARY KEY NONCLUSTERED 
(
	[EventId] ASC,
	[PartitionId] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [ps_af]([PartitionId])
) ON [ps_af]([PartitionId])
GO
/****** Object:  Table [dbo].[staging_table]     ******/
CREATE TABLE [dbo].[staging_table](
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](max) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL
) ON [ps_af]([PartitionId])
GO
/****** Object:  Index [ixccs]     ******/
CREATE CLUSTERED COLUMNSTORE INDEX [ixccs] ON [dbo].[rawdata_cs] WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [ps_af]([PartitionId])
GO
/****** Object:  Index [ixcc]     ******/
GO
ALTER TABLE [dbo].[rawdata]  WITH NOCHECK ADD CHECK  ((isjson([ComplexData])=(1)))
GO
ALTER TABLE [dbo].[rawdata_cs]  WITH CHECK ADD CHECK  ((isjson([ComplexData])=(1)))
GO
ALTER TABLE [dbo].[rawdata_cs_mo]  WITH CHECK ADD CHECK  ((isjson([ComplexData])=(1)))
GO
ALTER TABLE [dbo].[rawdata_mo]  WITH CHECK ADD CHECK  ((isjson([ComplexData])=(1)))
GO
/****** Object:  StoredProcedure [dbo].[stp_WriteData]     ******/


create procedure [dbo].[stp_WriteData] 
@payload as dbo.payloadType readonly
as

declare @buid uniqueidentifier = newId() 

insert into dbo.rawdata 
	([BatchId], [EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId], [StoredAt])
select
	@buid as BatchId, 	
	[EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId],
	sysutcdatetime() as StoredAt
from
	@payload
GO
/****** Object:  StoredProcedure [dbo].[stp_WriteData_cs]     ******/



create procedure [dbo].[stp_WriteData_cs] 
@payload as dbo.payloadType readonly
as

declare @buid uniqueidentifier = newId() 

insert into dbo.rawdata_cs
	([BatchId], [EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId], [StoredAt])
select
	@buid as BatchId, 	
	[EventId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId],
	sysutcdatetime() as StoredAt
from
	@payload
GO
/****** Object:  StoredProcedure [dbo].[stp_WriteDataBatch]     ******/
CREATE procedure [dbo].[stp_WriteDataBatch] 
as
  -- Move events from staging_table to rawdata table.
  -- WARNING: This procedure is non-transactional to optimize performance, and
  --          assumes no concurrent writes into the staging_table during its execution.
  declare @buid uniqueidentifier = newId();

  -- ETL logic: insert events if they do not already exist in destination table
WITH staging_data_with_partition AS
(
	SELECT * 
	FROM dbo.staging_table
)
MERGE dbo.rawdata AS t
    USING (

      -- Deduplicate events from staging table
      SELECT  *
      FROM (SELECT *,
	    ROW_NUMBER() OVER (PARTITION BY PartitionId, EventId ORDER BY EnqueuedAt) AS RowNumber
        FROM staging_data_with_partition
        ) AS StagingDedup
      WHERE StagingDedup.RowNumber = 1

    ) AS s
        ON s.PartitionId = t.PartitionId AND s.EventId = t.EventId

    WHEN NOT MATCHED THEN
        INSERT (PartitionId, EventId, Type, DeviceId, DeviceSequenceNumber, CreatedAt, Value, ComplexData, EnqueuedAt, ProcessedAt, 
			BatchId, StoredAt) 
        VALUES (s.PartitionId, s.EventId, s.Type, s.DeviceId, s.DeviceSequenceNumber, s.CreatedAt, s.Value, s.ComplexData, s.EnqueuedAt, s.ProcessedAt,
			@buid, sysutcdatetime())
        ;

TRUNCATE TABLE dbo.staging_table;
GO
/****** Object:  StoredProcedure [dbo].[stp_WriteDataBatch_cs]     ******/
CREATE procedure [dbo].[stp_WriteDataBatch_cs] 
as
  -- Move events from staging_table to rawdata table.
  -- WARNING: This procedure is non-transactional to optimize performance, and
  --          assumes no concurrent writes into the staging_table during its execution.
  declare @buid uniqueidentifier = newId();

  -- ETL logic: insert events if they do not already exist in destination table
WITH staging_data_with_partition AS
(
	SELECT * 
	FROM dbo.staging_table
)
MERGE dbo.rawdata_cs AS t
    USING (

      -- Deduplicate events from staging table
      SELECT  *
      FROM (SELECT *,
	    ROW_NUMBER() OVER (PARTITION BY PartitionId, EventId ORDER BY EnqueuedAt) AS RowNumber
        FROM staging_data_with_partition
        ) AS StagingDedup
      WHERE StagingDedup.RowNumber = 1

    ) AS s
        ON s.PartitionId = t.PartitionId AND s.EventId = t.EventId

    WHEN NOT MATCHED THEN
        INSERT (PartitionId, EventId, Type, DeviceId, DeviceSequenceNumber, CreatedAt, Value, ComplexData, EnqueuedAt, ProcessedAt, 
			BatchId, StoredAt) 
        VALUES (s.PartitionId, s.EventId, s.Type, s.DeviceId, s.DeviceSequenceNumber, s.CreatedAt, s.Value, s.ComplexData, s.EnqueuedAt, s.ProcessedAt,
			@buid, sysutcdatetime())
        ;

TRUNCATE TABLE dbo.staging_table;
GO


