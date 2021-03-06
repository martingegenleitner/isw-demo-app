# Demo App for Information Security World

Small PHP Demo App that stores and displays a simple picture. It will be used to demonstrate transparent encryption of application data in container environments with THALES CipherTrust Transparent Encryption for Container Storage Interface (CTE CSI) on Kubernetes.

Watch the [video](demo-video.mkv) to see the final setup in action!

## Run the app locally

```shell
# Checkout the repo and change into its root directory
cd isw-demo-app
# Build the image
docker build -t isw-demo-app .
# Run the app and listen on the local port 8888
docker run -d --name isw-demo-app -p 8888:80 isw-demo-app
# Stop and remove the container and image to clean up
docker stop isw-demo-app
docker rm isw-demo-app
docker rmi isw-demo-app
```

## Push app to DockerHub

```shell
# Build the app with the desired tag
docker build -t isw-demo-app .
# Push the image to the registry
docker push isw-demo-app
```

## Create EKS Cluster

Terraform files have been stolen from <https://github.com/hashicorp/learn-terraform-provision-eks-cluster> and instructions are taken from the offical terraform training site (<https://learn.hashicorp.com/tutorials/terraform/eks>).

```shell
# Move to the terraform files
cd isw-demo-app/terraform/eks

# (optional) Ensure you are logged in via AWS CLI
aws configure
aws sts get-caller-identity

# Initialize terraform workspace
terraform init
# Deploy resources
terraform apply

# Merge k8s context to use EKS with kubectl
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)

# When you are finished using the EKS, destroy it to reduce costs
terraform destroy
```

## Create GKE Cluster

Terraform files have been stolen from <https://github.com/hashicorp/learn-terraform-provision-gke-cluster> and instructions are taken from the official terraform training site (<https://learn.hashicorp.com/tutorials/terraform/gke>). The file `terraform/gke/gke.tf` has been adjusted to include all OAuth-Scopes to allow GKE to fetch images from GCR.

```shell
# Move to the terraform files
cd isw-demo-app/terraform/gke

# Ensure your gcloud is initialized and connected to your account
gcloud init
gcloud auth application-default login

# Initialize terraform workspace
terraform init
# Deploy resources
terraform apply

# Merge k8s context to use GKE with kubectl
gcloud container clusters get-credentials $(terraform output -raw kubernetes_cluster_name) --region $(terraform output -raw region)

# When you are finished using the GKE, destroy it to reduce costs
terraform destroy
```

## Create KMS in Azure

```shell
# List available images/versions of k170v
az vm image list --offer cm_k170v --all

# Accept the license terms
az vm image terms accept --urn <image_urn>

# Create vm from image
az vm create --resource-group MartinGegenleitner --name isw-cm-2 --image thalesdiscplusainc1596561677238:cm_k170v:ciphertrust_manager:2.7.6808 --size Standard_DS3_v2 --admin-username ksadmin --ssh-key-name isw-cm-1_key --public-ip-sku Basic --vnet-name isw --location northeurope --subnet default
```

## Configure the Key Management Service

Perform the following steps on the vanilla CipherTrust-Manager created on Azure to prepare the endpoints for the CTE CSI integration.

1. Perform initial config of the appliance.
   1. Set SSH-key
   2. Set initial admin password
   3. Configure interface `web` as desired
2. Create a simple registration token in the Menu of Access Management -> Registration Tokens.
   1. Important: Set the usage limit to a high value as registrations and deregistrations on every creation of a Pod using CTE CSI. Recommondation for PoC: 1000
3. Configure CTE CSI - change to the CTE product tile
   1. On the K8s Storage Groups, create a new Storage Group with the following parameters. It is important to choose values that later match the parameter values from `k8s/cte-storageclass.yaml`
      1. Name = isw-storage-group
      2. StorageClass = cte-csi-sc
      3. Namespace = default
   2. Within the new storage group, create a new GuardPolicy of type `Container Storage Interface` and choose the name `op-encrypt-only` as it is important that the name matches the parameter `ctePolicy` in the PVC configured at `k8s/cte-claim.yaml`.

## Deploy the app on Kubernetes

### Deploy ingress with letsencrypt

Taken from <https://www.fosstechnix.com/kubernetes-nginx-ingress-controller-letsencrypt-cert-managertls/>

```shell
# Install nginx ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
# Check ingress and public service endpoint
kubectl get services

#############
# !!! Now apply DNS configuration to map your choosen DNS names to the kubernetes service endpoint!
#############

# Install certmanager for cluster
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.1/cert-manager.yaml

# Create clusterissuer
kubectl apply -f cluster-issuer.yaml

# Create certificate
kubectl apply -f (eks|gke)-letsencrypt-cert.yaml

# Create ingress
kubectl apply -f (eks|gke)-ingress.yaml
```

### Deploy CTE-CSI Storage driver

Checkout the repository from <https://github.com/thalescpl-io/cte-csi-deploy> and run...

```shell
./deploy.sh -u=thalesctecsi -p=08b2059e-2c46-4439-90ba-1ed9641f71a0
```

... in `bash`.

### Deploy the actual applications

Before you begin to apply configuration to the cluster, make sure the files `k8s/cte-storageclass.yaml` and `k8s/cte-claim.yaml` contain the correct values from your key management setup!

```shell
# Ensure to be in the correct directory
cd <GIT_REPO_PATH>/k8s

# Deploy the PV and PVC for the actual storage over NFS
kubectl apply -f (eks|gke)-nfs-claim.yaml

# Create the storage class and PVC for CTE CSI
kubectl apply -f cte-storageclass.yaml

# Finally deploy the application
kubectl apply -f app-deployment.yaml
```
