# Event Hubs Kafka -> Apache Flink -> Event Hubs Kafka - Knowledge Base

This page is about known issues and workarounds when they exist.

## AKS

### Service Principal may have to be created upfront

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

### 2 client secrets created in aksServicePrincipal.json
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

### Container image may not be found

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

## HDInsight

### HDInsight setup

The HDInsight password is hard-coded in the script `create-solution.sh`. It is only for manual access; the deployment scripts perform all cluster actions via script actions.

When connecting to the HDInsight cluster, you will land on the first head node. The Flink deployment script action actually runs on the first worker node. To list worker nodes: `yarn node -list` (they are listed unordered, the first worker node is the one with the lowest number, usually its name starts with `wn0-`). The script installs the Flink client under `/opt/flink`. Script action logs are stored at `/var/lib/ambari-agent/data/`.

The Flink application itself (Job Manager) will run on any other of the worker nodes. To find out which, SSH into the cluster and run:

```
yarn app -list

Total number of applications (application-types: [], states: [SUBMITTED, ACCEPTED, RUNNING] and tags: []):1
                Application-Id	    Application-Name	    Application-Type	      User	     Queue	             State	       Final-State	       Progress	                       Tracking-URL
application_1572498497480_0001	               Flink	        Apache Flink	      root	   default	           RUNNING	         UNDEFINED	           100%	http://wn2-algatt.pvszxskaguqehnrfy2pxxxhewe.fx.internal.cloudapp.net:43861
```

To connect to the Flink Job Manager Web UI, tunnel to host and port reported above:

```
ssh -L 10000:wn2-algatt.pvszxskaguqehnrfy2pxxxhewe.fx.internal.cloudapp.net:43861 sshuser@algattik01hdi-ssh.azurehdinsight.net
```

The console output of the `create-solution.sh` script contains the command line above with the correct syntax for your deployment.

After the tunnel is created, open a web browser on http://localhost/10000.

### Script action error

Deployment with "-p hdinsight" may fail with:

```
running script action
Command group 'hdinsight' is in preview. It may be changed/removed in a future release.
Deployment failed. Correlation ID: c48b85e5-0d05-4b11-8ba0-6b65006b44ec. ErrorCode: ScriptExecutionFailed; ErrorDescription: Execution of the following scripts failed :StartFlinkCluster
```

From the portal, look at the script action logs to locate the worker node and path to the logs (in /var/lib/ambari-agent/data/). SSH to the node. If the error is:


```
org.apache.flink.client.deployment.ClusterDeploymentException: Couldn't deploy Yarn session cluster
        at org.apache.flink.yarn.AbstractYarnClusterDescriptor.deploySessionCluster(AbstractYarnClusterDescriptor.java:385)
        at org.apache.flink.yarn.cli.FlinkYarnSessionCli.run(FlinkYarnSessionCli.java:616)
        at org.apache.flink.yarn.cli.FlinkYarnSessionCli.lambda$main$3(FlinkYarnSessionCli.java:844)
        at java.security.AccessController.doPrivileged(Native Method)
        at javax.security.auth.Subject.doAs(Subject.java:422)
        at org.apache.hadoop.security.UserGroupInformation.doAs(UserGroupInformation.java:1730)
        at org.apache.flink.runtime.security.HadoopSecurityContext.runSecured(HadoopSecurityContext.java:41)
        at org.apache.flink.yarn.cli.FlinkYarnSessionCli.main(FlinkYarnSessionCli.java:844)
Caused by: org.apache.flink.yarn.AbstractYarnClusterDescriptor$YarnDeploymentException: Couldn't get cluster description, please check on the YarnConfiguration
        at org.apache.flink.yarn.AbstractYarnClusterDescriptor.isReadyForDeployment(AbstractYarnClusterDescriptor.java:242)
        at org.apache.flink.yarn.AbstractYarnClusterDescriptor.deployInternal(AbstractYarnClusterDescriptor.java:457)
        at org.apache.flink.yarn.AbstractYarnClusterDescriptor.deploySessionCluster(AbstractYarnClusterDescriptor.java:378)
        ... 7 more
Caused by: java.lang.ArrayIndexOutOfBoundsException: 1
        at java.util.ArrayList.add(ArrayList.java:463)
```

This seems to be a race condition and should be fixed in the script. In the meantime just run the `create-solution.sh` script again.

### Flink failures

if the metrics reporting step of `create-solution.sh` shows something like this, where events are being pushed into Event Hubs 1 (by the simulator), but not into Events Hub 2 (by the Flink job), you will need to debug the job:

```
***** [M] Starting METRICS reporting
Event Hub capacity: 2 throughput units (this determines MAX VALUE below).
Reporting aggregate metrics per minute, offset by 2 minutes, for 30 minutes.
                             Event Hub #    IncomingMessages       IncomingBytes    OutgoingMessages       OutgoingBytes   ThrottledRequests
                             -----------    ----------------       -------------    ----------------       -------------  ------------------
                   MAX VALUE                          120000           120000000              491520           240000000                   -
                             -----------    ----------------       -------------    ----------------       -------------  ------------------
    2019-10-31T11:39:21+0100           1                   0                   0                   0                   0                   0
    2019-10-31T11:39:21+0100           2                   0                   0                   0                   0                   0
    2019-10-31T11:40:00+0100           1                   0                   0                   0                   0                   0
    2019-10-31T11:40:00+0100           2                   0                   0                   0                   0                   0
    2019-10-31T11:41:00+0100           1                   0                   0                   0                   0                   0
    2019-10-31T11:41:00+0100           2                   0                   0                   0                   0                   0
    2019-10-31T11:42:00+0100           1                   0                   0                   0                   0                   0
    2019-10-31T11:42:00+0100           2                   0                   0                   0                   0                   0
    2019-10-31T11:43:00+0100           1               17804            16501080                 272              253966                   0
    2019-10-31T11:43:00+0100           2                   0                   0                   0                   0                   0
    2019-10-31T11:44:00+0100           1               60240            55873234                2102             1963716                   0
    2019-10-31T11:44:00+0100           2                   0                   0                   0                   0                   0
    2019-10-31T11:45:00+0100           1               59951            55640681                3138             2931439                   0
    2019-10-31T11:45:00+0100           2                   0                   0                   0                   0                   0
```

SSH into the cluster

```
yarn app -list

Total number of applications (application-types: [], states: [SUBMITTED, ACCEPTED, RUNNING] and tags: []):1
                Application-Id	    Application-Name	    Application-Type	      User	     Queue	             State	       Final-State	       Progress	                       Tracking-URL
application_1572498497480_0001	               Flink	        Apache Flink	      root	   default	           RUNNING	         UNDEFINED	           100%	http://wn2-algatt.pvszxskaguqehnrfy2pxxxhewe.fx.internal.cloudapp.net:43861
```

Then using the applicationId reported above:

```
yarn logs -applicationId application_1572498497480_0001
```

## Local run

You can try running the job locally as well:

Download Flink from https://archive.apache.org/dist/flink/flink-$flink_version/flink-1.9.1-bin-scala_2.12.tgz

```
bin/start-cluster.sh 
# check start was successful
tail log/flink-*-standalonesession-*.log

bin/flink run -jar flink-kafka-consumer/target/assembly/flink-kafka-consumer-simple-relay.jar \
  --kafka.in.sasl.mechanism 'PLAIN' ... # args from Flink Job Manager UI -> Running job -> Configuration

tail -f log/flink-*-taskexecutor-*.log
```


## General

### Integration tests (validation job)

Integration tests of the whole streaming-at-scale repo run on any PR to master. They are run in https://algattik.visualstudio.com/streaming-at-scale/_build?definitionId=1 (public Azure DevOps project). The tests deploy each solution and run integration tests in Spark on Databricks by passing the `-sV` step to `create-solution.sh`.

By default this will spin a new Databricks workspace and ask you to create and provide a PAT. To save time on this, do the following:

* Deploy Databricks in a VNET as specified in https://github.com/Azure-Samples/streaming-at-scale/tree/master/integration-tests#creating-the-integration-test-pipeline-in-azure-devops.
* Pass the following values as environment variable to the `create-solution.sh` script:
```
DATABRICKS_VNET_RESOURCE_GROUP=databricks
DATABRICKS_HOST=https://northeurope.azuredatabricks.net
DATABRICKS_TOKEN=dapi12345678901234567890123456789012 
```
