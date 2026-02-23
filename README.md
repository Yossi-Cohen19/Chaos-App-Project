# 🌪️ Chaos Engineering & Resilience Platform

> A production-grade cloud-native platform for simulating infrastructure failures and validating system resilience — fully automated from code to cloud.

---

## 📌 What Is This Project?

This platform is a **full-stack DevOps showcase** that brings together the industry's leading tools into a single, cohesive system. It demonstrates the complete journey from a developer's `git push` to a live, monitored, highly-available application running in a multi-environment Kubernetes cluster on AWS.

The application itself is a **Chaos Engineering dashboard** — a web interface for triggering controlled failures (CPU stress, pod termination) against a live Kubernetes cluster, then observing how the system recovers. Think of it as a "stress test control panel" for cloud infrastructure.

---

## ✨ Key Highlights

| Category | Implementation |
|---|---|
| **Cloud Provider** | AWS (EKS, RDS, ECR, Route53, ACM, Secrets Manager) |
| **Container Orchestration** | Kubernetes (AWS EKS 1.29) |
| **Infrastructure as Code** | Terraform + Terragrunt (DRY, multi-env) |
| **GitOps / CD** | ArgoCD — App of Apps pattern |
| **CI Pipeline** | GitHub Actions (build → ECR push → GitOps commit) |
| **Application** | Next.js 14 (React 19) |
| **Database** | PostgreSQL 16 on AWS RDS |
| **Observability** | Prometheus + Grafana (kube-prometheus-stack) |
| **Secret Management** | AWS Secrets Manager + External Secrets Operator |
| **DNS & TLS** | Route53 + ACM (SSL terminated at NLB) |
| **Environments** | Dev · Staging · Production |
.
---

## 🏗️ Architecture Overview

```
Developer → git push → GitHub Actions (CI)
                          │
                          ├─ Build Docker image
                          ├─ Push to Amazon ECR
                          └─ Commit image tag to Git (GitOps)
                                    │
                                    ▼
                              ArgoCD (CD) detects Git change
                                    │
                          ┌─────────┴──────────┐
                          │                    │
                        Dev EKS           Prod EKS
                        Cluster           Cluster
                          │                    │
                    ┌─────┴──────┐       ┌─────┴──────┐
                    │  chaos-app │       │  chaos-app │
                    │  (1 pod)   │       │  (3 pods)  │
                    └─────┬──────┘       └─────┬──────┘
                          │                    │
                    RDS Postgres          RDS Postgres
                    (single-AZ)          (Multi-AZ HA)
```

**Infrastructure is fully managed by Terragrunt** with a DRY `_env/` pattern — each environment folder simply inherits the base config and overrides only what's different (cluster name, instance sizes, HA settings, etc.).

---

## 📁 Repository Structure

```
Chaos-App-Project/
│
├── chaos-app/                    # 🖥️  Next.js Application
│   ├── app/api/                  #    REST API endpoints (chaos, metrics, health)
│   ├── components/               #    React UI (dashboard, scaling panel)
│   └── Dockerfile                #    Multi-stage production build
│
├── charts/                       # ⎈  Helm Charts
│   └── chaos-generic/            #    Generic chart — deployed to every environment
│       ├── values.yaml           #    Base configuration
│       ├── values-dev.yaml       #    Dev overrides
│       ├── values-staging.yaml   #    Staging overrides
│       └── values-prod.yaml      #    Production overrides (HA, PDB, monitoring)
│
├── argocd-apps/                  # 🔄  GitOps Manifests (ArgoCD)
│   ├── clusters/                 #    App-of-Apps bootstrap (dev.yaml, prod.yaml)
│   └── apps/                     #    Per-environment app definitions
│       ├── infrastructure/       #    Ingress-nginx, Prometheus
│       └── workloads/            #    chaos-app per environment
│
├── infrastructure-live/          # ☁️  Infrastructure as Code (Terragrunt)
│   ├── _env/                     #    Shared base configs (DRY)
│   │   ├── eks.hcl               #    EKS cluster definition
│   │   ├── rds.hcl               #    RDS PostgreSQL config
│   │   ├── vpc.hcl               #    VPC / networking
│   │   └── addons-integrations.hcl # ArgoCD, External Secrets, External DNS
│   ├── dev/us-east-1/dev-cluster/    #  Dev environment
│   └── prod/us-east-1/prod-cluster/  #  Production environment
│
├── .github/workflows/            # 🚀  CI/CD Pipeline
│   └── ci-cd.yaml                #    Build, push, GitOps tag update (dev & prod)
│
├── deploy.sh                     # 🎯  One-command full deployment script
└── destroy.sh                    # 🗑️  One-command full teardown script
```

---

## 🔄 CI/CD Flow (End-to-End)

```
┌─────────────────────────────────────────────────────────┐
│                     GitHub Actions                       │
│                                                         │
│  git push develop ──► Build image                       │
│                        Push to ECR (chaos-app-dev)      │
│                        Commit tag → values.yaml         │
│                                  ▼                      │
│  git push main ────► Build image                        │
│                        Push to ECR (chaos-app-prod)     │
│                        Commit tag → values-prod.yaml    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ (ArgoCD polls Git every 3 min)
                    ArgoCD detects new tag
                          │
                    Helm upgrade deployed
                    to the right namespace
```

Every image is tagged with the git commit SHA (`sha-abc123...`) for full traceability. The `latest` tag is also pushed for convenience.

---

## 🛡️ Production Environment — Best Practices

The Production environment is configured with enterprise-grade settings:

| Feature | Config |
|---|---|
| **High Availability** | 3 replicas + HPA (auto-scale to 5) |
| **Database HA** | RDS Multi-AZ enabled |
| **Data Protection** | `skip_final_snapshot = false`, 30-day backup retention |
| **Secret Management** | AWS Secrets Manager → External Secrets Operator → K8s Secret |
| **Traffic Protection** | PodDisruptionBudget (`minAvailable: 2`) |
| **Observability** | Prometheus ServiceMonitor enabled |
| **DNS + TLS** | Route53 wildcard + ACM cert at NLB |
| **Image Pinning** | No `latest` — CI/CD sets exact SHA tag via GitOps commit |

---

## 🛠️ Quick Start

### Prerequisites
See [USER_REQUIREMENTS.md](USER_REQUIREMENTS.md) for tool installation instructions.

### One-Command Deploy
```bash
# Deploy the Dev environment
chmod +x deploy.sh
./deploy.sh --env dev

# Deploy Production
./deploy.sh --env prod
```

The script auto-detects your AWS account, provisions all infrastructure via Terragrunt, configures kubectl, and bootstraps ArgoCD.

### Access the Platform

```bash
# Get the Chaos App URL
kubectl get ingress -n dev

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Then: https://localhost:8080
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

### Tear Down
```bash
./destroy.sh --env dev
```

---

## 🧰 Technology Stack

| Layer | Technology |
|---|---|
| **Frontend / App** | Next.js 14, React 19, TypeScript |
| **Containerization** | Docker (multi-stage build) |
| **Registry** | Amazon ECR |
| **Orchestration** | Kubernetes 1.29 on AWS EKS |
| **IaC** | Terraform + Terragrunt |
| **GitOps** | ArgoCD (App of Apps pattern) |
| **CI/CD** | GitHub Actions + OIDC (no static keys) |
| **Database** | PostgreSQL 16 on AWS RDS |
| **Secrets** | AWS Secrets Manager + External Secrets Operator |
| **DNS** | AWS Route53 + External-DNS (auto record creation) |
| **TLS** | AWS ACM (SSL terminated at Network Load Balancer) |
| **Monitoring** | Prometheus + Grafana (kube-prometheus-stack) |
| **Ingress** | ingress-nginx |
| **Autoscaling** | Kubernetes HPA |
| **Node Cost Saving** | EC2 Spot Instances |

---

## 👤 Author

**Yossi Cohen** — DevOps / Cloud Engineer

