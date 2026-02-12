#!/bin/bash
# Automated Destruction Script for Chaos Platform
# Handles cleanup order to prevent dependency issues (e.g. lingering ALBs blocking VPC deletion)
# Usage: ./destroy.sh [--env dev|prod]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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
      echo "Usage: ./destroy.sh [--env dev|prod]"
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
elif [[ "$ENV" == "prod" ]]; then
  CLUSTER_NAME="chaos-prod-cluster"
  CLUSTER_DIR="prod/us-east-1/prod-cluster"
  APPS_FILE="argocd-apps/prod-cluster-apps.yaml"
fi

print_step() {
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}$1${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "${RED}⚠️  WARNING: THIS WILL DESTROY ALL ${ENV^^} INFRASTRUCTURE ⚠️${NC}"
echo -e "${RED}Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${RED}Are you sure you want to proceed? [y/N]${NC}"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Aborting."
    exit 1
fi

# Step 1: Cleanup Kubernetes Resources (Load Balancers, Ingress)
print_step "Step 1: Cleaning up Kubernetes Resources (${ENV})"
if command -v kubectl &> /dev/null; then
    # Check if we can connect to the cluster
    if kubectl cluster-info &>/dev/null; then
        echo "Deleting ArgoCD Applications..."
        kubectl delete -f "${APPS_FILE}" --ignore-not-found=true
        kubectl delete -f argocd-apps/observability.yaml --ignore-not-found=true

        echo "Removing ingress-nginx controller..."
        helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true

        echo "Waiting for Load Balancers to be deleted (45s)..."
        sleep 45
    else
        echo -e "${YELLOW}Cannot connect to cluster, skipping K8s cleanup${NC}"
    fi
else
    echo "kubectl not found, skipping K8s cleanup (proceeding with caution)"
fi

# Step 2: Destroy Infrastructure
print_step "Step 2: Destroying Terraform Infrastructure (${ENV})"
cd "$(dirname "$0")/infrastructure-live/${CLUSTER_DIR}"

echo "Running: terragrunt run-all destroy"
terragrunt run-all destroy --terragrunt-non-interactive

print_step "🎉 Destruction Complete (${ENV})"
echo -e "${GREEN}All ${ENV} resources have been destroyed.${NC}"
