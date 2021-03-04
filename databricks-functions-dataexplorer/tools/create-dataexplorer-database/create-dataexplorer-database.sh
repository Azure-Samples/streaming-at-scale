#!/bin/sh
export RESOURCE_GROUP=
export CLIENT_ID=
export CLIENT_SECRET=
export TENANT_ID=
export SUBSCRIPTION_ID=
export CLUSTER_NAME=
export REGION=southeastasia
export RAW_TABLE=sdltelemetry
export RETENTION_DAYS=1
export MAX_BATCHTIME=00:01:00
export MAX_ITEMS=500
export MAX_RAWSIZE=1024
echo $CLUSTER_NAME
echo $MAX_BATCHTIME
pip install -r requirements.txt
python create_dataexplorer_database.py createDatabase -s FieldList -c 5
python create_dataexplorer_database.py createTableofDatabase -s FieldList -c 5
python create_dataexplorer_database.py updateDatabaseIngestPolicy -s FieldList -c 5
python create_dataexplorer_database.py updateretentiondate -s FieldList -c 5
#python create_dataexplorer_database.py deleteDatabase -s FieldList -c 5
