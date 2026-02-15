# Chaos Engineering & Resilience Platform

## Overview
This repository contains a **Chaos Engineering Platform** built with **Next.js** and deployed on **AWS EKS** (Elastic Kubernetes Service) using **Terragrunt** for Infrastructure as Code (IaC) and **ArgoCD** for GitOps-based delivery.

The platform is designed to simulate infrastructure failures and stress tests to validate system resilience.

## 🏗 Repository Structure

```
├── chaos-app/                     # The application source code (Next.js)
│   ├── app/api/               # Chaos Experiments API (kill, stress, health)
│   └── Dockerfile             # Multi-stage Docker build
│
├── charts/                        # Helm Charts
│   └── chaos-generic/         # Generic Helm chart for deploying the application
│
├── argocd-apps/                   # GitOps Configuration (ArgoCD)
│   ├── apps/                  # Application definitions (Workloads & Infrastructure)
│   └── clusters/              # Cluster-level Bootstrap (App of Apps)
│
├── infrastructure-live/           # Infrastructure as Code (Terragrunt)
│   ├── _env/                      # DRY configurations (inherit-based architecture)
│   │   ├── addons.hcl             # EKS Addons (ArgoCD, Metrics Server, etc.)
│   │   ├── eks.hcl                # EKS Cluster definition
│   │   ├── rds.hcl                # RDS Postgres configuration
│   │   └── vpc.hcl                # VPC Network configuration
│   │
│   └── dev/us-east-1/dev-cluster/ # Development Environment Instantiation
│       ├── eks/                   # Inherits from _env/eks.hcl
│       ├── vpc/                   # Inherits from _env/vpc.hcl
│       ├── rds/                   # Inherits from _env/rds.hcl
│       └── addons/                # Inherits from _env/addons.hcl
│
├── .github/workflows/             # CI/CD Pipelines (GitHub Actions)
└── deploy.sh                      # Automated deployment script
```

## 🚀 Key Components

### 1. Application (`chaos-app`)
- **Framework**: Next.js 14 (React 19).
- **Chaos Features**:
    - **`/api/kill`**: Triggers a hard crash (`process.exit(1)`).
    - **`/api/stress`**: CPU stress test using worker threads.
- **Build**: Uses a multi-stage `Dockerfile` producing a standalone output for efficiency.

### 2. Infrastructure (`infrastructure-live`)
Managed via **Terragrunt** to keep configurations DRY.
- **EKS Cluster**: Version `1.29` with Spot Instances using Cluster Autoscaler.
- **Database**: Postgres 16 on managed RDS.
- **Connectivity**: Private subnets with NAT Gateways, ALB Ingress Controller.

### 3. GitOps & ArgoCD (`argocd-apps`)
The platform uses the **App of Apps** pattern:
- **`clusters/`**: Defines the root Application that points to `apps/`.
- **`apps/`**: Contains `infrastructure` (ingress-nginx, prometheus) and `workloads` (chaos-app) definitions.

### 4. CI/CD (`.github/workflows`)
- **Build & Push**: Builds the Docker image and pushes to Amazon ECR.
- **Deploy**: Updates the Helm chart version in the Git repository, triggering ArgoCD to sync the new version.

## 🛠 Usage

### 📋 Prerequisites
Please refer to [USER_REQUIREMENTS.md](USER_REQUIREMENTS.md) for detailed setup instructions.

### 🚀 Quick Start (Recommended)
This repository includes a fully automated deployment script for any AWS account.

```bash
chmod +x deploy.sh
./deploy.sh --env dev
```

**What this does:**
1.  **Auto-detects** your AWS Account and Region.
2.  **Initializes & Deploys** all infrastructure via Terragrunt.
3.  **Configures** `kubectl` for the new EKS cluster.
4.  **Deploys** ArgoCD applications to `dev` environment.

### 🔧 Manual Deployment
If you prefer manual steps:

1.  **Deploy Infrastructure**:
    ```bash
    cd infrastructure-live/dev/us-east-1/dev-cluster
    terragrunt run-all apply
    ```

2.  **Configure Access**:
    ```bash
    aws eks update-kubeconfig --name chaos-dev-cluster --region us-east-1
    ```

3.  **Deploy Application (GitOps)**:
    ```bash
    # Apply the App-of-Apps bootstrap
    kubectl apply -f argocd-apps/clusters/dev.yaml
    ```

## 🎯 Accessing the Platform

### ArgoCD UI
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Forward port
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

### Chaos Application
```bash
# Get Load Balancer URL
kubectl get ingress -n dev
```

## 🧹 Cleanup
To destroy all resources:
```bash
cd infrastructure-live/dev/us-east-1/dev-cluster
terragrunt run-all destroy
```
