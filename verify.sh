#!/bin/bash
# Quick Infrastructure Health Check

echo "=== Pod Status ==="
kubectl get pods -A | grep -E "ingress-nginx|external-dns|staging|dev|argocd"

echo -e "\n=== LoadBalancer Status ==="
kubectl get svc -n ingress-nginx ingress-nginx-controller

echo -e "\n=== Ingress Status ==="
kubectl get ingress -A

echo -e "\n=== DNS Records ==="
echo "Checking stage.yossi.site..."
dig stage.yossi.site +short
echo "Checking dev.yossi.site..."
dig dev.yossi.site +short

echo -e "\n=== HTTPS Test ==="
curl -I https://stage.yossi.site 2>&1 | head -5

echo -e "\n=== HTTP Redirect Test ==="
echo "Testing redirect from HTTP to HTTPS..."
curl -I http://stage.yossi.site 2>&1 | grep -E "HTTP|Location"

echo -e "\n=== ArgoCD Applications ==="
kubectl get applications -n argocd
