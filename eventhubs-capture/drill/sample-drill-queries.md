**Sample Apache Drill queries**

Show all the available registered and configured data sources:

    show databases;

Show the content of a data source:

    show files from azure;

Extract data from the file `dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` in the `azure` data source:

    select t.B.`deviceId`, t.B.`type`, t.B.`value` from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` limit 10) as t;"

Aggregate data:

    select t.B.`deviceId`, t.B.`type`, AVG(t.B.`value`) as `value` from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` limit 10) as t group by t.B.`deviceId`, t.B.`type`;"

Aggregate and order:

    select t.B.`deviceId`, t.B.`type`, AVG(t.B.`value`) as `value`, COUNT(t.B.deviceId) as ctn from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_*.avro`) as t group by t.B.`deviceId`, t.B.`type` order by ctn limit 10;"
