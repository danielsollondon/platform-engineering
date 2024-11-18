# steps to debug failed ADE deployments
```bash
devCenterName=
projectName=
envName=

az devcenter dev environment list-operation --environment-name $envName --project-name $projectName --dev-center $devCenterName

operationId=
clear
az devcenter dev environment show-logs-by-operation --operation-id $operationId --environment-name $envName --project-name $projectName --dev-center $devCenterName > output.json
```

# delete ADE deployment
If there is an error in the deployment delete script you will not be able to delete, and will need to use the '--force' and the latest AZ CLI.

```bash
az devcenter dev environment delete --environment-name {env_name} --project {proj_name} --force
```