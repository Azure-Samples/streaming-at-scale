# Streaming at Scale with Azure Event Hubs and Flink

**Experimental work in progress**.

The conventional way to run Flink is to setup a cluster and submit JAR jobs to it.
Here we use a different approach that is better suited to the use of containers in a DevOps process.
This project builds a specific job container containing both Flink and the job JAR.
In the Kubernetes deployment, Flink is run in standalone mode.
This ensures immutable infrastructure, and allows scaling Task Managers independently for each Flink Job.

The architecture is based on the blog post by Tobias Bahls on [Running Apache
Flink on Kubernetes at
Zalando](https://jobs.zalando.com/tech/blog/running-apache-flink-on-kubernetes).

TODO:

- Kafka Connection string containing password should be passed as a secret, not as an argument
