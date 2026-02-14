#!/bin/bash
# Manual Cleanup Script for Dangling Resources
# Usage: ./cleanup_dangling_resources.sh dev|prod

ENV=$1

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <env>"
  echo "Example: $0 dev"
  exit 1
fi

if [[ "$ENV" == "dev" ]]; then
  VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*chaos-dev*" --query "Vpcs[0].VpcId" --output text)
  CLUSTER_NAME="chaos-dev-cluster"
elif [[ "$ENV" == "prod" ]]; then
  VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*chaos-prod*" --query "Vpcs[0].VpcId" --output text)
  CLUSTER_NAME="chaos-prod-cluster"
else
  echo "Invalid environment. Must be dev or prod."
  exit 1
fi

echo "Environment: $ENV"
echo "VPC ID: $VPC_ID"

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "VPC not found. Skipping network cleanup."
else
  echo "Checking for dangling Load Balancers..."
  LBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
  
  for lb in $LBS; do
    echo "Deleting Load Balancer: $lb"
    aws elbv2 delete-load-balancer --load-balancer-arn "$lb"
    # Wait for deletion
    echo "Waiting for LB deletion..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "$lb" 2>/dev/null || sleep 15
  done

  echo "Checking for dangling Target Groups..."
  # Target Groups don't have a direct VPC ID filter in describe-target-groups (it returns all), 
  # so we filter by VpcId in the query.
  TGS=$(aws elbv2 describe-target-groups --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text)
  
  for tg in $TGS; do
    echo "Deleting Target Group: $tg"
    aws elbv2 delete-target-group --target-group-arn "$tg"
  done

  echo "Checking for dangling ENIs..."
  ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)
  if [[ -n "$ENIS" ]]; then
     echo "Found ENIs: $ENIS"
     echo "Attempting to detach and delete..."
     for eni in $ENIS; do
        # Try to detach first if attached
        ATTACH_ID=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)
        if [[ "$ATTACH_ID" != "None" ]]; then
           aws ec2 detach-network-interface --attachment-id "$ATTACH_ID" || true
           sleep 5
        fi
        aws ec2 delete-network-interface --network-interface-id "$eni" || echo "Failed to delete ENI $eni (might be managed by AWS service)"
     done
  else
     echo "No dangling ENIs found."
  fi
fi

# For prod, if EKS cluster still exists but terraform state is messed up, we might need manual intervention.
# But usually cleaning up the underlying resources allows terraform destroy to finish (or fail cleanly so it can be re-run).

echo "Cleanup complete. Try running 'destroy.sh --env $ENV' or 'terragrunt run-all destroy' again."
