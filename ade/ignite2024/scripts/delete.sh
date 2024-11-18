#!/bin/bash

## NOTE - this is does not work completely and will need debugging

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -e # exit on error

EnvironmentState="$ADE_STORAGE/environment.tfstate"
EnvironmentPlan="/environment.tfplan"
EnvironmentVars="/environment.tfvars.json"

echo "base image version $BASE_IMAGE_VERSION"
echo "custom image version $CUSTOM_IMAGE_VERSION"

echo "$ADE_OPERATION_PARAMETERS" > $EnvironmentVars

# Set up Terraform AzureRM managed identity.
export ARM_USE_MSI=true
export ARM_CLIENT_ID=$ADE_CLIENT_ID
export ARM_TENANT_ID=$ADE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$ADE_SUBSCRIPTION_ID

if ! test -f $EnvironmentState; then
    echo "No state file present. Delete succeeded."
    exit 0
fi

echo -e "\n>>> Terraform...\n"
echo -e "\n>>> Terraform Info...\n"
terraform -version

echo -e "\n>>> Initializing Terraform...\n"
terraform init -no-color

echo -e "\n>>> Creating Terraform Plan...\n"
export TF_VAR_resource_group_name=$ADE_RESOURCE_GROUP_NAME
export TF_VAR_ade_env_name=$ADE_ENVIRONMENT_NAME
export TF_VAR_env_name=$ADE_ENVIRONMENT_NAME
export TF_VAR_ade_subscription=$ADE_SUBSCRIPTION_ID
export TF_VAR_ade_location=$ADE_ENVIRONMENT_LOCATION
export TF_VAR_ade_environment_type=$ADE_ENVIRONMENT_TYPE
terraform plan -no-color -compact-warnings -destroy -refresh=true -lock=true -state=$EnvironmentState -out=$EnvironmentPlan -var-file="$EnvironmentVars"

echo -e "\n>>> Applying Terraform Plan...\n"
terraform apply -no-color -compact-warnings -auto-approve -lock=true -state=$EnvironmentState $EnvironmentPlan

# we need the below 
export name=$(echo $ADE_OPERATION_PARAMETERS | jq .name | sed -e 's/^"//' -e 's/"$//')
export fileName=$(ade files download --file-name deploymentName.txt --folder-path $ADE_STORAGE | cat $ADE_STORAGE/deploymentName.txt)
# connect to githib

# CONNECT TO GIT
# access PAT from secret store
echo "Signing into Azure using MSI"
while true; do
    # managed identity isn't available immediately
    # we need to do retry after a short nap
    az login --identity --only-show-errors --output none && {
        echo "Successfully signed into Azure"
        az account set --subscription $ADE_SUBSCRIPTION_ID
        break
    } || sleep 5
done
# clone repo, and delete file
# note you we need to create a GH PAT TOKEN, allow it permission to read, write to the repo, and commit (optional).
GITHUB_TOKEN=$(az keyvault secret show --name aks-terraform-pat --vault-name kvdansol24 --query value -o tsv | tr -d '[:space:]')
# clone tesrepo
git config --global user.email "danis@microsoft.com"
git config --global user.name "danielsollondon"
git clone https://danielsollondon:${GITHUB_TOKEN}@github.com/danielsollondon/projects.git


cd projects
git rm environments/$fileName
git commit -a -m "deleting resources for $name"
git push
