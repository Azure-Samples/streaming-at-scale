Load Test

# Utility for Load Test
## Installation
```
pip3 install -r requirements.txt
```
## Count All ADX Database Table Records
Setup Required Environment Variables. Skip this step if they are ready.
```
export CLIENT_ID='<AAD client id for ADX query>'
export CLIENT_SECRET='<AAD client secret for ADX query>'
export TENANT_ID='<AAD tenat id for ADX query>'
export REGION='<ADX region>'
export CLUSTER_NAME='<ADX cluster name>'
export SUBSCRIPTION_ID='<ADX subscription ID>'
export RESOURCE_GROUP='<ADX resource group name>'
```
```
python3 count_adx_all_db_records.py
```

## Cleanup All ADX Database Table Records
Setup Required Environment Variables. Skip this step if they are ready.
```
export CLIENT_ID='<AAD client id for ADX query>'
export CLIENT_SECRET='<AAD client secret for ADX query>'
export TENANT_ID='<AAD tenat id for ADX query>'
export REGION='<ADX region>'
export CLUSTER_NAME='<ADX cluster name>'
export SUBSCRIPTION_ID='<ADX subscription ID>'
export RESOURCE_GROUP='<ADX resource group name>'
```
```
python3 cleanup_adx_all_db_records.py
```