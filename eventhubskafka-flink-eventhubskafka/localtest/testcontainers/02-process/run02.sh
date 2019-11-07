#!/bin/bash

flink run /opt/flink/lib/job.jar \
    --kafka.in.topic "$KAFKA_INPUT_TOPIC" \
    --kafka.in.bootstrap.servers "$KAFKA_BOOTSTRAP_SERVERS" \
    --kafka.in.request.timeout.ms "15000" \
    --kafka.in.sasl.mechanism PLAIN \
    --kafka.in.security.protocol PLAINTEXT \
    --kafka.out.topic "$KAFKA_OUTPUT_TOPIC" \
    --kafka.out.bootstrap.servers "$KAFKA_BOOTSTRAP_SERVERS" \
    --kafka.out.request.timeout.ms "15000" \
    --kafka.out.sasl.mechanism PLAIN \
    --kafka.out.security.protocol PLAINTEXT
