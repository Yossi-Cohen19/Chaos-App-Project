#!/bin/bash
# Deployment Script for Chaos Platform
# Supports both dev-cluster and prod-cluster deployments
# Usage: ./deploy.sh [--env dev|prod]

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default environment
ENV="${ENV:-dev}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENV="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./deploy.sh [--env dev|prod]"
      exit 1
      ;;
  esac
done

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo -e "${RED}Invalid environment: $ENV. Must be 'dev' or 'prod'${NC}"
  exit 1
fi

# Set cluster-specific variables
if [[ "$ENV" == "dev" ]]; then
  CLUSTER_NAME="chaos-dev-cluster"
  CLUSTER_DIR="dev/us-east-1/dev-cluster"
  APPS_FILE="argocd-apps/dev-cluster-apps.yaml"
  ECR_REPO="chaos-platform-app-dev"
elif [[ "$ENV" == "prod" ]]; then
  CLUSTER_NAME="chaos-prod-cluster"
  CLUSTER_DIR="prod/us-east-1/prod-cluster"
  APPS_FILE="argocd-apps/prod-cluster-apps.yaml"
  ECR_REPO="chaos-platform-app-prod"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Chaos Platform - Automated Deployment (${ENV})            ║${NC}"
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
command -v helm >/dev/null 2>&1 || { echo "Error: helm not installed"; exit 1; }
echo -e "${GREEN}✓ All prerequisites installed${NC}"

# Auto-detect configuration
print_step "Step 0.1: Auto-detecting Configuration"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
GITHUB_REPO=$(git config --get remote.origin.url | sed 's/https:\/\/github.com\///' | sed 's/.git$//')

echo "Detected Account ID:  ${GREEN}${AWS_ACCOUNT_ID}${NC}"
echo "Detected Region:      ${GREEN}${AWS_REGION}${NC}"
echo "Detected GitHub Repo: ${GREEN}${GITHUB_REPO}${NC}"
echo "Target Environment:   ${GREEN}${ENV}${NC}"
echo "Target Cluster:       ${GREEN}${CLUSTER_NAME}${NC}"

# Update Helm Values
echo "Updating Helm values.yaml with current Account ID..."
sed -i "s|repository: .*|repository: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}|g" charts/chaos-generic/values.yaml

# Update ArgoCD Apps
echo "Updating ArgoCD apps with current GitHub Repo..."
sed -i "s|repoURL: .*|repoURL: https://github.com/${GITHUB_REPO}.git|g" "${APPS_FILE}"

# Also update dev-cluster-apps if deploying dev (contains both dev + staging)
if [[ "$ENV" == "dev" ]]; then
  sed -i "s|repoURL: .*|repoURL: https://github.com/${GITHUB_REPO}.git|g" argocd-apps/dev-cluster-apps.yaml
fi

# Export for Terragrunt
export GITHUB_REPO="${GITHUB_REPO}"

# Deploy all infrastructure with one command
print_step "Step 1: Initializing Infrastructure (${ENV})"
cd "$(dirname "$0")/infrastructure-live/${CLUSTER_DIR}"
echo "Running: terragrunt run-all init"
terragrunt run-all init
echo -e "${GREEN}✓ Infrastructure initialized${NC}"

print_step "Step 2: Deploying All Infrastructure (${ENV})"
echo "Running: terragrunt run-all apply --terragrunt-non-interactive"
terragrunt run-all apply --terragrunt-non-interactive
echo -e "${GREEN}✓ All infrastructure deployed${NC}"

# Configure kubectl to access the EKS cluster
print_step "Step 3: Configuring kubectl for EKS"
cd "$(dirname "$0")"
# Navigate back to repo root
cd - > /dev/null
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
echo -e "${GREEN}✓ kubectl configured for ${CLUSTER_NAME}${NC}"

# Wait for External Secrets to be ready
print_step "Step 4: Waiting for External Secrets Operator"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s && \
  echo -e "${GREEN}✓ External Secrets Operator ready${NC}" || \
  echo -e "${YELLOW}⚠ External Secrets might not be ready yet${NC}"

# Install ingress-nginx controller
print_step "Step 5: Installing ingress-nginx Controller"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

if helm status ingress-nginx -n ingress-nginx >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ ingress-nginx already installed, upgrading...${NC}"
  helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
    -n ingress-nginx \
    --set controller.service.type=LoadBalancer \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
else
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    -n ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
fi
echo -e "${GREEN}✓ ingress-nginx controller deployed${NC}"

# Deploy ArgoCD Applications
print_step "Step 6: Deploying ArgoCD Applications"
kubectl apply -f "${APPS_FILE}"

# Deploy observability stack (both environments)
echo "Deploying observability stack..."
kubectl apply -f argocd-apps/observability.yaml
echo -e "${GREEN}✓ ArgoCD Applications deployed${NC}"

# Post-deployment verification
print_step "Step 7: Post-deployment Verification"

echo "Waiting for pods to be ready..."
sleep 15

if [[ "$ENV" == "dev" ]]; then
  echo "Checking dev namespace..."
  kubectl get pods -n dev 2>/dev/null || echo -e "${YELLOW}⚠ No pods in dev yet (ArgoCD will sync shortly)${NC}"
  echo ""
  echo "Checking staging namespace..."
  kubectl get pods -n staging 2>/dev/null || echo -e "${YELLOW}⚠ No pods in staging yet (ArgoCD will sync shortly)${NC}"
elif [[ "$ENV" == "prod" ]]; then
  echo "Checking prod namespace..."
  kubectl get pods -n prod 2>/dev/null || echo -e "${YELLOW}⚠ No pods in prod yet (ArgoCD will sync shortly)${NC}"
fi

echo ""
echo "ArgoCD Applications status:"
kubectl get applications -n argocd 2>/dev/null || echo -e "${YELLOW}⚠ ArgoCD not ready yet${NC}"

echo ""
echo "Checking ingress-nginx LoadBalancer..."
INGRESS_LB=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
echo -e "LoadBalancer DNS: ${BLUE}${INGRESS_LB}${NC}"

# Summary
print_step "🎉 Deployment Complete! (${ENV})"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Push your code to trigger CI/CD:"
echo "   ${BLUE}git add . && git commit -m 'deploy' && git push origin develop${NC}"
echo ""
echo "2. Access ArgoCD UI:"
echo "   ${BLUE}kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
echo "   ${BLUE}kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443${NC}"
echo "   Open: ${BLUE}https://localhost:8080${NC}"
echo ""
echo "3. Access your app via LoadBalancer:"
echo "   ${BLUE}http://${INGRESS_LB}${NC}"
echo ""
echo "4. Check deployment:"
echo "   ${BLUE}kubectl get pods -A${NC}"
echo "   ${BLUE}kubectl get ingress -A${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
