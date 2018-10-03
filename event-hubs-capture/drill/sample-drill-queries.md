**WIP**

    show databases;

    show files from azure;

    select t.B.`deviceId`, t.B.`type`, t.B.`value` from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` limit 10) as t;"

    select t.B.`deviceId`, t.B.`type`, AVG(t.B.`value`) as `value` from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` limit 10) as t group by t.B.`deviceId`, t.B.`type`;"

    select t.B.`deviceId`, t.B.`type`, AVG(t.B.`value`) as `value`, COUNT(t.B.deviceId) as ctn from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_*.avro`) as t group by t.B.`deviceId`, t.B.`type` order by ctn limit 10;"
