"""
  [Microsoft Stream-at-Scale project]
  provision code to pre-generate database and tables in adx
"""
import os
import sys
import argparse
import json
from datetime import timedelta

from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.mgmt.kusto.models import ReadWriteDatabase
from azure.mgmt.kusto import KustoManagementClient
from azure.common.credentials import ServicePrincipalCredentials

RETENTION_DAYS = None
KUSTO_MGMT_CLIENT = None
SERVICE_CLIENT = None
CLUSTER = None
CLUSTER_NAME = None
RESOURCE_GROUP = None

CLIENT_ID = None
CLIENT_SECRET = None
TENANT_ID = None
SUBSCRIPTION_ID = None
REGION = None

MAX_BATCHTIME = "00:01:00"
MAX_ITEMS = "500"
MAX_RAWSIZE = "1024"
SOFTDELETEPERIOD = "3650"
HOTCACHEPERIOD = "3650"
DATABASE_NAME_FORMAT = "company-id-{INDEX}"
TABLE_LIST_STR = "CO2,TEMP"
TABLE_LIST = ["CO2", "TEMP"]
BATCH_INGESTION_POLICY = """
{{
    "MaximumBatchingTimeSpan":"{MAX_BATCHTIME}",
    "MaximumNumberOfItems":{MAX_ITEMS},
    "MaximumRawDataSizeMB":{MAX_RAWSIZE}
}}
"""

def init_config():
    """get config from environment
    """
    global RETENTION_DAYS, RESOURCE_GROUP, CLUSTER_NAME
    global REGION, CLUSTER, CLIENT_ID, CLIENT_SECRET, TENANT_ID, SUBSCRIPTION_ID
    global MAX_BATCHTIME, MAX_ITEMS, MAX_RAWSIZE
    global SOFTDELETEPERIOD, HOTCACHEPERIOD
    global TABLE_LIST_STR, TABLE_LIST
    RETENTION_DAYS = os.getenv('RETENTION_DAYS', RETENTION_DAYS)
    RESOURCE_GROUP = os.getenv('RESOURCE_GROUP')
    REGION = os.getenv('REGION')
    CLIENT_ID = os.getenv('CLIENT_ID')
    CLIENT_SECRET = os.getenv('CLIENT_SECRET')
    TENANT_ID = os.getenv('TENANT_ID')
    SUBSCRIPTION_ID = os.getenv('SUBSCRIPTION_ID')
    CLUSTER_NAME = os.getenv('CLUSTER_NAME')
    MAX_BATCHTIME = os.getenv('MAX_BATCHTIME', MAX_BATCHTIME)
    MAX_ITEMS = int(os.getenv('MAX_ITEMS', MAX_ITEMS))
    MAX_RAWSIZE = int(os.getenv('MAX_RAWSIZE', MAX_RAWSIZE))
    SOFTDELETEPERIOD = int(os.getenv('SOFTDELETEPERIOD', SOFTDELETEPERIOD))
    HOTCACHEPERIOD = int(os.getenv('HOTCACHEPERIOD', HOTCACHEPERIOD))
    CLUSTER = f"https://{CLUSTER_NAME}.{REGION}.kusto.windows.net"
    TABLE_LIST_STR =  os.getenv('TABLE_LIST_STR', TABLE_LIST_STR)
    TABLE_LIST = TABLE_LIST_STR.split(',')
    print(TABLE_LIST)

def initialize_kusto_client():
    """initialize kusto client
    """
    try:
        global SERVICE_CLIENT, KUSTO_MGMT_CLIENT

        credentials = ServicePrincipalCredentials(
            client_id=CLIENT_ID,
            secret=CLIENT_SECRET,
            tenant=TENANT_ID
        )

        KUSTO_MGMT_CLIENT = KustoManagementClient(credentials, SUBSCRIPTION_ID)
        kcsb = KustoConnectionStringBuilder.with_aad_application_key_authentication(
            CLUSTER,
            CLIENT_ID,
            CLIENT_SECRET,
            TENANT_ID)
        SERVICE_CLIENT = KustoClient(kcsb)

    except Exception as err:
        print("error for KustoClient")
        print(err)
        raise


def get_ingest_mapping(file_path):
    """get ingestion mapping from schema
    :param fp: schemaFp
    :type fp: string
    """
    mapping = ["'['"]
    with open(file_path, 'r', encoding='utf-8') as mapping_fd:
        content = json.load(mapping_fd)
        line_count = len(content['schema'])
        for i in range(line_count):
            field = content['schema'][i]
            kql_dict = {"column": '{field}'.format(field=field['field']),
                        "datatype": '{adxType}'.format(adxType=field['adxType']),
                        "Properties": {"Path": '$.{field}'.format(field=field['field'])}}

            if 'ingest' in field.get('properties', {}):
                source = field['properties']['ingest']['source']
                transform = field['properties']['ingest']['transform']
                kql_dict["Properties"] = {"Path": '$.{source}'.format(source=source), \
                "transform": transform}

            if i != line_count - 1:
                json_str = '\'{json_kql},\''.format(json_kql=json.dumps(kql_dict))
            else:
                json_str = '\'{json_kql}\''.format(json_kql=json.dumps(kql_dict))

            mapping.append(json_str)

    mapping.append("']'")
    return '\n'.join(mapping)


def get_schema(file_path, get_raw=True):
    """get schema
    :param file_path: schema file path
    :type file_path: string
    :param get_raw: [description], defaults to True
    :type get_raw: bool, optional
    :return: schema json content
    :rtype: dict
    """
    schema = {}
    with open(file_path, 'r', encoding='utf-8') as schema_fd:
        content = json.load(schema_fd)
        for field in content["schema"]:
            fieldname = field["field"]
            adx_type = field["adxType"]
            is_raw = True
            if "update" in field.get("properties", {}):
                is_raw = False

            if (get_raw and is_raw) or (not get_raw):
                schema[fieldname] = adx_type
    return schema

def create_table_command(table, schema):
    """get a query that will create table
    :param table: table name
    :type table: string
    :param schema: schema dict
    :type schema: json
    """

    schema_str = ", ".join(["%s:%s" % (k, schema[k]) for k in sorted(list(schema.keys()))])
    command = '.create-merge table %s (%s)' % (table, schema_str)
    return command

def retention_policy(table):
    """retention_policy
    :param table: table name
    :type table: string
    """
    command = ".alter-merge table %s policy retention softdelete = %sd \
    recoverability = disabled" % (table, RETENTION_DAYS)
    return command

def ingestion_mapping_command(table, schema_file):
    """ingestion_mapping_command
    :param table: table name
    :type table: string
    """
    #TODO:Change mapping name to variable#TODO:Change mapping name to env variable
    #TODO:Need to align with function setting
    command = '.create-or-alter table %s ingestion json mapping "json_mapping_01"\n%s' \
    % (table, get_ingest_mapping(schema_file))
    return command

def batch_policy(database):
    """retention_policy
    :param table: table name
    :type table: string
    """
    ingestion_policy_json = BATCH_INGESTION_POLICY.format(MAX_BATCHTIME=MAX_BATCHTIME, \
        MAX_ITEMS=MAX_ITEMS, \
        MAX_RAWSIZE=MAX_RAWSIZE)
    ingestion_policy = json.dumps(json.loads(ingestion_policy_json))

    command = ".alter database [%s] policy ingestionbatching @'%s'"%(database, ingestion_policy)
    return command


def drop_entity_command(entity_type, entity_value):
    """drop entity

    :param entity_type: entity type
    :type entity_type: string. ex table, database
    :param entity_value: entity value. ex: database name
    :type entity_value: string
    :return: kql command string
    :rtype: string
    """
    return '.drop %s %s ifexists' % (entity_type, entity_value)



def create_database(number_of_companies):
    """create_database
    :param number_of_companies: number_of_companies
    :type number_of_companies: int
    """
    soft_deleteperiod = timedelta(days=SOFTDELETEPERIOD)
    hot_cacheperiod = timedelta(days=HOTCACHEPERIOD)
    database_operations = KUSTO_MGMT_CLIENT.databases
    for index in range(0, number_of_companies):
        try:
            database_name = DATABASE_NAME_FORMAT.format(INDEX=index)
            _database = ReadWriteDatabase(location=REGION, soft_delete_period=soft_deleteperiod, \
                hot_cache_period=hot_cacheperiod)
            print(f"Create Database {index} - {database_name}")
            database_operations.create_or_update(resource_group_name=RESOURCE_GROUP, \
                cluster_name=CLUSTER_NAME, database_name=database_name, parameters=_database)
        except Exception as err:
            print(err)
            raise

def update_retention_date(number_of_companies):
    """update table retention date
    :param number_of_companies: number_of_companies
    :type number_of_companies: int
    """
    print("update retention date")
    for index in range(0, number_of_companies):
        database_name = DATABASE_NAME_FORMAT.format(INDEX=index)
        print(f"Update retention date Policy for Database {index} - {database_name}")
        command_list = []
        for table_name in TABLE_LIST:
            command_list.append(retention_policy(table_name))
        try:
            for command in command_list:
                SERVICE_CLIENT.execute(database_name, command)
        except Exception as err:
            print(err)
            raise

def update_ingestion_policy(number_of_companies):
    """update ingestion policy

    :param number_of_companies: number_of_companies
    :type number_of_companies: int
    """
    print("update_ingestion_policy")
    for index in range(0, number_of_companies):
        database_name = DATABASE_NAME_FORMAT.format(INDEX=index)
        print(f"Update Ingestion Policy for Database {index} - {database_name}")
        command = batch_policy(database_name)
        print(f"Batch Policy Command:{command}")
        try:
            SERVICE_CLIENT.execute_mgmt(database_name, command)
        except Exception as err:
            print(err)
            raise


def create_table_of_database(number_of_companies, schema_file):
    """create table for existing database

    :param number_of_companies: number_of_companies
    :type number_of_companies: int
    :param schema_file: schema file
    :type schema_file: json
    """
    for index in range(0, number_of_companies):
        database_name = DATABASE_NAME_FORMAT.format(INDEX=index)
        print(f"Create Table for Database {index} - {database_name}")
        #add_userrole(database_name)
        command_list = create_tables_command(schema_file)
        try:
            for command in command_list:
                #while True:
                SERVICE_CLIENT.execute(database_name, command)
        except Exception as err:
            print(err)
            raise


def delete_database(number_of_companies):
    """deletedatabase

   :param number_of_companies: number_of_companies
    :type number_of_companies: int
    """
    soft_deleteperiod = timedelta(days=SOFTDELETEPERIOD)
    hot_cacheperiod = timedelta(days=HOTCACHEPERIOD)
    for index in range(0, number_of_companies):
        try:
            database_name = DATABASE_NAME_FORMAT.format(INDEX=index)
            print(f"Delete Database {index} - {database_name}")
            database_operations = KUSTO_MGMT_CLIENT.databases
            _database = ReadWriteDatabase(location=REGION, soft_delete_period=soft_deleteperiod, \
            hot_cache_period=hot_cacheperiod)
            database_operations.delete(resource_group_name=RESOURCE_GROUP, \
                cluster_name=CLUSTER_NAME, database_name=database_name, \
                parameters=_database)
        except Exception as err:
            print(err)
            raise

def create_tables_command(schema_file):
    """create one table for existing database

    :param number_of_companies: number_of_companies
    :type number_of_companies: int
    :param schema_file: schema file
    :type schema_file: json
    """
    command_list = []
    for table_name in TABLE_LIST:
        schema = get_schema(schema_file, False)
        command_list.append(create_table_command(table_name, schema))
        command_list.append(retention_policy(table_name))
        command_list.append(ingestion_mapping_command(table_name, schema_file))
    return command_list

if __name__ == "__main__": # pragma: no cover
    init_config()
    initialize_kusto_client()

    # Get related arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('act', help='action will be performed', type=str, \
                        choices=["createDatabase", "createTableofDatabase", \
                        "deleteDatabase", "dropTables", "updateDatabaseIngestPolicy", \
                        "updateretentiondate"])
    parser.add_argument('-s', '--schemaFp', \
        help='Schema file. format: {field_name},{type},{value_source_str}', \
        type=str)
    parser.add_argument('-c', '--deviceCount', help='Device count. format: int',
                        type=int)
    args = parser.parse_args()

    act = args.act
    schemaFp = args.schemaFp
    databaseCount = args.deviceCount

    # validate args. Error if schema file is not assigned
    if act in ("createTableofDatabase") \
        and (not schemaFp or not os.path.exists(schemaFp)):
        print("Please assign schema file path: -s /tmp/schema.csv")
        sys.exit(1)

    # run functions
    s = []
    if act == "createDatabase":
        create_database(databaseCount)
    elif act == "createTableofDatabase":
        create_table_of_database(databaseCount, schemaFp)
    elif act == "updateDatabaseIngestPolicy":
        update_ingestion_policy(databaseCount)
    elif act == "deleteDatabase":
        delete_database(databaseCount)
    elif act == "updateretentiondate":
        update_retention_date(databaseCount)
