# kafka-streaming-platform-gitops
Building a production-oriented, reproducible streaming platform using Infrastructure as Code, GitOps, secrets management, least-privilege identities, observability, and application delivery.

The Project extends the workflow of the https://developer.confluent.io/courses/data-streaming-systems/create-an-application-delivery-pipeline-with-gitops-exercise/ by Confluent. Improved it to be more closer to mimicking using GITOPS to actually setup and monitor Kafka operations using Confluent Cloud.

This implementation extands the workflow by introducing:

- Terraform-managed Confluent Cloud infrastructure
- separate Terraform and application service accounts
- least-privilege Kafka ACLs
- SOPS + Age encrypted Kubernetes Secrets
- Flux-managed secret reconciliation
- reproducible secret-generation automation
- Prometheus/Grafana/Alertmanager observability

## Phase 1 - Provisioning

### 1. Install Kind

Download Kind binary
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
```
Make it executable and move it to /usr/local/bin:
```bash
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### 2. Create the local Kubernetes cluster

```bash
kind create cluster --name staging
```

### 3. Install Kubectl

Download Kubectl binary
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```
Make it executable and move it to /usr/local/bin:
```bash
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```
Verify the Kubernetes node:
```bash
kubectl get nodes
```

### 4. Verify the Kind context

Run these commands to be absolutely certain you are operating against the local staging cluster:
```bash
kubectl config current-context
```

```bash
kubectl config get-contexts
```

### 5. Install FluxCD

Download installation
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```
Verify the Flux installation:
```bash
flux --version
```
Check Flux prerequisites:
```bash
flux check --pre
```

### 6. Set your Github credentials in local environment

```bash
export GITHUB_USER="YOUR_GITHUB_USERNAME"
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
```

### 7. Bootstrap Flux to Github repo

```bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=<Your_Repo_Name> \
  --context=kind-staging \
  --branch=main \
  --path=./clusters/staging \
  --personal
```

### 8. Verify Flux Integration

Check namespace, you should see **flux-system** after running these command:
```bash
kubectl get namespaces
```
Verify the Flux components such as **helm-controller**, **kustomize**, **notification-controller**, **source-controller** with their status showing running:
```bash
kubectl get pods -n flux-system
```
Check Flux prerequisites:
```bash
flux check --pre
```

## Phase 2 - Infrastructure

### 1. Install Terraform

Download installation Binary
```bash
curl -LO https://releases.hashicorp.com/terraform/1.16.1/terraform_1.16.1_linux_amd64.zip
```
Unzip and move to /usr/local/bin
```bash
unzip -o terraform_1.16.1_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```
Remember to remove the zip file
```bash
rm terraform_1.16.1_linux_amd64.zip
```
Confirm installation
```bash
terraform version
```

### 2. Authenticate Terraform to connect to Confluent Cloud

Connect to Confluent Cloud via CLI
```bash
confluent login --save
```
Enter your email and password in the prompt. Wait for a successful connection, then run the following to create a CLOUD API KEY:
```bash
confluent api-key create --resource cloud
```
Copy the api-key & Secret to a save place and export them as your local environment variables **DO NOT COMMIT THE API DETAILS TO GIT**
```bash
export TF_VAR_confluent_cloud_api_key="YOUR_API_KEY"
export TF_VAR_confluent_cloud_api_secret="YOUR_API_SECRET"
```
Format terraform 
```bash
terraform fmt
```
The Validate terraform 
```bash
terraform validate
```
You should get a "Success! The configuration is valid." message after validating. The run Plan.
```bash
terraform plan
```
Review the plan, then run:
```bash
terraform apply
```
Once the Infrastructure has been provisioned, then move to Phase 3.

## Phase 3 - Gitops Platform

### 1. Install Age

Install Age
```bash
sudo apt update
sudo apt install -y age
```
### 2. Install SOPS

Download SOPS binary
```bash
curl -L \
  -o /tmp/sops \
  "https://github.com/getsops/sops/releases/download/v3.13.3/sops-v3.13.3.linux.amd64"
```
Make it executable and move it to /usr/local/bin:
```bash
chmod +x /tmp/sops
sudo mv /tmp/sops /usr/local/bin/sops
```
### 3. Generate the Age Encryption Key

Create a directory in the root to store the Encrption Key
```bash
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age
```
Generate the encryption key
```bash
age-keygen -o ~/.config/sops/age/keys.txt
```
Retrieve the public key only
```bash
age-keygen -y ~/.config/sops/age/keys.txt > clusters/staging/public.agekey
```
### 4. Create the Flux SOPS Secret

Create a SOPS-AGE Secret in the flux-system namespace
```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
```

### 5. Create the encrypted Kafka credentials

Create a SOPS-AGE Secret in the flux-system namespace
```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
```
### 6. Create the Customer-event namespace

Create a customer-event namespace
```bash
kubectl create namespace customer-events
```
### 7. Create an encrypted Kafka credential

First make the script executable
```bash
chmod +x scripts/create-orders-secret.sh
```
The execute the script 
```bash
./scripts/create-orders-secret.sh
```

### 8. Extend the generated flux bootstrap configuration with SOPS Decryption

Add the following code block to clusters/staging/flux-system/gotk-sync.yaml Place it between the second resource **spec** and **sourceref**. This is to extend the generated Fluxx bootstrap configuration with SOPS decryption.
```bash
decryption:
    provider: sops
    secretRef:
      name: sops-age
```