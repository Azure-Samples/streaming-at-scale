#!/bin/bash
watchForSeconds=$1

echo KAFKA_BOOTSTRAP_SERVERS=$KAFKA_BOOTSTRAP_SERVERS
echo KAFKA_INPUT_TOPIC=$KAFKA_INPUT_TOPIC
echo watchForSeconds=$watchForSeconds

kafka-console-consumer --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS --topic $KAFKA_INPUT_TOPIC --partition 0 &
kafka-console-consumer --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS --topic $KAFKA_INPUT_TOPIC --partition 1 &
kafka-console-consumer --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS --topic $KAFKA_OUTPUT_TOPIC --partition 0 &
kafka-console-consumer --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS --topic $KAFKA_OUTPUT_TOPIC --partition 1 &

sleep $watchForSeconds

kill %1
kill %2
kill %3
kill %4
