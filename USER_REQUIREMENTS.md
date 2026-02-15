# 📋 User Requirements (Prerequisites)

Before running `./deploy.sh`, ensure you have met the following requirements. 

## 1. AWS Account & Credentials

You need an active AWS account and admin credentials configured locally.

### Step 1.1: Create an IAM User (or use existing)
Ensure your IAM user has **AdministratorAccess** (or extensive permissions for VPC, EKS, RDS, IAM, etc.).
Common permissions required:
- `AdministratorAccess` (easiest for setup)
- OR specific policies for: EC2, EKS, IAM, RDS, Route53, S3, DynamoDB (for Terraform state).

### Step 1.2: Configure AWS CLI
Run the following command and enter your Access Key ID and Secret Access Key:

```bash
aws configure
```

- **AWS Access Key ID**: `AKIA...`
- **AWS Secret Access Key**: `...`
- **Default region name**: `us-east-1` (Recommended, or your preferred region)
- **Default output format**: `json`

## 2. Install Required Tools

The deployment script relies on these standard DevOps tools. Make sure they are installed and in your PATH.

### macOS (Homebrew)
```bash
brew install awscli kubectl terraform terragrunt docker
```

### Linux (Ubuntu/Debian)
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.54.0/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Docker (Required for building images)
# Follow official Docker installation guide for your distro
```

### Verify Installation
```bash
aws --version
terraform --version
terragrunt --version
kubectl version --client
docker --version
```

## 3. GitHub Repository (For CI/CD)

The deployment sets up a CI/CD pipeline that connects AWS to your GitHub repository.

1.  **Fork this repository** to your own GitHub account (if you haven't already).
2.  **Clone your fork** locally:
    ```bash
    git clone https://github.com/YOUR_USERNAME/Chaos-App-Project.git
    cd Chaos-App-Project
    ```
3.  **Note**: The automated deployment script (`deploy.sh`) relies on identifying the remote origin URL to configure GitHub OIDC provider in AWS. Ensure your git remote is set correctly.

## 4. Ready to Deploy?

Once these steps are complete, you are ready to run:

```bash
chmod +x deploy.sh
./deploy.sh --env dev
```
