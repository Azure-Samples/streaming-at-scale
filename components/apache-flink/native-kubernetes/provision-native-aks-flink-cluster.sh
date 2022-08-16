#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

namespace=$1

flink_version=$2
flink_scala_version=$3
java_version=$4

registry_username=$5
registry_password=$6

job_name=flink_job
job_version=1.0.0

echo 'building flink job image'
cd docker/flink-job
docker login MYREPO.azurecr.io
docker build --no-cache -t xpayregistry.azurecr.io/$job_name:$job_version .
docker push MYREPO.azurecr.io/$job_name:$job_version
cd ../..

echo 'deploying role'
kubectl create role flink-role --verb=get --verb=list --verb=watch --verb=create --verb=update --verb=patch --verb=delete  --resource=pods,services,deployments,namespaces --namespace=$namespace

echo 'deploying rolebinding'
kubectl create rolebinding flink-role-binding --role=pod-reader --serviceaccount=$namespace:default --namespace=$namespace

echo 'deploying secret for accessing azure container registry'
kubectl create secret docker-registry my-registry-key \
    --namespace=$namespace
    --docker-server=MYREPO.azurecr.io \
    --docker-username=$registry_username \
    --docker-password=$registry_password


echo 'download Flink runtime'
cd /opt/flink
curl -sfL -o flink.tgz "https://archive.apache.org/dist/flink/flink-$flink_version/flink-$flink_version-bin-scala_$flink_scala_version.tgz"
tar zxvf flink.tgz
rm -f flink
ln -s flink-$flink_version flink
cd flink

echo 'run Flink job on native k8s application mode'
./bin/flink run-application \
    --target kubernetes-application \
    -Dkubernetes.namespace=$namespace \
    -Dkubernetes.cluster-id=my-first-application-cluster \
    -Dkubernetes.container.image=MYREPO.azurecr.io/$job_name:$job_version \
    -Dkubernetes.container.image.pull-secrets=my-registry-key \
    -Dkubernetes.container.image.pull-policy=Always \
    local:///opt/flink/usrlib/job.jar 