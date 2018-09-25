# Streaming at Scale with IoT device messages to cloud

This sample uses simulated IoT devices to send messages to IoT Hub

The provided scripts will an end-to-end solution complete with load test client.

## Running the Scripts

Please note that the scripts have been tested on Windows 10 WSL/Ubuntu, so make sure to use one of these two environment to run the scripts.
A PowerShell script is also in the works.

## Setup Solution

Make sure you are logged into your Azure account:

    az login

and also make sure you have the subscription you want to use selected

    az account list

if you want to select a specific subscription use the following command

    az account set --subscription <subscription_name>

If you have a pre-created IoT Hub and devices,

    Replace lines 66 and 67 of the create-solution.sh file with IoT Hub details

Else, you can uncomment lines 69 through 72 to have the script create IoT Hub and devices for you

once you have selected the subscription you want to use just execute the following command

    ./create-solution.sh <solution_name>

then `solution_name` value will be used to create a resource group that will contain all resources created by the script. It will also be used as a prefix for all resource created, in order to help to avoid name duplicates that will break the script

**Note**
To make sure that name collisions will be unlikely use a random string:

    openssl rand 5 -base64 | cut -c1-7


## Monitor performances

## Query Data