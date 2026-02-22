# 📋 Setup & Prerequisites Guide

This guide covers everything you need to deploy the **Chaos Engineering Platform** from scratch into your own AWS account. Follow the steps in order.

---

## ⏱️ Estimated Setup Time

| Step | Time |
|---|---|
| AWS credentials + tool installation | ~15 minutes |
| Infrastructure provisioning (`deploy.sh`) | ~25–35 minutes |
| ArgoCD app sync + DNS propagation | ~5–10 minutes |
| **Total** | **~45–60 minutes** |

---

## 1. AWS Account & Credentials

You need an active AWS account with programmatic access.

### 1.1 IAM Permissions Required
The deploying user needs permissions for:

| Service | Purpose |
|---|---|
| EC2 / VPC | Networking, subnets, NAT gateway |
| EKS | Kubernetes cluster management |
| RDS | PostgreSQL database |
| ECR | Container image registry |
| IAM | IRSA roles for pods |
| Route53 | DNS record management |
| ACM | TLS certificate provisioning |
| Secrets Manager | Secret storage |
| S3 | Terraform remote state backend |

> **Easiest option**: Attach `AdministratorAccess` to your IAM user for initial setup.

### 1.2 Configure AWS CLI

```bash
aws configure
```

Enter when prompted:
- **AWS Access Key ID** — from your IAM user
- **AWS Secret Access Key** — from your IAM user
- **Default region** — `us-east-1` (recommended)
- **Default output format** — `json`

Verify:
```bash
aws sts get-caller-identity
```

---

## 2. Required Tools

Install these tools before running the deploy script.

| Tool | Min Version | Purpose |
|---|---|---|
| AWS CLI | v2 | AWS authentication |
| Terraform | v1.3+ | Infrastructure provisioning |
| Terragrunt | v0.54+ | DRY IaC orchestration |
| kubectl | v1.29+ | Kubernetes CLI |
| Docker | Latest | Build container images |
| Helm | v3+ | Kubernetes package manager |

### macOS (Homebrew)

```bash
brew install awscli terraform terragrunt kubectl docker helm
```

### Linux (Ubuntu/Debian)

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.54.0/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64 && sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Verify All Tools

```bash
aws --version
terraform --version
terragrunt --version
kubectl version --client
helm version
docker --version
```

---

## 3. GitHub Repository Setup (For CI/CD)

The CI/CD pipeline uses **GitHub OIDC** — no static AWS credentials needed. The deploy script automatically provisions the OIDC trust relationship between GitHub Actions and AWS.

### Steps

1. **Fork this repository** to your own GitHub account
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Chaos-App-Project.git
   cd Chaos-App-Project
   ```
3. **Ensure your git remote is set** (the deploy script reads it):
   ```bash
   git remote -v
   # Should show: origin https://github.com/YOUR_USERNAME/Chaos-App-Project.git
   ```

> **Why OIDC?** GitHub Actions authenticates to AWS via a short-lived token — no IAM access keys stored as GitHub secrets. This is the AWS security best practice.

---

## 4. Terraform State Backend (S3)

The platform uses S3 for remote Terraform state. The `deploy.sh` script creates the bucket automatically, named:

```
chaos-platform-tf-state-<YOUR_AWS_ACCOUNT_ID>
```

No manual setup required.

---

## 5. DNS (Optional — for production domains)

If you want the application accessible at a custom domain (e.g., `prod.yourdomain.com`):

1. Register or transfer a domain to **AWS Route53**
2. Note your **Hosted Zone ID** from the Route53 console
3. Update `infrastructure-live/terragrunt.hcl`:
   ```hcl
   route53_zone_id = "YOUR_ZONE_ID"
   domain_name     = "yourdomain.com"
   ```

DNS records are automatically created by **External-DNS** once the cluster is running.

---

## ✅ Ready to Deploy

Once all prerequisites are met:

```bash
# Deploy Dev environment (~30 minutes)
chmod +x deploy.sh
./deploy.sh --env dev

# Deploy Production environment
./deploy.sh --env prod
```

**What the script does automatically:**
1. Creates the S3 state bucket
2. Provisions VPC, EKS cluster, RDS, ECR, IRSA roles via Terragrunt
3. Installs Helm addons (ArgoCD, ingress-nginx, Prometheus, External Secrets, External-DNS)
4. Configures `kubectl` for the new cluster
5. Bootstraps the ArgoCD App-of-Apps root application

---

## 🧹 Teardown

To completely destroy all cloud resources (avoids ongoing AWS costs):

```bash
./destroy.sh --env dev
./destroy.sh --env prod
```

> ⚠️ **Production warning**: The prod RDS has `skip_final_snapshot = false`. AWS will create a final snapshot before deletion. Delete it manually in the RDS console afterwards if you don't need it.
