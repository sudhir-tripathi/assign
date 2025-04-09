# Mane Flask ECS App Deployment

This project deploys a containerized Flask application to AWS ECS Fargate using a complete CI/CD pipeline via AWS CodePipeline. All infrastructure is provisioned using AWS CloudFormation based on the Well-Architected Framework principles.

## 📦 Contents

- `app.py` – Flask application
- `Dockerfile` – Container definition for Flask app
- `buildspec.yml` – CodeBuild configuration for Docker build & ECR push
- `mane-flask-ecs.yml` – CloudFormation template for full infrastructure

## 🌍 AWS Region

Deployment target: **ap-south-1 (Mumbai)**

---

## 🚀 Deployment Guide

### 1. 🧑‍💻 Prerequisites

- AWS CLI configured (`aws configure`)
- A GitHub repository with:
  - `app.py`, `Dockerfile`, `buildspec.yml`
  - Optionally: `mane-flask-ecs.yml` for reference
- GitHub Personal Access Token (PAT) with `repo` and `admin:repo_hook` scopes

---

### 2. 🛠 Deploy CloudFormation Stack

**Option A: Using AWS Console**

1. Go to [CloudFormation console](https://console.aws.amazon.com/cloudformation/)
2. Click **Create stack → With new resources (standard)**
3. Upload `mane-flask-ecs.yml` or use an S3 URL
4. Provide parameters:
   - `GitHubOwner`: Your GitHub username or org
   - `GitHubRepo`: Name of your repo
   - `GitHubBranch`: Branch to build from (default: `main`)
   - `GitHubOAuthToken`: Your GitHub PAT
5. Accept IAM capabilities and deploy

**Option B: Using AWS CLI**

```bash
aws cloudformation create-stack \
  --stack-name ManeFlaskAppStack \
  --template-body file://mane-flask-ecs.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=GitHubOwner,ParameterValue=yourgithubname \
               ParameterKey=GitHubRepo,ParameterValue=your-repo \
               ParameterKey=GitHubBranch,ParameterValue=main \
               ParameterKey=GitHubOAuthToken,ParameterValue=your_token
