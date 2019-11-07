#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
flinkRoot=$DIR/..
initialpwd=`pwd`

cd $DIR/testcontainers/00-init
docker build -t 00init:1.0 -t 00init:latest .

tmpdir=$(mktemp -d)
cp -r $flinkRoot/../simulator/generator $tmpdir
cp -r $DIR/testcontainers/01-inject/*.py $tmpdir/generator/generator
docker build -t 01inject-main:1.0 -t 01inject-main:latest $tmpdir/generator
rm -r $tmpdir

cd $DIR/testcontainers/01-inject
docker build -t 01inject:1.0 -t 01inject:latest .

cd $flinkRoot/flink-kafka-consumer
mvn clean package -P package-complex-processing

tmpdir=$(mktemp -d)
cp -R $flinkRoot/kubernetes/docker/flink-job $tmpdir
cp $flinkRoot/flink-kafka-consumer/target/assembly/flink-kafka-consumer-complex-processing.jar $tmpdir/flink-job
docker build -t 02process-jar:1.0 -t 02process-jar:latest \
  --build-arg job_jar=flink-kafka-consumer-complex-processing.jar \
  --build-arg flink_version=1.9.1-scala_2.12 \
  $tmpdir/flink-job
rm -r $tmpdir
cd $DIR/testcontainers/02-process
docker build -t 02process:1.0 -t 02process:latest .

#tmpdir=$(mktemp -d)
#cp -R $DIR/testcontainers/02-process/* $tmpdir
#cp $flinkRoot/flink-kafka-consumer/target/assembly/flink-kafka-consumer-complex-processing.jar $tmpdir
#docker build -t 02process-jar:1.0 -t 02process-jar:latest $tmpdir
#rm -r $tmpdir

cd $initialpwd
