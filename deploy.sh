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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Update Helm Values with ECR repo and build info
echo "Updating Helm values.yaml with current Account ID and Build Info..."
COMMIT_SHA=$(git rev-parse --short HEAD)
sed -i "s|repository: .*|repository: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}|g" charts/chaos-generic/values.yaml
sed -i "s|nextPublicCommitSha: .*|nextPublicCommitSha: \"${COMMIT_SHA}\"|g" charts/chaos-generic/values.yaml

if [[ "$ENV" == "prod" ]]; then
  sed -i "s|nextPublicEnvironment: .*|nextPublicEnvironment: \"AWS EKS (prod)\"|g" charts/chaos-generic/values.yaml
else
  sed -i "s|nextPublicEnvironment: .*|nextPublicEnvironment: \"AWS EKS (dev)\"|g" charts/chaos-generic/values.yaml
fi

# Update ArgoCD Apps with GitHub repo
echo "Updating ArgoCD apps with current GitHub Repo..."
find argocd-apps -name "*.yaml" -type f -exec sed -i "s|repoURL: https://github.com/.*|repoURL: https://github.com/${GITHUB_REPO}.git|g" {} \;

# Export for Terragrunt
export GITHUB_REPO="${GITHUB_REPO}"

# Deploy all infrastructure with one command
print_step "Step 1: Initializing Infrastructure (${ENV})"
cd "${SCRIPT_DIR}/infrastructure-live/${CLUSTER_DIR}"
echo "Running: terragrunt run-all init -upgrade"
terragrunt run-all init -upgrade
echo -e "${GREEN}✓ Infrastructure initialized${NC}"

print_step "Step 2: Deploying All Infrastructure (${ENV})"
echo "Running: terragrunt run-all apply --terragrunt-non-interactive"
terragrunt run-all apply --terragrunt-non-interactive
echo -e "${GREEN}✓ All infrastructure deployed${NC}"

# Configure kubectl to access the EKS cluster
print_step "Step 3: Configuring kubectl for EKS"
cd "${SCRIPT_DIR}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
echo -e "${GREEN}✓ kubectl configured for ${CLUSTER_NAME}${NC}"

# Wait for External Secrets to be ready
print_step "Step 4: Waiting for External Secrets Operator"
echo "Waiting for pods to be scheduled..."
sleep 30
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s && \
  echo -e "${GREEN}✓ External Secrets Operator ready${NC}" || \
  echo -e "${YELLOW}⚠ External Secrets might not be ready yet${NC}"

# Patch ALB webhook to allow non-ALB ingress classes (nginx)
# This is needed because the ALB controller's validating webhook blocks all ingress classes by default
print_step "Step 5: Configuring ALB Controller Webhook"
echo "Scoping ALB webhook to only validate ALB-managed resources..."
kubectl get ValidatingWebhookConfiguration aws-load-balancer-webhook -o json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
changed = False
for wh in data.get('webhooks', []):
    if wh['name'] == 'vingress.elbv2.k8s.aws':
        wh['objectSelector'] = {
            'matchExpressions': [{
                'key': 'elbv2.k8s.aws/cluster',
                'operator': 'Exists'
            }]
        }
        changed = True
if changed:
    json.dump(data, sys.stdout)
" | kubectl apply -f - 2>/dev/null && \
  echo -e "${GREEN}✓ ALB webhook scoped to ALB-only resources${NC}" || \
  echo -e "${YELLOW}⚠ ALB webhook patch skipped (not found or already configured)${NC}"

# Deploy ArgoCD Applications (App of Apps pattern)
print_step "Step 6: Deploying ArgoCD Root Application"
echo "Deploying root App of Apps for ${ENV} cluster..."
kubectl apply -f "argocd-apps/clusters/${ENV}.yaml"
echo -e "${GREEN}✓ Root application deployed - child apps will auto-sync${NC}"

# Wait for ArgoCD to sync
print_step "Step 7: Waiting for ArgoCD Sync"
echo "ArgoCD will now sync all applications from Git. This may take 2-5 minutes..."
echo "Waiting 60 seconds for initial sync..."
sleep 60

echo ""
echo "ArgoCD Applications status:"
kubectl get applications -n argocd 2>/dev/null || echo -e "${YELLOW}⚠ ArgoCD not fully ready yet${NC}"

echo ""
echo "Checking ingress-nginx LoadBalancer..."
INGRESS_LB=$(kubectl get svc -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
echo -e "LoadBalancer DNS: ${BLUE}${INGRESS_LB}${NC}"

# Summary
print_step "🎉 Deployment Complete! (${ENV})"
echo ""
echo -e "${GREEN}What was deployed:${NC}"
echo "  • Infrastructure via Terragrunt (VPC, EKS, RDS, ECR, Secrets, IRSA)"
echo "  • ArgoCD manages: ingress-nginx, chaos-app(s), kube-prometheus-stack"
echo ""
echo -e "${GREEN}Access:${NC}"
echo "  ArgoCD UI:  ${BLUE}kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443${NC}"
echo "  Password:   ${BLUE}kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
echo "  App URL:    ${BLUE}http://${INGRESS_LB}${NC}"
echo ""
echo -e "${GREEN}Verify:${NC}"
echo "  ${BLUE}kubectl get applications -n argocd${NC}"
echo "  ${BLUE}kubectl get pods -A${NC}"
echo "  ${BLUE}kubectl get ingress -A${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
