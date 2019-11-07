#!/bin/bash

echo KAFKA_BOOTSTRAP_SERVERS=$KAFKA_BOOTSTRAP_SERVERS
echo KAFKA_INPUT_TOPIC=$KAFKA_INPUT_TOPIC
echo KAFKA_OUTPUT_TOPIC=$KAFKA_OUTPUT_TOPIC

kafka-topics --create \
    --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
    --replication-factor 1 \
    --partitions 2 \
    --topic $KAFKA_INPUT_TOPIC

kafka-topics --create \
    --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
    --replication-factor 1 \
    --partitions 2 \
    --topic $KAFKA_OUTPUT_TOPIC

kafka-topics --list --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS
