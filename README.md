# Chaos Engineering & Resilience Platform

## Overview
This repository contains a **Chaos Engineering Platform** built with **Next.js** and deployed on **AWS EKS** (Elastic Kubernetes Service) using **Terragrunt**.

The platform is designed to simulate infrastructure failures and stress tests to validate system resilience.

## 🏗 Repository Structure

```
├── chaos-app/                     # The application source code
│   ├── app/api/               # Chaos Experiments API (kill, stress, health)
│   └── Dockerfile             # Multi-stage Docker build (Node.js 20 Alpine)
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
└── k8s-manifests/                 # (Currently Empty) Kubernetes manifests for GitOps
```

## 🚀 Key Components

### 1. Application (`chaos-app`)
- **Framework**: Next.js 14 (React 19).
- **Chaos Features**:
    - **`/api/kill`**: Triggers a hard crash (`process.exit(1)`).
    - **`/api/stress`**: CPU stress test using worker threads (capped at 10s, safe mode).
- **Build**: Uses a multi-stage `Dockerfile` producing a standalone output for efficiency.

### 2. Infrastructure (`infrastructure-live`)
Managed via **Terragrunt** to keep configurations DRY.
- **EKS Cluster**:
    - Version: `1.29`
    - Nodes: Spot Instances (`t3.medium`, `t3a.medium`), Autoscaling (1-3 nodes).
- **Database**:
    - Engine: Postgres 16 (`db.t4g.micro`).
    - Auth: Managed via AWS Secrets Manager.
- **Addons**:
    - **ArgoCD**: For GitOps deployment.
    - **External Secrets**: For secret management.
    - **Metrics Server**: For HPA/monitoring.

## 🚧 Status & Future Implementation
- **Missing Deployment Manifests**: The `k8s-manifests` directory and `infrastructure-live/.../app-dev` are currently empty.
- **Next Steps**:
    1.  Create Helm chart or Kustomize manifests for the Next.js app.
    2.  Configure ArgoCD Application in `app-dev` to point to the manifests.
    3.  Build and push the Docker image to ECR (ECR creation is present in structure but needs verification).

## 🛠 Usage

### 📋 Prerequisites
Please refer to [USER_REQUIREMENTS.md](USER_REQUIREMENTS.md) for detailed setup instructions.
- AWS CLI configured
- kubectl
- Terragrunt
- Docker

### 🚀 Quick Start (Recommended)
This repository includes a fully automated deployment script for any AWS account.

```bash
chmod +x deploy.sh
./deploy.sh
```

**What this does:**
1.  **Auto-detects** your AWS Account and Region.
2.  **Initializes & Deploys** all infrastructure via Terragrunt.
3.  **Configures** `kubectl` for the new EKS cluster.
4.  **Deploys** ArgoCD applications to `dev` and `staging` environments.

### 🔧 Manual Deployment
If you prefer manual steps:

1.  **Deploy Infrastructure**:
    ```bash
    cd infrastructure-live/dev/us-east-1/dev-cluster
    terragrunt run-all init
    terragrunt run-all apply
    ```

2.  **Configure Access**:
    ```bash
    aws eks update-kubeconfig --name chaos-dev-cluster --region us-east-1
    ```

3.  **Deploy Application**:
    ```bash
    kubectl apply -f argocd-apps/dev-cluster-apps.yaml
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
