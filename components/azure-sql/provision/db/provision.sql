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

CREATE TABLE [dbo].[rawdata]
(
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
	) 
) ON [ps_af]([PartitionId])
GO

ALTER TABLE [dbo].[rawdata]  WITH NOCHECK ADD CHECK  ((isjson([ComplexData])=1))
GO

CREATE CLUSTERED INDEX [ixc] ON [dbo].[rawdata] (CreatedAt, PartitionId) ON [ps_af]([PartitionId])
GO

CREATE TABLE [dbo].[rawdata_cs]
(
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
	)
) ON [ps_af]([PartitionId])
GO

ALTER TABLE [dbo].[rawdata_cs]  WITH CHECK ADD CHECK ((isjson([ComplexData])=1))
GO

CREATE CLUSTERED COLUMNSTORE INDEX [ixccs] ON [dbo].[rawdata_cs] ON [ps_af]([PartitionId])
GO

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


