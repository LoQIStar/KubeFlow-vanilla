#!/bin/sh

# Sets the AWS CLI profile
export AWS_PROFILE=ba-ndaly-cli

# Creates an IAM user to grant S3 permissions
aws iam create-user --user-name kubeflow-pipeline-s3-user --profile $AWS_PROFILE

# Attaches an S3 full access IAM policy (not appropriate for production use-cases)
aws iam attach-user-policy --user-name kubeflow-pipeline-s3-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
    --profile $AWS_PROFILE

# Outputs AWS credentials for the S3 IAM user to a temp file
aws iam create-access-key --user-name kubeflow-pipeline-s3-user --profile $AWS_PROFILE > /tmp/iam_user_output.json

# Sets the S3 IAM user credentials as environment variables
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
type: Opaque
data:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID_VALUE
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY_VALUE
EOF