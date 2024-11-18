#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -e # exit on error

EnvironmentState="$ADE_STORAGE/environment.tfstate"
EnvironmentPlan="/environment.tfplan"
EnvironmentVars="/environment.tfvars.json"

echo "base image version $BASE_IMAGE_VERSION"
echo "custom image version $CUSTOM_IMAGE_VERSION"
#env type indicates which folder in the repo, this can be test, staging, prod
#envtype="test"

echo "$ADE_OPERATION_PARAMETERS" > $EnvironmentVars

# Set up Terraform AzureRM managed identity.
export ARM_USE_MSI=true
export ARM_CLIENT_ID=$ADE_CLIENT_ID
export ARM_TENANT_ID=$ADE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$ADE_SUBSCRIPTION_ID

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

terraform plan -no-color -compact-warnings -refresh=true -lock=true -state=$EnvironmentState -out=$EnvironmentPlan -var-file="$EnvironmentVars"

echo -e "\n>>> Applying Terraform Plan...\n"
terraform apply -no-color -compact-warnings -auto-approve -lock=true -state=$EnvironmentState $EnvironmentPlan

# Outputs must be written to a specific file location.
# ADE expects data types array, boolean, number, object and string.
# Terraform outputs list, bool, number, map, set, string and null
# In addition, Terraform has type constraints, which allow for specifying the types of nested properties.
echo -e "\n>>> Generating outputs for ADE...\n"
tfout="$(terraform output -state=$EnvironmentState -json)"

# Convert Terraform output format to our internal format.
tfout=$(jq 'walk(if type == "object" then 
            if .type == "bool" then .type = "boolean" 
            elif .type == "list" then .type = "array" 
            elif .type == "map" then .type = "object" 
            elif .type == "set" then .type = "array" 
            elif (.type | type) == "array" then 
                if .type[0] == "tuple" then .type = "array" 
                elif .type[0] == "object" then .type = "object" 
                elif .type[0] == "set" then .type = "array" 
                else . 
                end 
            else . 
            end 
        else . 
        end)' <<< "$tfout")

echo "{\"outputs\": $tfout}" > $ADE_OUTPUTS
echo "Outputs successfully generated for ADE"

export name=$(echo $ADE_OPERATION_PARAMETERS | jq .name | sed -e 's/^"//' -e 's/"$//')
export teamname=$(echo $ADE_OPERATION_PARAMETERS | jq .teamname | sed -e 's/^"//' -e 's/"$//')
export repourl=$(echo $ADE_OPERATION_PARAMETERS | jq .repourl | sed -e 's/^"//' -e 's/"$//')
export repopath=$(echo $ADE_OPERATION_PARAMETERS | jq .repopath | sed -e 's/^"//' -e 's/"$//')
export keyvaultname=$(terraform output -state=$EnvironmentState keyvault_id  | awk -F"/" '{print $NF}' | tr -d '/"')
export clientid=$(terraform output -state=$EnvironmentState msi_client_id | tr -d '/"')

export deploymentName="adeGitOps-$ADE_ENVIRONMENT_NAME-"$(date +'%s')
# not deliberately making the deployment name the filename, as it looks like this is not stored anywhere, so will make it the 'name', although unquiness needs to be thought through
echo "ADE Deployment Name:" $name
# save name of file to environment storage
export fileName=$deploymentName.yaml
echo "$fileName" > $ADE_STORAGE/deploymentName.txt
ade files upload --file-path $ADE_STORAGE/deploymentName.txt
echo "Create Temporary Path"
tempPath="/tempTemplateDir"
mkdir $tempPath
echo "Downloading template, filename:" $fileName
curl https://raw.githubusercontent.com/danielsollondon/platform-engineering/refs/heads/main/ade/templates/full-backend-env-Fips.yaml -o $tempPath/$fileName
cat $tempPath/$fileName
echo "starting variable substitution"
echo "Client ID value: $clientid, Keyvault Name: $keyvaultname"
echo "STARTING variable substitution done and here it is:"
echo "VAR SUB $name"
sed -i -e "s/app-name/$name/g" $tempPath/$fileName
echo "VAR SUB $teamname"
sed -i -e "s/teamname/$teamname/g" $tempPath/$fileName
echo "VAR SUB $repourl"
sed -i -e "s~repourl~$repourl~g" $tempPath/$fileName
echo "VAR SUB $repopath"
sed -i -e "s~repopath~$repopath~g" $tempPath/$fileName
echo "VAR SUB $ADE_RESOURCE_GROUP_NAME"
sed -i -e "s/resource-group/$ADE_RESOURCE_GROUP_NAME/g" $tempPath/$fileName
echo "VAR SUB $ADE_TENANT_ID"
sed -i -e "s/mytenantid/$ADE_TENANT_ID/g" $tempPath/$fileName
echo "VAR SUB $clientid"
sed -i -e "s/myclientid/$clientid/g" $tempPath/$fileName
echo "VAR SUB $keyvaultname"
sed -i -e "s/mykeyvaultname/$keyvaultname/g" $tempPath/$fileName
echo "VAR SUB $branch"
sed -i -e "s/branch/$branch/g" $tempPath/$fileName

echo "variable substitution done and here it is:"
echo "filepath:" $tempPath/$fileName  
cat $tempPath/$fileName  

# rm ./$tempPath/$fileName 

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
GITHUB_TOKEN=$(az keyvault secret show --name aks-terraform-pat --vault-name kvdansol24 --query value -o tsv | tr -d '[:space:]')
# clone tesrepo

## ADD IN YOUR GH DETAILS HERE
git config --global user.email "my@username"
git config --global user.name "mygitusername"
git clone https://mygitusername:${GITHUB_TOKEN}@github.com/mygitusername/repo.git

# e.g.git clone https://danielsollondon:${GITHUB_TOKEN}@github.com/danielsollondon/projects.git


cluster=dev01
cp $tempPath/$fileName projects/environments/$cluster/$fileName
cd projects
git add environments/$cluster/$fileName
git commit -a -m "adding resources for $deploymentName"
git push

