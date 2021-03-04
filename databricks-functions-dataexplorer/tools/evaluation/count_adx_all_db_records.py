from typing import List
import os

from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.mgmt.kusto import KustoManagementClient
from azure.common.credentials import ServicePrincipalCredentials

def get_kusto_client(client_id: str, client_secret: str, tenant_id: str,
                     region: str, cluster_name: str) -> KustoClient:
    cluster = f"https://{cluster_name}.{region}.kusto.windows.net"
    kcsb = KustoConnectionStringBuilder.with_aad_application_key_authentication(cluster,
                                                                                client_id,
                                                                                client_secret,
                                                                                tenant_id)
    return KustoClient(kcsb)

def get_kusto_mgnt_client(client_id: str, client_secret: str, tenant_id: str, sub_id: str) -> KustoClient:
    credentials = ServicePrincipalCredentials(
        client_id=client_id,
        secret=client_secret,
        tenant=tenant_id
    )
    return KustoManagementClient(credentials, sub_id)

def get_all_db_table_records_count(kusto_client: KustoClient, database: str, table_prefix: str =''):
    # Count Records from  CO Table and TEMP Tables in All Databases
    query_filter = f"union database(\"*\").CO*|union database(\"*\").TEMP*|count"
    print(f"query on database: {database} by query_filter: {query_filter}")
    response = kusto_client.execute(database, query_filter)
    result = response.primary_results[0]
    records_count = result.to_dict().get('data')[0]
    return records_count.get('Count')

if __name__ == '__main__':
    CLIENT_ID = os.environ.get('CLIENT_ID')
    CLIENT_SECRET = os.environ.get('CLIENT_SECRET')
    TENANT_ID = os.environ.get('TENANT_ID')
    REGION = os.environ.get('REGION')
    CLUSTER_NAME = os.environ.get('CLUSTER_NAME')
    SUBSCRIPTION_ID = os.environ.get('SUBSCRIPTION_ID')
    RESOURCE_GROUP = os.environ.get('RESOURCE_GROUP')

    if not CLIENT_ID or not CLIENT_SECRET or not TENANT_ID or not REGION or not CLUSTER_NAME or not SUBSCRIPTION_ID or not RESOURCE_GROUP:
        raise ValueError('Required env were missing: CLIENT_ID, CLIENT_SECRET, TENANT_ID, REGION, CLUSTER_NAME, SUBSCRIPTION_ID, RESOURCE_GROUP')

    kusto_client = get_kusto_client(CLIENT_ID, CLIENT_SECRET, TENANT_ID, REGION, CLUSTER_NAME)
    mgnt_client = get_kusto_mgnt_client(CLIENT_ID, CLIENT_SECRET, TENANT_ID, SUBSCRIPTION_ID)
    database_operations = mgnt_client.databases
    db_list_result = database_operations.list_by_cluster(RESOURCE_GROUP, CLUSTER_NAME)
    entry_database = None
    for db in db_list_result:
        entry_database = db.name.replace(CLUSTER_NAME + '/', '')
        break
    all_table_records = get_all_db_table_records_count(kusto_client, entry_database)
    print(f'all_table_records: {all_table_records}')
