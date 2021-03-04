## Usage ##
### -c to define database count
- create database
python create_dataexplorer_database.py createDatabase -s FieldList -c 5
- create table for database
python create_dataexplorer_database.py createTableofDatabase -s FieldList -c 5
- update database ingestion policy
#python create_dataexplorer_database.py updateDatabaseIngestPolicy -s FieldList -c 5
- update retention date
#python create_dataexplorer_database.py updateretentiondate -s FieldList -c 5
- delete database
#python create_dataexplorer_database.py deleteDatabase -s FieldList -c 5