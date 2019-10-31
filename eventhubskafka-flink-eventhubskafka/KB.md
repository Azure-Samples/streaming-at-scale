# Event Hubs Kafka -> Apache Flink -> Event Hubs Kafka - Knowledge Base

This page is about known issues and workarounds when they exist.

## Service Principal may have to be created upfront

The first time your run `create-solution.sh` for AKS without creating a service principal before, 
you may have the following error:

```
Operation failed with status: 'Bad Request'. Details: Service principal clientID: <some GUID> not found in Active Directory tenant <some GUID>
```

workaround: rerun the script. 

Why?

There is a bug currently. 
Sometimes it works, but sometimes the service principal has not been propagated, so AKS creation fails just after the creation of the service principal. 
The better way is to do it in two steps. 
But when you don't specify a service principal, it creates one for you and stores it into $HOME/.azure/aksServicePrincipal.json (or use it if it already exists). 
This is also why running the command after a while works. 
First time, it creates the SP and fails, second time, it takes the SP from local file, and the propagation is done.

## 2 client secrets created in aksServicePrincipal.json
```
Operation failed with status: 'Bad Request'. Details: The credentials in ServicePrincipalProfile were invalid. Please see https://aka.ms/aks-sp-help for more details. (Details: adal: Refresh request failed. Status Code = '401'. Response body: {"error":"invalid_client","error_description":"AADSTS7000215: Invalid client secret is provided.\r\nTrace ID: \r\nCorrelation ID: xxxx \r\nTimestamp: xxx","error_codes":[7000215],"timestamp":xxx","trace_id":"xxx ","correlation_id":"xxxx","error_uri":"https://login.microsoftonline.com/error?code=7000215"})
```
If you get this error than you ended up getting 2 client secrets:
```
$ cat $HOME/.azure/aksServicePrincipal.json
{"5763fde3-4253-480c-928f-dfe1e8888a57": {"client_secret": "xxxx", "service_principal": "3xxxx"}, "e3a22b46-4544-4266-b1a1-e2290f4081e9": {"client_secret": "xxxx", "service_principal": "xxxx"}}
```
Solution is to remove this file or backup, and re-run the create solution script.
```
$ rm $HOME/.azure/aksServicePrincipal.json
or
$ mv $HOME/.azure/aksServicePrincipal.json $HOME/.azure/aksServicePrincipal.bkup
```

## Container image may not be found

while running test with `create-solution.sh`, you may have an error like this

```
(...)
***** [T] Starting up TEST clients
creating container registry...
creating generator container instances...
. number of instances: 1
. events/second per instance: 1000
The image '###obfuscated###.azurecr.io/generator:latest' in container group 'data-generator-1' is not accessible. Please check the image and registry credential.
```

workaround: rerun the script. 

Why? 

This is a transient error that we need to fix.
