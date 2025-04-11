# Flask ECS Fargate Multi-Stack Deployment with CI/CD Pipeline

This project deploys a containerized Flask web application to AWS ECS Fargate using a set of **three distinct CloudFormation stacks** for network, application, and CI/CD resources. This modular approach follows AWS Well-Architected Framework principles for better manageability and separation of concerns. It includes a fully automated CI/CD pipeline using AWS CodePipeline and AWS CodeBuild, triggered by pushes to a specified GitHub repository branch.

## Architecture Overview

The infrastructure is divided into three layers, deployed sequentially:

1.  **Network Stack (`network-stack.yml`)**:
    *   Creates the foundational network: VPC, Public & Private Subnets across 2 AZs, Internet Gateway, NAT Gateway, Route Tables.
    *   Exports VPC and Subnet IDs for use by the Application Stack.

2.  **Application Stack (`app-stack.yml`)**:
    *   Imports Network Stack outputs.
    *   Creates application-specific resources: ECR Repository, ECS Cluster, Task Definition (Fargate), ECS Service, Application Load Balancer (ALB), Target Group, Listener, Security Groups (ALB & ECS), ECS Auto Scaling, and necessary IAM Roles.
    *   Requires a placeholder image in ECR for initial deployment.
    *   Exports ECR Repo Name, Cluster Name, Service Name, ALB DNS, etc., for use by the Pipeline Stack and for access.

3.  **Pipeline Stack (`pipeline-stack.yml`)**:
    *   Imports Application Stack outputs.
    *   Creates the CI/CD pipeline: S3 Artifact Bucket, CodeBuild Project (with permissions to push to ECR), CodePipeline (Source: GitHub -> Build: CodeBuild -> Deploy: ECS), and necessary IAM Roles.

## 📦 Contents

This repository should contain:

-   `app.py` – Your Flask application code.
-   `Dockerfile` – Container definition for the Flask app (ensure it exposes the correct port, e.g., 5000).
-   `buildspec.yml` – CodeBuild configuration for Docker build, ECR push, and `imagedefinitions.json` generation.
-   `network-stack.yml` – CloudFormation template for network resources.
-   `app-stack.yml` – CloudFormation template for application (ECS, ALB, ECR) resources.
-   `pipeline-stack.yml` – CloudFormation template for CI/CD (CodePipeline, CodeBuild) resources.
-   `README.md` – This file.

## 🌍 AWS Region

Default Deployment Target: **ap-south-1 (Mumbai)**
(Ensure Availability Zones in `network-stack.yml` are valid if changing regions).

---

## 🚀 Deployment Guide

Deploy the stacks **sequentially** as described below. Dependencies require this order.

### 1. 🧑‍💻 Prerequisites

-   **AWS Account & CLI:** Configured AWS CLI (`aws configure`) with permissions to create VPC, ECS, ECR, ALB, S3, CodePipeline, CodeBuild, IAM resources, etc.
-   **GitHub Repository:** Your repository containing the application code (`app.py`), `Dockerfile`, and `buildspec.yml`.
-   **GitHub Personal Access Token (PAT):** Generate a PAT with `repo` scope (for private repos) or `public_repo` scope (for public repos). **Treat this token securely.** It will be passed as a parameter during pipeline stack deployment.
-   **Docker:** Docker installed locally. Needed *only* for the initial placeholder image push (Step 3).

---

### 2. 🔸 Deploy Network Stack

This creates the VPC and subnets.

```bash
# Choose a stack name (e.g., mane-network-stack)
NETWORK_STACK_NAME="mane-network-stack"
AWS_REGION="ap-south-1"

echo "Deploying Network Stack: ${NETWORK_STACK_NAME}..."
aws cloudformation deploy \
  --template-file network-stack.yml \
  --stack-name ${NETWORK_STACK_NAME} \
  --capabilities CAPABILITY_IAM \
  --region ${AWS_REGION}
echo "Network Stack deployment initiated."
```
Wait for the stack creation to complete. Note the NETWORK_STACK_NAME used.

### 3. 🖼️ Manually Push Placeholder Image to ECR

Why? The app-stack creates an ECS Task Definition which requires a valid container image URI during its initial creation. The pipeline hasn't run yet, so your actual application image doesn't exist in ECR. We must push any valid image (e.g., hello-world) tagged as latest to the ECR repository before deploying the app stack for the first time.

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-south-1"
ECR_REPO_NAME="mane-flask-app"

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker pull hello-world:latest
docker tag hello-world:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest
```

### 4. 🏗️ Deploy Application Stack

```bash
APP_STACK_NAME="mane-app-stack"
NETWORK_STACK_NAME="mane-network-stack"
ECR_REPO_NAME_PARAM="mane-flask-app"
AWS_REGION="ap-south-1"

echo "Deploying Application Stack: ${APP_STACK_NAME}..."
aws cloudformation deploy \
  --template-file app-stack.yml \
  --stack-name ${APP_STACK_NAME} \
  --parameter-overrides \
      NetworkStackName=${NETWORK_STACK_NAME} \
      EcrRepoName=${ECR_REPO_NAME_PARAM} \
  --capabilities CAPABILITY_IAM \
  --region ${AWS_REGION}
echo "Application Stack deployment initiated."
```

### 5. 🚀 Deploy Pipeline Stack

```bash
PIPELINE_STACK_NAME="mane-pipeline-stack"
APP_STACK_NAME="mane-app-stack"
AWS_REGION="ap-south-1"

# Replace with actual values
GITHUB_OWNER="your-github-username"
GITHUB_REPO="your-flask-app-repo"
GITHUB_BRANCH="main"
GITHUB_TOKEN="ghp_YourGitHubPersonalAccessToken"

echo "Deploying Pipeline Stack: ${PIPELINE_STACK_NAME}..."
aws cloudformation deploy \
  --template-file pipeline-stack.yml \
  --stack-name ${PIPELINE_STACK_NAME} \
  --parameter-overrides \
      AppStackName=${APP_STACK_NAME} \
      GitHubOwner=${GITHUB_OWNER} \
      GitHubRepo=${GITHUB_REPO} \
      GitHubBranch=${GITHUB_BRANCH} \
      GitHubOAuthToken=${GITHUB_TOKEN} \
  --capabilities CAPABILITY_IAM \
  --region ${AWS_REGION}
echo "Pipeline Stack deployment initiated."
```

---

## ✅ Post-Deployment

- **Find ALB DNS:** Go to the Application Stack (e.g., `mane-app-stack`) Outputs tab for `ALBDNSName`.
- **Access Application:** Open the DNS name in your browser.
- **Trigger Pipeline:** Push a new commit to GitHub to trigger deployment:
```bash
git commit -m "Trigger pipeline deployment" --allow-empty
git push origin ${GITHUB_BRANCH}
```
- **Monitor Pipeline:** AWS Console > CodePipeline > Your Pipeline.
- **Logs:** View container logs in CloudWatch (log group from `app-stack.yml`).

---

## 🪑 Cleanup

**Reverse order of deletion:**

### Delete Pipeline Stack
```bash
aws cloudformation delete-stack --stack-name mane-pipeline-stack --region ap-south-1
aws cloudformation wait stack-delete-complete --stack-name mane-pipeline-stack --region ap-south-1
```
Manually empty and delete the S3 bucket if needed.

### Delete Application Stack
```bash
aws cloudformation delete-stack --stack-name mane-app-stack --region ap-south-1
aws cloudformation wait stack-delete-complete --stack-name mane-app-stack --region ap-south-1
```
Manually delete the ECR repository (delete images first).

### Delete Network Stack
```bash
aws cloudformation delete-stack --stack-name mane-network-stack --region ap-south-1
aws cloudformation wait stack-delete-complete --stack-name mane-network-stack --region ap-south-1
```

---

## 🔧 Customization

- **Parameters:** Override via `--parameter-overrides` or edit templates.
- **Region:** Change `AWS_REGION` and AZs in `network-stack.yml`.
- **Build:** Modify `buildspec.yml` for tests, env vars, etc.
- **Task Definition:** Tune CPU/memory, ports, env vars in `app-stack.yml`.
- **Security:** Harden security groups and IAM policies for production.