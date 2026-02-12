#!/bin/bash
# Automated Destruction Script for Chaos Platform
# Handles cleanup order to prevent dependency issues (e.g. lingering ALBs blocking VPC deletion)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}$1${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "${RED}⚠️  WARNING: THIS WILL DESTROY ALL INFRASTRUCTURE ⚠️${NC}"
echo -e "${RED}Are you sure you want to proceed? [y/N]${NC}"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Aborting."
    exit 1
fi

# Step 1: Cleanup Kubernetes Resources (Load Balancers)
print_step "Step 1: Cleaning up Kubernetes Resources"
if command -v kubectl &> /dev/null; then
    echo "Deleting ArgoCD Applications..."
    kubectl delete -f argocd-apps/dev-cluster-apps.yaml --ignore-not-found=true
    
    echo "Waiting for Load Balancers to be deleted (30s)..."
    sleep 30
else
    echo "kubectl not found, skipping K8s cleanup (proceeding with caution)"
fi

# Step 2: Destroy Infrastructure
print_step "Step 2: Destroying Terraform Infrastructure"
cd "$(dirname "$0")/infrastructure-live/dev/us-east-1/dev-cluster"

echo "Running: terragrunt run-all destroy"
terragrunt run-all destroy --terragrunt-non-interactive

print_step "🎉 Destruction Complete"
echo -e "${GREEN}All resources have been destroyed.${NC}"
