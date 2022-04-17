# GitHub IDP

## Manual Deployment

Create: `aws cloudformation create-stack --stack-name github-idp --template-body file://template.yml --parameters file://params.json --cli-input-yaml file://stack-config.yml --profile snapped-mgmt-admin`

Update: `aws cloudformation update-stack --stack-name github-idp --template-body file://template.yml --parameters file://params.json --cli-input-yaml file://stack-config.yml --profile snapped-mgmt-admin`