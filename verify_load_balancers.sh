#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Chaos Platform Load Balancer Verification ===${NC}"

# Function to check a cluster
check_cluster() {
    local env=$1
    local cluster_name=$2
    local region="us-east-1"

    echo -e "\n${GREEN}Checking environment: ${env} (Cluster: ${cluster_name})${NC}"
    
    # Update kubeconfig
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --name "${cluster_name}" --region "${region}" > /dev/null
    
    # Check Ingress Nginx Service
    echo "Checking ingress-nginx Service..."
    local svc_type=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.type}' 2>/dev/null || echo "NotFound")
    
    if [[ "$svc_type" == "NotFound" ]]; then
        echo -e "${RED}❌ ingress-nginx-controller Service NOT FOUND${NC}"
    else
        echo "Service Type: $svc_type"
        local lb_hostname=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending")
        local lb_annotations=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.metadata.annotations}' 2>/dev/null)
        
        echo "LoadBalancer Hostname: $lb_hostname"
        echo "Annotations: $lb_annotations"
        
        if [[ "$lb_hostname" == "Pending" ]]; then
             echo -e "${RED}⚠️ LoadBalancer is Pending. Checking events...${NC}"
             kubectl describe svc -n ingress-nginx ingress-nginx-controller | grep -A 5 "Events"
        else
             echo -e "${GREEN}✅ LoadBalancer DNS assigned${NC}"
        fi
    fi
    
    # Check AWS Load Balancer Controller
    echo "Checking AWS Load Balancer Controller..."
    local pods=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l)
    if [[ "$pods" -gt 0 ]]; then
        echo -e "${GREEN}✅ AWS Load Balancer Controller is running ($pods pods)${NC}"
        # Check logs for errors
        echo "Checking controller logs for errors..."
        kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20 | grep -i "error" || echo "No recent errors found in logs."
    else
        echo -e "${RED}❌ AWS Load Balancer Controller pods NOT FOUND${NC}"
    fi
    
    # List all Ingresses
    echo "Listing Ingresses..."
    kubectl get ingress -A
}

# Check Dev
check_cluster "dev" "chaos-dev-cluster"

# Check Prod
check_cluster "prod" "chaos-prod-cluster"
