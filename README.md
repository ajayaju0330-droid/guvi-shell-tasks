# Project 1 — Application Deployment: Brain Tasks App

## Overview
This project containerizes the **Brain Tasks App** (a pre-built Vite/React static site) and deploys it to **AWS EKS (Elastic Kubernetes Service)**, with the container image stored in **Amazon ECR**. The app is exposed to the internet via a Kubernetes `LoadBalancer` service.

- **Source app:** [Vennilavanguvi/Brain-Tasks-App](https://github.com/Vennilavanguvi/Brain-Tasks-App) (original static build)
- **Deployment repo:** [ajayaju0330-droid/Brain-Storm-App](https://github.com/ajayaju0330-droid/Brain-Storm-App) (Dockerfile, deployment.yaml, buildspec.yml)
- **Live app URL:** http://aceef156c35d54adfbb839b3f4ed5580-718151067.us-west-2.elb.amazonaws.com:3000
- **LoadBalancer ARN:** `arn:aws:elasticloadbalancing:us-west-2:196390795947:loadbalancer/aceef156c35d54adfbb839b3f4ed5580`

---

## Architecture

```
GitHub Repo (Brain-Tasks-App)
        │
        ▼
  EC2 Build Host (Docker, AWS CLI, kubectl, eksctl)
        │
        ▼
   Docker Image (nginx:alpine + built dist/)
        │
        ▼
   Amazon ECR (private repository)
        │
        ▼
  Amazon EKS Cluster (brain-tasks-cluster)
    ├── Managed Node Group (2x t3.medium)
    ├── Deployment (2 replicas)
    └── Service (type: LoadBalancer)
        │
        ▼
   Public Internet (Classic ELB on port 3000)
```

---

## Prerequisites

- AWS account with IAM user credentials (ECR, EKS, EC2, CloudFormation, ELB permissions)
- EC2 instance (Ubuntu 22.04, t2.medium or larger)
- Installed on the EC2 instance:
  - Docker
  - AWS CLI v2
  - `kubectl`
  - `eksctl`

---

## Step-by-Step Setup

### 1. Launch the build EC2 instance
- Ubuntu Server 22.04 LTS, `t2.medium`, 20 GB storage
- Security group: allow SSH (22)

### 2. Install Docker
```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
# log out and reconnect for group change to take effect
```

### 3. Clone the app repository
```bash
git clone https://github.com/Vennilavanguvi/Brain-Tasks-App.git
cd Brain-Tasks-App
```
> Note: this repo ships a **pre-built** static site (`dist/` folder only — no `src/`), so no Node build stage is required.

### 4. Write the Dockerfile
```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 80
```
> nginx is kept on its default internal port 80; the Kubernetes Service later maps external port 3000 → container port 80.

### 5. Build and test locally
```bash
docker build -t brain-tasks-app .
docker run -d -p 3000:80 --name test-run brain-tasks-app
curl -4 http://127.0.0.1:3000
docker stop test-run && docker rm test-run
```

### 6. Push the image to Amazon ECR
```bash
# Create the ECR repo (brain-tasks-app) via the console first

aws configure   # set access key, secret key, region (us-west-2), output format (json)

aws ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

docker tag brain-tasks-app:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/brain-tasks-app:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/brain-tasks-app:latest
```

### 7. Install kubectl and eksctl
```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### 8. Create the EKS cluster and node group
```bash
eksctl create cluster \
  --name brain-tasks-cluster \
  --region us-west-2 \
  --nodegroup-name brain-tasks-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

**Core addons** (VPC CNI, kube-proxy, CoreDNS) must be present for nodes to register as healthy:
```bash
eksctl create addon --cluster brain-tasks-cluster --region us-west-2 --name vpc-cni --force
eksctl create addon --cluster brain-tasks-cluster --region us-west-2 --name kube-proxy --force
eksctl create addon --cluster brain-tasks-cluster --region us-west-2 --name coredns --force
```

```bash
aws eks update-kubeconfig --region us-west-2 --name brain-tasks-cluster
kubectl get nodes
```

### 9. Deploy the app to the cluster
`deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: brain-tasks-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: brain-tasks-app
  template:
    metadata:
      labels:
        app: brain-tasks-app
    spec:
      containers:
      - name: brain-tasks-app
        image: <account-id>.dkr.ecr.us-west-2.amazonaws.com/brain-tasks-app:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: brain-tasks-service
spec:
  type: LoadBalancer
  selector:
    app: brain-tasks-app
  ports:
  - protocol: TCP
    port: 3000
    targetPort: 80
```

```bash
kubectl apply -f deployment.yaml
kubectl get pods
kubectl get service brain-tasks-service
```

### 10. Access the app
```
http://<EXTERNAL-IP>:3000
```

---

## Troubleshooting Notes (encountered during this deployment)

| Issue | Cause | Fix |
|---|---|---|
| `curl localhost:3000` returned "Connection reset by peer" | curl resolving to IPv6 first while nginx bound IPv4 | Used `curl -4` to force IPv4, or tested via `127.0.0.1` |
| `eksctl create cluster` appeared to hang after the control-plane stack finished | The `eksctl` CLI process itself stalled locally, even though the AWS-side CloudFormation stack completed | Verified stack status directly via `aws cloudformation describe-stacks`; killed the hung process and re-ran node group creation with `eksctl create nodegroup` separately |
| Node group creation failed with `NodeCreationFailure: Unhealthy nodes` | Core EKS addons (VPC CNI, kube-proxy, CoreDNS) were not installed, so nodes couldn't complete registration | Installed all three addons via `eksctl create addon`, then deleted the failed (`ROLLBACK_COMPLETE`) CloudFormation stack (after disabling termination protection) and retried |
| `eksctl create nodegroup` skipped creation, reporting the node group already existed | Stale reference to the previously failed node group stack | Deleted the leftover `ROLLBACK_COMPLETE` stack via `aws cloudformation delete-stack`, then retried cleanly |
| Deleting the stale stack failed with a termination-protection error | `eksctl` enables termination protection on the stacks it creates | Ran `aws cloudformation update-termination-protection --no-enable-termination-protection`, then deleted the stack |
| `git push` to the original repo returned 403 | The source repo belongs to another GitHub account | Created my own repository and pushed to it using a personal access token |
| CodeBuild project creation failed: role name already exists | A role from an earlier attempt was left behind | Used a different service role name |
| Pipeline did not start on `git push` | GitHub App was authorized but not installed on the repo, so GitHub could not notify AWS | Installed the AWS Connector for GitHub app on the repo and created a new connection |
| New GitHub connection kept redirecting to `us-east-1` | The install callback URL carried `region=us-east-1` | Re-created the connection from the CodePipeline console in `us-west-2` |
| Pipeline Source stage failed: "provided role does not have sufficient permissions" | Pipeline role only allowed the old connection | Added an inline policy granting `UseConnection` on the new connection ARN |

---

## CI/CD Pipeline (CodeBuild + CodePipeline)

Every push to the `main` branch of the deployment repo automatically builds a new image, pushes it to ECR and redeploys it to EKS.

```
git push → GitHub (main) → CodePipeline (Source) → CodeBuild (build, push, deploy) → EKS rolling restart
```

### 11. CodeBuild project (`brain-tasks-build`)
- Source: GitHub repo `ajayaju0330-droid/Brain-Storm-App`
- Environment: Amazon Linux, standard image, **privileged mode enabled** (required for Docker builds)
- Environment variable: `ECR_REPO_URI` = `<account-id>.dkr.ecr.us-west-2.amazonaws.com/brain-tasks-app`
- Service role permissions:
  - `AmazonEC2ContainerRegistryPowerUser` (push images to ECR)
  - Inline policy allowing `eks:DescribeCluster` (for `aws eks update-kubeconfig`)
- EKS access: the CodeBuild role is registered on the cluster so `kubectl` works inside the build:
```bash
aws eks create-access-entry --cluster-name brain-tasks-cluster --region us-west-2 \
  --principal-arn arn:aws:iam::<account-id>:role/service-role/<codebuild-role>

aws eks associate-access-policy --cluster-name brain-tasks-cluster --region us-west-2 \
  --principal-arn arn:aws:iam::<account-id>:role/service-role/<codebuild-role> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### 12. `buildspec.yml`
```yaml
version: 0.2

phases:
  install:
    commands:
      - echo Installing kubectl...
      - curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
      - chmod +x ./kubectl
      - mv ./kubectl /usr/local/bin/kubectl
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REPO_URI
  build:
    commands:
      - echo Building Docker image...
      - docker build -t brain-tasks-app .
      - docker tag brain-tasks-app:latest $ECR_REPO_URI:latest
  post_build:
    commands:
      - echo Pushing image to ECR...
      - docker push $ECR_REPO_URI:latest
      - echo Updating kubeconfig...
      - aws eks update-kubeconfig --region us-west-2 --name brain-tasks-cluster
      - echo Deploying to EKS...
      - kubectl apply -f deployment.yaml
      - kubectl rollout restart deployment brain-tasks-app
```

### 13. CodePipeline (`brain-tasks-pipeline`)
- **Source stage:** GitHub (via GitHub App) connection, repo `ajayaju0330-droid/Brain-Storm-App`, branch `main`, trigger on push to `main`
- **Build stage:** AWS CodeBuild project `brain-tasks-build`
- **Deploy stage:** not a separate stage, because the build's `post_build` phase runs `kubectl apply` and a rolling restart against the EKS cluster
- Requirements for the GitHub connection:
  - The **AWS Connector for GitHub** app must be *installed* on the repository (authorization alone is not enough for push triggers)
  - The connection must be created in the same region as the pipeline (us-west-2)
  - The pipeline service role needs `codeconnections:UseConnection` on that connection's ARN

### 14. Logging with CloudWatch
- **Build logs:** CodeBuild writes to the log group `/aws/codebuild/brain-tasks-build`
- **Application (pod) logs:** the `amazon-cloudwatch-observability` EKS addon runs Fluent Bit and CloudWatch agent pods on every node and ships container logs to `/aws/containerinsights/brain-tasks-cluster/application`
- The node IAM role needs `CloudWatchAgentServerPolicy`:
```bash
aws iam attach-role-policy \
  --role-name <node-instance-role> \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

eksctl create addon --cluster brain-tasks-cluster --region us-west-2 \
  --name amazon-cloudwatch-observability --force

kubectl get pods -n amazon-cloudwatch
```

---

## Deliverables Checklist

- [x] Dockerized application
- [x] Image pushed to Amazon ECR
- [x] EKS cluster and node group provisioned
- [x] Kubernetes Deployment + LoadBalancer Service applied
- [x] App verified live and accessible
- [x] LoadBalancer ARN captured
- [x] CodeBuild project and `buildspec.yml`
- [x] CodePipeline (GitHub → CodeBuild → EKS), verified with a push-triggered run
- [x] CloudWatch Logs (build logs and application logs)
- [x] Screenshots compiled

---

## Screenshots

Stored in the `screenshots/` folder of the repo.

| File | Shows |
|---|---|
| `01-ec2-launched.png` | EC2 build host running |
| `02-docker-installed.png` | Docker installed |
| `03-repo-cloned.png` | App repo cloned |
| `04-dockerfile-created.png` | Dockerfile contents |
| `05-image-built.png` | Docker image built |
| `06-local-test.png` | App served locally from the container |
| `07-ecr-repo-created.png` | ECR repository created |
| `08-image-pushed-ecr.png` | Image pushed to ECR |
| `09-kubectl-eksctl-installed.png` | kubectl and eksctl versions |
| `10-eks-cluster-nodegroup-created.png` | EKS node group created |
| `11-kubectl-get-nodes.png` | Both nodes `Ready` |
| `12-deployment-yaml-created.png` | Deployment and Service manifest |
| `13-pods-running.png` | Pods running |
| `14-loadbalancer-service.png` | LoadBalancer service with external hostname |
| `15-app-live-browser.png` | App live in the browser |
| `16-github-repo-pushed.png` | Files pushed to GitHub |
| `17-codebuild-project-created.png` | CodeBuild project |
| `18-codebuild-role-ecr-policy.png` | ECR policy on the CodeBuild role |
| `19-codebuild-role-eks-policy.png` | EKS inline policy on the CodeBuild role |
| `20-eks-access-entry.png` | CodeBuild role registered on the EKS cluster |
| `21-buildspec-updated.png` | Final `buildspec.yml` |
| `22-buildspec-pushed.png` | `buildspec.yml` pushed to GitHub |
| `23-codebuild-test-run.png` | Manual CodeBuild run succeeded |
| `24-pipeline-source-stage.png` | Pipeline source stage configuration |
| `25-pipeline-build-stage.png` | Pipeline review with the build stage |
| `26-pipeline-succeeded.png` | First pipeline run succeeded |
| `27-new-connection-available.png` | New GitHub connection available |
| `28-pipeline-source-new-connection.png` | Pipeline saved with the new connection |
| `29-pipeline-role-connection-policy.png` | Pipeline role permission for the connection |
| `30-pipeline-rerun-succeeded.png` | Pipeline re-run succeeded |
| `31-pipeline-auto-trigger.png` | Run triggered automatically by a commit |
| `32-cloudwatch-build-logs.png` | CodeBuild logs in CloudWatch |
| `33-node-role-cloudwatch-policy.png` | CloudWatch policy on the node role |
| `34-cloudwatch-addon-pods.png` | CloudWatch addon pods running |
| `35-cloudwatch-app-logs.png` | Application logs in CloudWatch |
