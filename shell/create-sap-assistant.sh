# If not already cloned, clone the remote repository (https://github.com/aws-samples/amazon-bedrock-sap-sustainability-assistant) and change working directory to amazon-bedrock-sap-sustainability-assistant shell folder
# cd amazon-bedrock-sap-sustainability-assistant/shell/
# chmod u+x create-sap-assistant.sh
# export STACK_NAME=<YOUR-STACK-NAME> # Stack name must be lower case for S3 bucket naming convention
# export AWS_REGION=<YOUR-STACK-REGION> # Stack deployment region
# export SECURITY_GROUP_ID=<YOUR-SECURITY-GROUP-ID>
# export PRIV_SUBNET_ID01=<YOUR-PRIV-SUBNET-ID-01>
# export PRIV_SUBNET_ID02=<YOUR-PRIV-SUBNET-ID-02>
# source ./create-sap-assistant.sh

set -x

export STACK_NAME=$(echo $STACK_NAME | tr '[:upper:]' '[:lower:]')
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ARTIFACT_BUCKET_NAME=$ACCOUNT_ID-$STACK_NAME-sap-assistant

aws s3 mb s3://${ARTIFACT_BUCKET_NAME} --region ${AWS_REGION}
aws s3 cp ../agent/ s3://${ARTIFACT_BUCKET_NAME}/agent/ --region ${AWS_REGION} --recursive --exclude ".DS_Store"
aws s3 cp ../cfn/ s3://${ARTIFACT_BUCKET_NAME}/cfn/ --region ${AWS_REGION} --recursive --exclude ".DS_Store"
aws s3 cp ../frontend/ s3://${ARTIFACT_BUCKET_NAME}/frontend/ --region ${AWS_REGION} --recursive --exclude ".DS_Store"

aws cloudformation create-stack \
--stack-name ${STACK_NAME} \
--template-body file://../cfn/sap-assistant-resources-01.yml \
--parameters \
ParameterKey=ArtifactBucket,ParameterValue=${ARTIFACT_BUCKET_NAME} \
ParameterKey=SecurityGroupId,ParameterValue=${SECURITY_GROUP_ID} \
ParameterKey=SubnetId01,ParameterValue=${PRIV_SUBNET_ID01} \
ParameterKey=SubnetId02,ParameterValue=${PRIV_SUBNET_ID02} \
--capabilities CAPABILITY_NAMED_IAM \
--region ${AWS_REGION}

aws cloudformation describe-stacks --stack-name $STACK_NAME --region ${AWS_REGION} --query "Stacks[0].StackStatus"
