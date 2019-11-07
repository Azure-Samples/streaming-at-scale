# Simulator: Standalone Setup with Event Hub with Kafka Head + JSON producer

The simulator is written using PySpark library that uses pre-compiled Apache Spark JARS deployed into Python virtual environments.

The simulator can only be used with `create-solution.sh` bash  integration script under every folder in this repo. 

The following steps need to be performed to run it standalone

## Prerequisites

1. [Apache Maven 3.6.2](https://maven.apache.org/)
2. [Python 3.6 and above](https://www.python.org/downloads/)
3. Event Hub and Event Hub Namespace in Azure
4. Azure Container Registry
5. If using anaconda, install conda and follow steps [here](https://docs.conda.io/projects/conda/en/latest/commands/install.html)

## Steps to install development setup

1. Create a python virtual environment or use conda environment

`python3 -m venv env`

2. Activate the environment

`source env/bin/activate`

3. Pip install libraries from simulator/generator/requirements.txt

`pip install -r requirements.txt`

4. Navigate to the simulator/generator folder and install maven artifacts

`mvn -f ./dependencies dependency:copy-dependencies`

This will generate the following jar files in the target/dependency folder

```
azure-eventhubs-2.3.2.jar             proton-j-0.31.0.jar                   slf4j-api-1.7.25.jar                  unused-1.0.0.jar
azure-eventhubs-spark_2.11-2.3.13.jar qpid-proton-j-extensions-1.2.0.jar    snappy-java-1.1.7.1.jar
kafka-clients-2.0.0.jar               scala-java8-compat_2.11-0.9.0.jar     spark-sql-kafka-0-10_2.11-2.4.3.jar
lz4-java-1.4.1.jar                    scala-library-2.11.12.jar             spark-tags_2.11-2.4.3.jar
```

5. Copy these jar files to env/lib/python3.6/site-packages/pyspark/jars folder

If using conda, navigate to the conda environment.

6. Set the following environment variables using a bash script

```
export EVENTHUBNS="Event Hub Namespace"
export RESOURCE_GROUP="Resource Group in Azure where Event Hub is deployed"
export EVENTHUB_CS="Event hub connection string"
export CONTAINER_REGISTRY="Azure Container Registry"
export KAFKA_TOPIC="streaming"

export KAFKA_BROKERS=
$EVENTHUBNS.servicebus.windows.net:9093
export KAFKA_SECURITY_PROTOCOL=SASL_SSL
export KAFKA_SASL_MECHANISM=PLAIN
export SIMULATOR_INSTANCES=1
export loginModule="org.apache.kafka.common.security.plain.PlainLoginModule"
export KAFKA_SASL_JAAS_CONFIG="$loginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS\";"
export OUTPUT_OPTIONS=$(cat <<OPTIONS
{
  "kafka.bootstrap.servers": "$KAFKA_BROKERS",
  "kafka.sasl.mechanism": "$KAFKA_SASL_MECHANISM",
  "kafka.security.protocol": "$KAFKA_SECURITY_PROTOCOL",
  "topic": "$KAFKA_TOPIC"
}
OPTIONS
)
export SECURE_OUTPUT_OPTIONS=$(echo "$KAFKA_SASL_JAAS_CONFIG" | jq --raw-input '{"kafka.sasl.jaas.config":.}')

```

7. Run the python file in generator folder

`python __main_.py`

## Debugging with Visual Studio Code

1. Make sure the above steps are followed in the Visual Studio Code terminal, especially setting the environment variables

2. Make sure the Python interpreter in Visual Studio Code is pointing to the virtual environment or conda environment

3. Launch Debugger from Visual Studio Code.