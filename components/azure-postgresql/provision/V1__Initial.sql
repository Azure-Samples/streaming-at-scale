CREATE TABLE rawdata (
	EventId uuid NOT NULL,
	Type varchar(10) NOT NULL,
	DeviceId varchar(100) NOT NULL,
	DeviceSequenceNumber bigint NOT NULL,
	CreatedAt timestamp NOT NULL,
	Value numeric(18, 0) NOT NULL,
	ComplexData varchar(4000),
	EnqueuedAt timestamp NOT NULL,
	ProcessedAt timestamp NOT NULL,
	StoredAt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
)
