## Kubeflow Vanilla
This project demonstrates the process of 

1) Creating an Amazon Elastic Kubernetes Service (EKS) cluster. (this is required to host the KubeFlow platform).

2) Then deploying Kubeflow on the cluster.

3) And running a machine learning (ML) pipeline. (on the KubeFLow platform)

**This is NOT a production ready implementation of Kubeflow. Any AWS credentials used in this project should created in accordance with the principle of least privilege.**

## Prerequisites
- Insall & Configure [AWS access key ID and secret access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-delegated-user.html)
- Install [jq](https://stedolan.github.io/jq/download/) (1.6)
- Install [awscli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html) (v1.18.179)
- Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl) (v1.19.4)
- Install [eksctl](https://eksctl.io) (v0.32.0)
- Install [kfctl](https://github.com/kubeflow/kfctl/releases/tag/v1.2.0) (v1.2.0-0-gbc038f9)

## Deploy EKS Cluster
Before creating the EKS cluster, remove your existing Kubernetes `config` file with the following command:
```
rm -rf /Users/<your-name>/.kube/config
```

Also make sure that you have `v1.2.0` of `kfctl` installed. To remove your existing version of `kfctl` run the following command:
```
rm -rf /usr/local/bin/kfctl
```

Download the `kfctl` from [here](https://github.com/kubeflow/kfctl/releases/tag/v1.2.0), unzip and run the executable. In your `Downloads/` directory, run the following command to add `kfctl` to your path:
```
sudo mv ./kfctl /usr/local/bin/kfctl
```

You can test that you have the correct version of `kfctl` installed by running:
```
kfctl version
```

In the `eks_cluster.yaml` file, set the region to whatever is most appropriate. Then run the following `eksctl` CLI command to create the cluster with reference to the manifest file. If you don't have multiple AWS CLI profiles, you can remove the `--profile` flag from the command.
```
eksctl create cluster -f eks_cluster.yaml --profile ba-ndaly-cli
```

After the EKS cluster has been deployed, you can check if you have access to the cluster by running `kubectl get nodes`.

## Deploy Kubeflow on EKS
Kubeflow can be deployed on the EKS cluster by running the `deploy_kubeflow.sh` shell script. Before doing so, make sure to set the `AWS_REGION` environment variable to match that of region in which the EKS cluster is deployed. The `AWS_CLI_PROFILE` should also be set if you have AWS CLI credentials for multiple AWS accounts. If not you can remove the `--profile` flag from the appropriate AWS CLI command.

To create credentials for secure access to Kubeflow, create the following parameters using the AWS Systems Manager Parameter Store:
- `kubeflow-vanilla-username`
- `kubeflow-vanilla-password`

These parameters should be created in the same region as your EKS cluster. You can use the AWS Management Console to create the parameters or the AWS CLI. For example, a Kubeflow username parameter can be created using the AWS CLI like so:
```
aws ssm put-parameter --name kubeflow-vanilla-username \
    --value '<username>' \
    --type String \
    --profile ba-ndaly-cli
```

Also set a new `USERNAME` and `PASSWORD` that differs from the pair shown. The shell script can be run as follows:
```
sh deploy_kubeflow.sh
```

Once the Kubeflow dashboard has been successfully deployed it can be accessed in two ways:
- Application Load Balancer (ALB)
    - Run `kubectl get ingress -n istio-system` to retrieve the ALB address.
    - Copy and paste the ALB address into a browser and enter the `USERNAME` and `PASSWORD`.
- Port Forwarding via a `port forward` command as shown:
    - Run the following command and enter the `USERNAME` and `PASSWORD`:
    - `kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80`

## Example Kubeflow Pipeline
To implement the example Kubeflow pipeline on an EKS cluster, the pipeline will need to interact with the following AWS services:
- S3
- SageMaker
- Elastic Container Registry (ECR)

To do this, a number of IAM users/roles need to be created and in the case of the users, their credentials need to applied to the cluster as Kubernetes Secrets. Run the following scripts to achieve this, making sure to replace the `AWS_PROFILE` variable value with your own.
```
sh eks_node_iam.sh

sh s3_iam.sh

sagemaker_iam.sh
```

Once you have generated the neccessary IAM roles/users, you are now ready to create a Notebook server in Kubeflow. You can do this by following these steps:
- In the `Quick Shortcuts` card on the Kubeflow homepage, click the `Create a new Notebook server` button.
- For the `Name` field choose whatever is appropriate.
- For the `Image` option we will choose the following Docker image:
    - `527798164940.dkr.ecr.us-west-2.amazonaws.com/tensorflow-1.15.2-notebook-cpu:1.2.0`
- Change the `CPU` value to `1.0` and accept the remaining defaults and click the `Launch` button.
- The Notebook server should take a few minutes to provision.
- Once ready, you can click on the `Connect` button and you will be redirected to a new browser tab with a Jupyter server becoming available.

Now that Jupyter is available, you can upload the `pipeline_notebook.ipynb` to start building the Kubeflow Pipeline.

## Resource Cleanup
Before deleting the EKS cluster, make sure to delete Kubeflow, otherwise the ALB and it's associated IAM roles will not be deleted. This can cause issues when trying to create a new instance of Kubeflow on the same cluster/new cluster with the same name. Kubeflow can be deleted with the following command inside the `kubeflow-platform` directory:
```
 kfctl delete -V -f kubeflow_manifest.yaml
```

In some cases, this command will not completely delete all of the resources that Kubeflow has created. In particular, the following IAM roles may need to be deleted manually before redeploying Kubeflow:
- `kf-admin-eu-west-1-kubeflow-platform`
- `kf-user-eu-west-1-kubeflow-platform`

The associated discussion on GitHub for this issue can be found [here](https://github.com/kubeflow/manifests/issues/1421).

The IAM users/roles created specifically for the Kubeflow Pipeline creation should be deleted. These are:
- `kubeflow-pipeline-sagemaker-user`
- `kubeflow-pipeline-sagemaker-role`
- `kubeflow-pipeline-s3-user`


Once Kubeflow and its associated resources have been deleted, the EKS cluster can be terminated via the following command:
```
eksctl delete cluster -f eks_cluster.yaml --profile ba-ndaly-cli 
```

Make sure to delete the Kubernetes `config` file so that other deployments don't use the wrong details:
```
rm -rf /Users/<your-name>/.kube/config
```

The artifacts generated after the `kfctl build` command can be deleted by running:
```
sh clean_kubeflow_platform.sh
```

The Kubeflow credentials that were created using the AWS Systems Manager Parameter Store can be deleted using the AWS Management Console or via the AWS CLI like so:
```
aws ssm delete-parameter --name kubeflow-vanilla-username --profile ba-ndaly-cli

aws ssm delete-parameter --name kubeflow-vanilla-password --profile ba-ndaly-cli
```

## Additional Resources
- [EKS Workshop](https://eksworkshop.com/)
- [EKS Private Clusters](https://eksctl.io/usage/eks-private-cluster/)
- [MNIST model training script](https://www.eksworkshop.com/advanced/420_kubeflow/kubeflow.files/mnist-tensorflow-jupyter.py)
- [Creating EKS clusters using eksctl](https://eksctl.io/usage/creating-and-managing-clusters/)
- [Updating kubeconfig](https://aws.amazon.com/premiumsupport/knowledge-center/eks-api-server-unauthorized-error/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [AWS CLI Named Profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
- [Kubeflow istio-ingress issue](https://github.com/kubeflow/kubeflow/issues/5192)
- [Uninstalling Kubeflow](https://www.kubeflow.org/docs/aws/deploy/uninstall-kubeflow/)
- [Kubeflow ALB creation issue](https://github.com/kubeflow/kubeflow/issues/3891)
- [Kubeflow v1.2.0 AWS Manifest](https://github.com/kubeflow/manifests/blob/master/kfdef/kfctl_aws.v1.2.0.yaml)

