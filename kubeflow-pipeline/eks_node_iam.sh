#!/bin/sh

# Sets the AWS CLI profile
export AWS_PROFILE=ba-ndaly-cli

# Retrieves the EKS cluster node IAM role environment variable using the AWS CLI and jq
export AWS_CLUSTER_NODE_ROLE=$(aws iam list-roles --profile $AWS_PROFILE\
                | jq -r ".Roles[] \
                | select(.RoleName \
                | startswith(\"eksctl-$AWS_CLUSTER_NAME\") and contains(\"NodeInstanceRole\")) \
                .RoleName")

# Attaches an S3 full access IAM policy (not appropriate for production use-cases)
aws iam attach-role-policy --role-name $AWS_CLUSTER_NODE_ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Attaches an ECR full access IAM policy (not appropriate for production use-cases)
aws iam attach-role-policy --role-name $AWS_CLUSTER_NODE_ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

# Attaches a SageMaker full access IAM policy (not appropriate for production use-cases)
aws iam attach-role-policy --role-name $AWS_CLUSTER_NODE_ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess