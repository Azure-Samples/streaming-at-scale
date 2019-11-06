$(az vm list -g $AZURE_EDGE_NODE_NAME --query "[].publicIpAddress" -o tsv)    

az vm identity assign --name "flinkhdiazedgenode" --resource-group "flinkhdiaz"

#  "publicIpAddress": "40.79.17.179",
# "systemAssignedIdentity": "f334bca8-e3d2-409f-856b-65c5820e461a",

az keyvault set-policy --name '<YourKeyVaultName>' --object-id <VMSystemAssignedIdentity> --secret-permissions get list
az keyvault set-policy --name 'flinkhdiazkeyvault' --object-id 'f334bca8-e3d2-409f-856b-65c5820e461a' --secret-permissions get list

ssh hdiedgeuser@40.79.17.179

sudo apt-get update && sudo apt-get install python-pip
pip install requests==2.7.0


#**************************
# create python demo script: vi keyvault.py

# importing the requests library
import requests

# Step 1: Fetch an access token from an MSI-enabled Azure resource      
# Note that the resource here is https://vault.azure.net for the public cloud, and api-version is 2018-02-01
MSI_ENDPOINT = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net"
r = requests.get(MSI_ENDPOINT, headers = {"Metadata" : "true"})

# Extracting data in JSON format 
# This request gets an access token from Azure Active Directory by using the local MSI endpoint
data = r.json()

# Step 2: Pass the access token received from the previous HTTP GET call to the key vault
KeyVaultURL = "https://flinkhdiazkeyvault.vault.azure.net/secrets/EVENTHUB-CS-IN-LISTEN?api-version=2016-10-01"
kvSecret = requests.get(url = KeyVaultURL, headers = {"Authorization": "Bearer " + data["access_token"]})

print(kvSecret.json()["value"])

#**************************

python keyvault.py
scp -r  sshuser@flinkhdiazhdi-ssh.azurehdinsight.net:/etc/apt/sources.list.d/HDP.list /etc/apt/sources.list.d/HDP.list


#**************************
sudo vi /etc/apt/sources.list.d/HDP.list
root@flinkhdiazedgenode:~# cat /etc/apt/sources.list.d/HDP.list
#VERSION_NUMBER=3.1.2.2-1
deb [trusted=yes] https://bigdatadistro.blob.core.windows.net/hwxmirror/HDP/ubuntu16/3.x/updates/3.1.2.2-1 HDP main
deb [trusted=yes] https://bigdatadistro.blob.core.windows.net/hwxmirror/HDP-UTILS-1.1.0.22/repos/ubuntu16 HDP-UTILS main
deb [trusted=yes] https://bigdatadistro.blob.core.windows.net/hwxmirror/ambari/ubuntu16/2.x/updates/2.7.3.2-19 Ambari main
#**************************

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 07513CAD 417A0893

sudo apt-get update


sudo apt-get install openjdk-8-jdk hadoop-client 
sudo apt-get install hadooplzo hadooplzo-native libsnappy1 liblzo2-2

#remove the initial set of Hadoop configuration directories
rm -rf /etc/{hadoop,hive*,pig,spark*,tez*,zookeeper}/conf
#create a ssh keypair for the root account
ssh-keygen -t rsa

cat ~/.ssh/id_rsa.pub | ssh sshuser@flinkhdiazhdi-ssh.azurehdinsight.net 'cat >> .ssh/authorized_keys'

#define the following environment variables (/etc/environment
  export AZURE_SPARK=1
  export SPARK_MAJOR_VERSION=2
  export PYSPARK_DRIVER_PYTHON=/usr/bin/python

#install the edge node ssh key on the head node(can be a non-privileged account on the headnode side)
#copy the /etc/hosts definition for "headnodehost" from the head node to the edge node

#replace JAVA_HOME /etc/hadoop/conf/hadoop-env.sh
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/

#synchronize the following directories (as root on the edge node)
rsync -a --delete sshuser@flinkhdiazhdi-ssh.azurehdinsight.net:/etc/{hadoop,hive\*,pig,ranger\*,spark\*,tez\*,zookeeper} /etc/
rsync -a --delete sshuser@flinkhdiazhdi-ssh.azurehdinsight.net:/usr/lib/hdinsight\* /usr/lib/
rsync -a --delete sshuser@flinkhdiazhdi-ssh.azurehdinsight.net:/usr/hdp/ /usr/hdp/

#check that your connectivity works with hdfs dfs -ls / 
hdfs dfs -ls /

#Install the Ambari Agent.
apt-get install ambari-agent


#Start the agent on every host in your cluster.
ambari-agent start