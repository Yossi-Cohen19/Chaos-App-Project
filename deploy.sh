#!/bin/bash
# Simplified Deployment Script for Chaos Platform
# This script now uses "terragrunt run-all" for one-command deployment

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Chaos Platform - Automated Deployment                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print step header
print_step() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Prerequisites check
print_step "Step 0: Checking Prerequisites"
command -v terragrunt >/dev/null 2>&1 || { echo "Error: terragrunt not installed"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not installed"; exit 1; }
echo -e "${GREEN}✓ All prerequisites installed${NC}"

# Auto-detect configuration
print_step "Step 0.1: Auto-detecting Configuration"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
GITHUB_REPO=$(git config --get remote.origin.url | sed 's/https:\/\/github.com\///' | sed 's/.git$//')

echo "Detected Account ID: ${GREEN}${AWS_ACCOUNT_ID}${NC}"
echo "Detected Region:     ${GREEN}${AWS_REGION}${NC}"
echo "Detected GitHub Repo: ${GREEN}${GITHUB_REPO}${NC}"

# Update Helm Values (for generic usage)
echo "Updating Helm values.yaml with current Account ID..."
# Use regex to replace the repository line regardless of what's currently there
sed -i "s|repository: .*|repository: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/chaos-platform-app-dev|g" charts/chaos-generic/values.yaml

# Update ArgoCD Apps (for generic usage)
echo "Updating ArgoCD apps with current GitHub Repo..."
# Use regex to replace the repoURL line regardless of what's currently there
sed -i "s|repoURL: .*|repoURL: ${GITHUB_REPO}.git|g" argocd-apps/dev-cluster-apps.yaml

# Export for Terragrunt
export GITHUB_REPO="${GITHUB_REPO}"

# Deploy all infrastructure with one command
print_step "Step 1: Initializing Infrastructure"
cd "$(dirname "$0")/infrastructure-live/dev/us-east-1/dev-cluster"
echo "Running: terragrunt run-all init"
terragrunt run-all init
echo -e "${GREEN}✓ Infrastructure initialized${NC}"

print_step "Step 2: Deploying All Infrastructure"
echo "Running: terragrunt run-all apply --terragrunt-non-interactive"
terragrunt run-all apply --terragrunt-non-interactive
echo -e "${GREEN}✓ All infrastructure deployed${NC}"

# Configure kubectl to access the EKS cluster
print_step "Step 3: Configuring kubectl for EKS"
cd ../../../../  # Back to repo root
aws eks update-kubeconfig --name chaos-dev-cluster --region us-east-1
echo -e "${GREEN}✓ kubectl configured${NC}"

# Wait for External Secrets to be ready
print_step "Step 4: Waiting for External Secrets Operator"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s && \
  echo -e "${GREEN}✓ External Secrets Operator ready${NC}" || \
  echo -e "⚠ External Secrets might not be ready yet"

# Deploy ArgoCD Applications
print_step "Step 5: Deploying ArgoCD Applications"
kubectl apply -f argocd-apps/dev-cluster-apps.yaml
echo -e "${GREEN}✓ ArgoCD Applications deployed${NC}"

# Summary
print_step "🎉 Deployment Complete!"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Push your code to trigger CI/CD:"
echo "   ${BLUE}git add . && git commit -m 'deploy' && git push origin develop${NC}"
echo ""
echo "2. Access ArgoCD UI:"
echo "   ${BLUE}kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
echo "   ${BLUE}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo "   Open: ${BLUE}https://localhost:8080${NC}"
echo ""
echo "3. Check deployment:"
echo "   ${BLUE}kubectl get pods -n dev${NC}"
echo "   ${BLUE}kubectl get ingress -n dev${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
