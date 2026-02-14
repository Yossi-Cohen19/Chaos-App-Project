#!/bin/bash
# Aggressive EKS Cleanup Script
# Usage: ./cleanup_eks.sh <cluster-name> <region>

CLUSTER_NAME=$1
REGION=$2

if [[ -z "$CLUSTER_NAME" || -z "$REGION" ]]; then
  echo "Usage: $0 <cluster-name> <region>"
  exit 1
fi

echo "Checking cluster: $CLUSTER_NAME in $REGION"
STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.status" --output text 2>/dev/null)

if [[ -z "$STATUS" ]]; then
  echo "Cluster not found."
  exit 0
fi

echo "Cluster status: $STATUS"

# Delete NodeGroups first
echo "Deleting NodeGroups..."
NGS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --query "nodegroups" --output text)

for ng in $NGS; do
  echo "Deleting NodeGroup: $ng"
  aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$REGION"
  # Don't wait here, trigger all deletions
done

# Wait for NodeGroups to be gone
if [[ -n "$NGS" ]]; then
  echo "Waiting for NodeGroups to delete..."
  aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$REGION" 2>/dev/null
fi

# Delete Cluster
echo "Deleting Cluster..."
aws eks delete-cluster --name "$CLUSTER_NAME" --region "$REGION"

# Wait for Cluster to be gone
echo "Waiting for Cluster deletion..."
aws eks wait cluster-deleted --name "$CLUSTER_NAME" --region "$REGION"

echo "EKS Cleanup Complete."
