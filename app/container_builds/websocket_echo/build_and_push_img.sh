#!/bin/bash

# Docker Image Universe Destroyer
# docker rmi -f $(docker images -aq)

# Set Global Variables
ACR_NAME_PREFIX=$(jq -r '.parameters.acr_params.value.name_prefix' params.json)
GLOBAL_UNIQUENESS=$(jq -r '.parameters.deploymentParams.value.global_uniqueness' params.json)

ENTERPRISE_NAME=$(jq -r '.parameters.deploymentParams.value.enterprise_name' params.json)
ENTERPRISE_NAME_SUFFIX=$(jq -r '.parameters.deploymentParams.value.enterprise_name_suffix' params.json)
LOC_SHORT_CODE=$(jq -r '.parameters.deploymentParams.value.loc_short_code' params.json)
RG_NAME="${ENTERPRISE_NAME}_${LOC_SHORT_CODE}_${ENTERPRISE_NAME_SUFFIX}_${GLOBAL_UNIQUENESS}"

CONTAINER_CODE_LOCATION="app/container_builds/websocket_echo/ws_server_app/"

pushd ${CONTAINER_CODE_LOCATION}

ACR_NAME=$(az acr list --resource-group $RG_NAME --query "[?starts_with(name, 'con')].{Name:name}" --output tsv)



export ACR_NAME
export IMG_NAME="websocket-echo"

echo -e "\n\nPushing images to ACR: $ACR_NAME"

# Login to Azure Container Registry
az acr login --name ${ACR_NAME} 2>&1  > /dev/null

# Disable Anonymous Docker Pull
az acr update --name ${ACR_NAME} --anonymous-pull-enabled false 2>&1  > /dev/null

## Build the image
docker build -t ${IMG_NAME} .

## Tag the image
BUILD_VERSION=$(date '+%Y-%m-%d-%H-%M')

docker tag ${IMG_NAME} ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}
docker tag ${IMG_NAME} ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}:${BUILD_VERSION}
docker tag ${IMG_NAME} ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}:v1

## Push the image to the registry
docker push ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}
docker push ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}:${BUILD_VERSION}
docker push ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}:v1


## Run the image from the registry

# docker run -it --rm -p 8080:80 mcr.microsoft.com/oss/nginx/nginx:stable
# docker run -it --rm -p 80:80 ${ACR_NAME}.azurecr.io/miztiik/${IMG_NAME}

# Return to home folder
popd