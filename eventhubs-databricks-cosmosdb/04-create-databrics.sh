#!/bin/bash

$RESULT = `az group deployment create -g dmtest001 --template-file databricks.arm.json --parameters workspaceName=dmtest001spark location=eastus tier=standard --output json`





 

  