#!/bin/bash

echo 'creating iothub'
echo ". name: $IOTHUB_NAME"

az iot hub create --name $IOTHUB_NAME \
--resource-group $RESOURCE_GROUP --sku S1 \
-o tsv >> log.txt

echo 'getting SAS token for IoT Hub'

IOTHUB_SAS_TOKEN=`az iot hub generate-sas-token -n $IOTHUB_NAME --duration 36000 -o tsv`
export IOTHUB_SAS_TOKEN=$IOTHUB_SAS_TOKEN

echo 'registering Light bulb devices'
echo ". name: SimulatedLightBulbs-[id]"

for BULB_ID in {0001..0100}
do
az iot hub device-identity create --device-id SimulatedLightBulbs-$BULB_ID --hub-name $IOTHUB_NAME \
-o tsv >> log.txt
done

echo 'registering Fridge devices'
echo ". name: SimulatedFridge-[id]"

for FRIDGE_ID in {0001..0100}
do
az iot hub device-identity create --device-id SimulatedFridge-$FRIDGE_ID --hub-name $IOTHUB_NAME \
-o tsv >> log.txt
done
