#!/bin/sh

# Sets the AWS CLI profile
export AWS_PROFILE=ba-ndaly-cli

# Creates an IAM user
aws iam create-user --user-name kubeflow-pipeline-sagemaker-user --profile $AWS_PROFILE

# Attaches SageMaker full access IAM policy (not appropriate for production use-cases)
aws iam attach-user-policy --user-name kubeflow-pipeline-sagemaker-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess \
    --profile $AWS_PROFILE

# Outputs AWS credentials for the SageMaker IAM user to a temp file
aws iam create-access-key --user-name kubeflow-pipeline-sagemaker-user --profile $AWS_PROFILE > /tmp/iam_user_output.json

# Sets SageMaker IAM user credentials as environment variables
export AWS_ACCESS_KEY_ID_VALUE=$(jq -j .AccessKey.AccessKeyId /tmp/iam_user_output.json | base64)
export AWS_SECRET_ACCESS_KEY_VALUE=$(jq -j .AccessKey.SecretAccessKey /tmp/iam_user_output.json | base64)

# Deletes the iam_user_output.json file
rm -rf /tmp/iam_user_output.json

# Dynamically creates a Kubernetes Secret manifest and applies it to the EKS cluster
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-secret
  namespace: kubeflow
type: Opaque
data:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID_VALUE
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY_VALUE
EOF

# Trust policy to be attached to the IAM role which grants SageMaker principal permissions to assume the role
TRUST="{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Principal\": { \"Service\": \"sagemaker.amazonaws.com\" }, \"Action\": \"sts:AssumeRole\" } ] }"

# Creates a SageMaker IAM role that assumes the pre-defined trust policy
aws iam create-role --role-name kubeflow-pipeline-sagemaker-role \
    --assume-role-policy-document "$TRUST"

# Attaches a SageMaker full access IAM policy (not appropriate for production use-cases)
aws iam attach-role-policy --role-name kubeflow-pipeline-sagemaker-role  \
    --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess

# Attaches an S3 full access IAM policy (not appropriate for production use-cases)
aws iam attach-role-policy --role-name kubeflow-pipeline-sagemaker-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Outputs the SageMaker IAM role ARN
aws iam get-role --role-name kubeflow-pipeline-sagemaker-role \
    --output text --query 'Role.Arn'