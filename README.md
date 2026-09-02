# kafka-streaming-platform-gitops
Build a local Kubernetes-based GitOps platform that automatically deploys and updates Kafka streaming applications connected to Confluent Cloud.

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
The Plan command should output:

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with
the following symbols:
  + create

Terraform will perform the following actions:

  # confluent_environment.staging will be created
  + resource "confluent_environment" "staging" {
      + display_name  = "kafka-streaming-platform-staging"
      + id            = (known after apply)
      + resource_name = (known after apply)

      + stream_governance (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.

