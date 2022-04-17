#!/bin/bash
set -uf -o pipefail

COMPONENT_FOUND=false
VALID_STACK_STATUSES='CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE UPDATE_ROLLBACK_FAILED'

check_stack() {
    STACK_LIST=$(aws cloudformation list-stacks --stack-status-filter $VALID_STACK_STATUSES --output text --query "StackSummaries[*].[StackName]")

    for stack in $STACK_LIST
    do
        if [ "$stack" = "$INPUT_STACK_OR_STACKSET_NAME" ]; then
            COMPONENT_FOUND=true
        fi
    done
}

create_stack() {
    echo Creating stack...
    STACK_ID=$(aws cloudformation create-stack --stack-name $INPUT_STACK_OR_STACKSET_NAME --template-url $INPUT_TEMPLATE_URL --parameters file://$INPUT_COMPONENT_PATH/$INPUT_PARAM_FILE_NAME --cli-input-yaml file://$INPUT_COMPONENT_PATH/$INPUT_CONFIG_FILE_NAME --output text)
    echo Checking stack create status...
    aws cloudformation wait stack-create-complete --stack-name $STACK_ID
    echo Stack create complete
}

update_stack() {
    echo Updating stack...
    output=$(aws cloudformation update-stack --stack-name $INPUT_STACK_OR_STACKSET_NAME --template-url $INPUT_TEMPLATE_URL --parameters file://$INPUT_COMPONENT_PATH/$INPUT_PARAM_FILE_NAME --cli-input-yaml file://$INPUT_COMPONENT_PATH/$INPUT_CONFIG_FILE_NAME --output text 2>&1)
    RESULT=$?
    
    if [ $RESULT -eq 0 ]; then
      echo "$output"
    else
      if [[ "$output" == *"No updates are to be performed"* ]]; then
        echo "No CloudFormation stack updates are to be performed."
      else
        echo "$output"
        echo Checking stack update status...
        aws cloudformation wait stack-update-complete --stack-name $output
      fi
    fi
    
    echo Stack update complete
}

echo Deploying Stack $INPUT_STACK_OR_STACKSET_NAME...
echo INPUT_COMPONENT_PATH = $INPUT_COMPONENT_PATH
echo INPUT_CONFIG_FILE_NAME = $INPUT_CONFIG_FILE_NAME
echo INPUT_PARAM_FILE_NAME = $INPUT_PARAM_FILE_NAME
echo INPUT_STACK_OR_STACKSET_NAME = $INPUT_STACK_OR_STACKSET_NAME
echo INPUT_TEMPLATE_URL = $INPUT_TEMPLATE_URL

echo Determining deploy action...
check_stack

if [[ "$COMPONENT_FOUND"  == true ]]
then
    update_stack
else
    create_stack
fi
echo Deploy Stack Complete
