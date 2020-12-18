/*
	database: streaming
*/
declare @p table (pid int);
insert into @p values (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16);

select top (100)
	*
from
	@p p
cross apply
(
	select top (100)
		*
	from
		dbo.[rawdata2] r
	where
		r.[PartitionId] = p.pid
	order by
		[StoredAt] desc
) t
order by
	[StoredAt] desc
go

select top (100)
	*
from
	dbo.[rawdata2] r
where
	[r].[DeviceId] = 'contoso://device-id-154'
and
	r.[PartitionId] = 5
order by
	[StoredAt] desc
