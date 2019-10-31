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

## HDInsight setup

The HDInsight password is hard-coded in the script `create-solution.sh`. It is only for manual access; the deployment scripts perform all cluster actions via script actions.

When connecting to the HDInsight cluster, you will land on the first head node. The Flink deployment script action actually runs on the first worker node. To list worker nodes: `yarn node -list` (they are listed unordered, the first worker node is the one with the lowest number, usually its name starts with `wn0-`). The script installs the Flink client under /opt/flink.

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



