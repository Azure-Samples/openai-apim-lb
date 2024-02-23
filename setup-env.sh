#!/bin/bash

# Prereqs: 
# 1) az login --use-device-code
# 2) azd env new <environment-name>

# Parameters
RESOURCE_GROUP=$1
WEBAPP_NAME=$2

# Check if parameters are empty
if [ -z "$RESOURCE_GROUP" ] || [ -z "$WEBAPP_NAME" ]; then
    echo "Error: Both resource group and webapp name must be provided."
    exit 1
fi

# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Set AZURE_ENTRA_AUTH
azd env set AZURE_ENTRA_AUTH true

# Set AZURE_TENANT_ID
azd env set AZURE_TENANT_ID $TENANT_ID

# Get Application ID of the Sample App managed identity
PRINCIPAL_ID=$(az webapp identity show --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)
APP_ID=$(az ad sp show --id $PRINCIPAL_ID --query appId -o tsv)

# Set AZURE_CLIENT_ID
azd env set AZURE_CLIENT_ID $APP_ID

# Set AZURE_AUDIENCE
azd env set AZURE_AUDIENCE https://cognitiveservices.azure.com