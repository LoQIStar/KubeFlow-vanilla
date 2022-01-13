#!/bin/sh

# AWS region environment variable
export AWS_REGION=eu-west-2
export REGION=eu-west-2

# EKS cluster name environment variable
export AWS_CLUSTER_NAME=kubeflow-platform

# Sets the AWS CLI profile
export AWS_PROFILE=ba-ndaly-cli

# Updates the Kubenetes config with the new cluster details
aws eks update-kubeconfig --name kubeflow-platform \
    --region eu-west-2

# Retrieves Kubeflow credentials from AWS SSM Parameter store
export KUBEFLOW_USERNAME=$(aws ssm get-parameter --name 'kubeflow-vanilla-username' \
    --profile $AWS_PROFILE \
    --query Parameter.Value \
    --output text)

# Retrieves Kubeflow credentials from AWS SSM Parameter store
export KUBEFLOW_PASSWORD=$(aws ssm get-parameter --name 'kubeflow-vanilla-password' \
    --profile $AWS_PROFILE \
    --query Parameter.Value \
    --output text)

# EKS cluster node role environment variable retrieved using the aws cli and jq
export AWS_CLUSTER_NODE_ROLE=$(aws iam list-roles --profile $AWS_PROFILE\
                | jq -r ".Roles[] \
                | select(.RoleName \
                | startswith(\"eksctl-$AWS_CLUSTER_NAME\") and contains(\"NodeInstanceRole\")) \
                .RoleName")

# Adds the environment variables and dynamically generates the kubeflow manifest file
cat << EOF > kubeflow_manifest.yaml
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  namespace: kubeflow
spec:
  applications:
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: namespaces/base
    name: namespaces
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: application/v3
    name: application
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/istio-1-3-1-stack
    name: istio-stack
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cluster-local-gateway-1-3-1
    name: cluster-local-gateway
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: istio/istio/base
    name: istio
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cert-manager-crds
    name: cert-manager-crds
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cert-manager-kube-system-resources
    name: cert-manager-kube-system-resources
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cert-manager
    name: cert-manager
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: metacontroller/base
    name: metacontroller
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/oidc-authservice
    name: oidc-authservice
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/dex-auth
    name: dex
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: admission-webhook/bootstrap/overlays/application
    name: bootstrap
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: spark/spark-operator/overlays/application
    name: spark-operator
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws
    name: kubeflow-apps
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: aws/istio-ingress/base_v3
    name: istio-ingress
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: knative/installs/generic
    name: knative
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: kfserving/installs/generic
    name: kfserving
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/spartakus
    name: spartakus
  plugins:
  - kind: KfAwsPlugin
    metadata:
      name: aws
    spec:
      auth:
        basicAuth:
          password: ${KUBEFLOW_PASSWORD}
          username: ${KUBEFLOW_USERNAME}
      region: ${AWS_REGION}
      enablePodIamPolicy: true
      #roles:
      #- ${AWS_CLUSTER_NODE_ROLE}
  repos:
  - name: manifests
    uri: https://github.com/kubeflow/manifests/archive/v1.2-branch.tar.gz
  version: v1.2-branch
EOF

# Builds and creates Kubeflow on the EKS cluster
kfctl build -f kubeflow_manifest.yaml -V
kfctl apply -f kubeflow_manifest.yaml -V
