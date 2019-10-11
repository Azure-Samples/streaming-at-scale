CREATE MASTER KEY
GO
/****** Object:  Table [dbo].[rawdata]     ******/
CREATE TABLE [dbo].[rawdata](
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](4000) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL
)
WITH (DISTRIBUTION = HASH([DeviceId]), CLUSTERED COLUMNSTORE INDEX)
GO
/****** Object:  Table [dbo].[rawdata_cs]     ******/
CREATE TABLE [dbo].[rawdata_cs](
	[EventId] [uniqueidentifier] NOT NULL,
	[Type] [varchar](10) NOT NULL,
	[DeviceId] [varchar](100) NOT NULL,
	[DeviceSequenceNumber] [bigint] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[Value] [numeric](18, 0) NOT NULL,
	[ComplexData] [nvarchar](4000) NOT NULL,
	[EnqueuedAt] [datetime2](7) NOT NULL,
	[ProcessedAt] [datetime2](7) NOT NULL,
	[StoredAt] [datetime2](7) NOT NULL
)
WITH (DISTRIBUTION = HASH([DeviceId]), CLUSTERED COLUMNSTORE INDEX)
GO
