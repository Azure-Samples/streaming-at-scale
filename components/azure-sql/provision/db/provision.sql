DROP TABLE IF EXISTS [dbo].[rawdata];
DROP TABLE IF EXISTS [dbo].[rawdata_cs];
DROP PROCEDURE IF EXISTS [dbo].[stp_WriteData];
DROP PROCEDURE IF EXISTS [dbo].[stp_WriteData_cs];
DROP TYPE IF EXISTS [dbo].[payloadType];
BEGIN TRY
	DROP PARTITION SCHEME [ps_af];
END TRY
BEGIN CATCH
END CATCH;
BEGIN TRY
	DROP PARTITION FUNCTION [pf_af];
END TRY
BEGIN CATCH
END CATCH;
GO

ALTER DATABASE [streaming] SET AUTO_UPDATE_STATISTICS_ASYNC ON
GO

CREATE PARTITION FUNCTION [pf_af](int) AS RANGE LEFT FOR VALUES (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
GO

CREATE PARTITION SCHEME [ps_af] AS PARTITION [pf_af] ALL TO ([PRIMARY])
GO

CREATE TYPE [dbo].[payloadType] AS TABLE
(
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
	) 
)
GO

/*
	ROWSTORE
*/
CREATE TABLE [dbo].[rawdata]
(
	[BatchId] [uniqueidentifier] NOT NULL,
	[EventId] [uniqueidentifier] NOT NULL DEFAULT NEWSEQUENTIALID(),
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](max) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL
) ON [ps_af]([PartitionId])
GO

ALTER TABLE [dbo].[rawdata]  WITH NOCHECK ADD CHECK  ((isjson([ComplexData])=1))
GO

CREATE CLUSTERED INDEX [ixc] ON [dbo].[rawdata] ([StoredAt] DESC) WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

ALTER TABLE dbo.[rawdata] 
ADD CONSTRAINT [pk__rawdata] PRIMARY KEY NONCLUSTERED 
	(
		[EventId] ASC,
		[PartitionId] ASC
	)  WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

CREATE NONCLUSTERED INDEX ix1 ON [dbo].[rawdata] ([DeviceId] ASC, [DeviceSequenceNumber] DESC) WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

CREATE NONCLUSTERED INDEX ix2 ON [dbo].[rawdata] ([BatchId]) WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

CREATE OR ALTER PROCEDURE [dbo].[stp_WriteData] 
@payload AS dbo.payloadType READONLY
AS
BEGIN
	declare @buid uniqueidentifier = newId() 

	insert into dbo.rawdata 
		([BatchId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId], [StoredAt])
	select
		@buid as BatchId, 	
		[Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId],
		sysutcdatetime() as StoredAt
	from
		@payload
	;
END
GO

/*
	COLUMNSTORE
*/
CREATE TABLE [dbo].[rawdata_cs]
(
	[BatchId] [uniqueidentifier] NOT NULL,
	[EventId] [uniqueidentifier] NOT NULL DEFAULT NEWSEQUENTIALID(),
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](max) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL,
	[PartitionId] [int] NOT NULL
) ON [ps_af]([PartitionId])
GO

ALTER TABLE [dbo].[rawdata_cs]  WITH CHECK ADD CHECK  ((isjson([ComplexData])=(1)))
GO

CREATE CLUSTERED COLUMNSTORE INDEX [ixccs] ON [dbo].[rawdata_cs] WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [ps_af]([PartitionId])
GO

ALTER TABLE dbo.[rawdata_cs] 
ADD CONSTRAINT [pk__rawdata_cs] PRIMARY KEY NONCLUSTERED 
	(
		[EventId] ASC,
		[PartitionId] ASC
	)  WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

CREATE NONCLUSTERED INDEX ix1 ON [dbo].[rawdata_cs] ([DeviceId], [DeviceSequenceNumber]) WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

CREATE NONCLUSTERED INDEX ix2 ON [dbo].[rawdata_cs] ([BatchId]) WITH (DATA_COMPRESSION = PAGE) ON [ps_af]([PartitionId])
GO

CREATE OR ALTER PROCEDURE [dbo].[stp_WriteData_cs] 
@payload AS dbo.payloadType READONLY
AS
BEGIN
	declare @buid uniqueidentifier = NEWID() 

	insert into dbo.rawdata_cs
		([BatchId], [Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId], [StoredAt])
	select
		@buid as BatchId, 	
		[Type], [DeviceId], [DeviceSequenceNumber], [CreatedAt], [Value], [ComplexData], [ProcessedAt], [EnqueuedAt], [PartitionId],
		sysutcdatetime() as StoredAt
	from
		@payload
	;
END
GO

/*
Batch Processing Objects
*/
CREATE TABLE [dbo].[staging_table]
(
	[EventId] [uniqueidentifier] NOT NULL DEFAULT NEWSEQUENTIALID(),
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

CREATE PROCEDURE [dbo].[stp_WriteDataBatch] 
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
        INSERT (PartitionId, [Type], DeviceId, DeviceSequenceNumber, CreatedAt, [Value], ComplexData, EnqueuedAt, ProcessedAt, 
			BatchId, StoredAt) 
        VALUES (s.PartitionId, s.Type, s.DeviceId, s.DeviceSequenceNumber, s.CreatedAt, s.Value, s.ComplexData, s.EnqueuedAt, s.ProcessedAt,
			@buid, sysutcdatetime())
        ;

TRUNCATE TABLE dbo.staging_table;
GO

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
        INSERT (PartitionId, [Type], DeviceId, DeviceSequenceNumber, CreatedAt, [Value], ComplexData, EnqueuedAt, ProcessedAt, 
			BatchId, StoredAt) 
        VALUES (s.PartitionId, s.Type, s.DeviceId, s.DeviceSequenceNumber, s.CreatedAt, s.Value, s.ComplexData, s.EnqueuedAt, s.ProcessedAt,
			@buid, sysutcdatetime())
        ;

TRUNCATE TABLE dbo.staging_table;
GO
