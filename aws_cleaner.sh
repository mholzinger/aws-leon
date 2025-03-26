#!/bin/bash
# AWS Resource Cleanup Script
# Usage: ./aws_cleaner.sh [region]

set -e  # Exit on error

# Use specified region or default to us-east-1
REGION=${1:-us-east-1}
echo "Running cleanup in region: $REGION"

# Set AWS region for this session
export AWS_DEFAULT_REGION=$REGION
export AWS_PAGER=""  # Disable AWS CLI pager

# Color output for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting AWS resource cleanup...${NC}"

# 1. Find and delete EKS clusters
echo -e "\n${YELLOW}Checking for EKS clusters...${NC}"
CLUSTERS=$(aws eks list-clusters --query 'clusters[*]' --output text)

if [ -n "$CLUSTERS" ]; then
  echo -e "${YELLOW}Found clusters: $CLUSTERS${NC}"
  for CLUSTER in $CLUSTERS; do
    echo -e "Deleting cluster: $CLUSTER"
    aws eks delete-cluster --name $CLUSTER
    echo -e "Waiting for cluster deletion to complete..."
    aws eks wait cluster-deleted --name $CLUSTER
  done
else
  echo -e "${GREEN}No EKS clusters found.${NC}"
fi

# 2. Find and delete Load Balancers
echo -e "\n${YELLOW}Checking for Classic Load Balancers...${NC}"
ELBS=$(aws elb describe-load-balancers --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

if [ -n "$ELBS" ]; then
  echo -e "${YELLOW}Found Classic Load Balancers: $ELBS${NC}"
  for ELB in $ELBS; do
    echo -e "Deleting Classic Load Balancer: $ELB"
    aws elb delete-load-balancer --load-balancer-name $ELB
  done
else
  echo -e "${GREEN}No Classic Load Balancers found.${NC}"
fi

echo -e "\n${YELLOW}Checking for Application/Network Load Balancers...${NC}"
ELBSV2=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text)

if [ -n "$ELBSV2" ]; then
  echo -e "${YELLOW}Found ALB/NLB Load Balancers: $ELBSV2${NC}"
  for ELBV2 in $ELBSV2; do
    echo -e "Deleting ALB/NLB: $ELBV2"
    aws elbv2 delete-load-balancer --load-balancer-arn $ELBV2
  done
else
  echo -e "${GREEN}No ALB/NLB Load Balancers found.${NC}"
fi

# 3. Find and delete NAT Gateways (async to speed up execution)
echo -e "\n${YELLOW}Checking for NAT Gateways...${NC}"
NATGATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output text)

if [ -n "$NATGATEWAYS" ]; then
  echo -e "${YELLOW}Found NAT Gateways: $NATGATEWAYS${NC}"
  for NATGW in $NATGATEWAYS; do
    echo -e "Deleting NAT Gateway: $NATGW"
    aws ec2 delete-nat-gateway --nat-gateway-id $NATGW
  done
  echo -e "${YELLOW}NAT Gateway deletion initiated. This process can take several minutes.${NC}"
else
  echo -e "${GREEN}No active NAT Gateways found.${NC}"
fi

# 4. Find and release unattached Elastic IPs
echo -e "\n${YELLOW}Checking for unattached Elastic IPs...${NC}"
EIPS=$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text)

if [ -n "$EIPS" ]; then
  echo -e "${YELLOW}Found unattached Elastic IPs: $EIPS${NC}"
  for EIP in $EIPS; do
    echo -e "Releasing Elastic IP: $EIP"
    aws ec2 release-address --allocation-id $EIP
  done
else
  echo -e "${GREEN}No unattached Elastic IPs found.${NC}"
fi

# 5. Delete security groups (with dependency handling)
echo -e "\n${YELLOW}Checking for non-default security groups...${NC}"
SECGROUPS=$(aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)

if [ -n "$SECGROUPS" ]; then
  echo -e "${YELLOW}Found security groups: $SECGROUPS${NC}"
  
  # First, remove all rules from each security group
  for SG in $SECGROUPS; do
    echo -e "Removing rules from security group: $SG"
    
    # Get inbound rules
    INBOUND=$(aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissions' --output json)
    if [ "$INBOUND" != "[]" ] && [ "$INBOUND" != "" ]; then
      echo "Revoking inbound rules"
      aws ec2 revoke-security-group-ingress --group-id $SG --ip-permissions "$INBOUND" || echo "No inbound rules or failed to revoke"
    fi
    
    # Get outbound rules
    OUTBOUND=$(aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissionsEgress' --output json)
    if [ "$OUTBOUND" != "[]" ] && [ "$OUTBOUND" != "" ]; then
      echo "Revoking outbound rules"
      aws ec2 revoke-security-group-egress --group-id $SG --ip-permissions "$OUTBOUND" || echo "No outbound rules or failed to revoke"
    fi
  done
  
  # Now attempt to delete each security group
  for SG in $SECGROUPS; do
    echo -e "Deleting security group: $SG"
    aws ec2 delete-security-group --group-id $SG || echo "Failed to delete $SG - may have dependencies"
  done
else
  echo -e "${GREEN}No non-default security groups found.${NC}"
fi

# 6. Check for CloudWatch Log Groups related to EKS
echo -e "\n${YELLOW}Checking for EKS CloudWatch Log Groups...${NC}"
LOGGROUPS=$(aws logs describe-log-groups --query 'logGroups[?contains(logGroupName, `/aws/eks/`)].logGroupName' --output text)

if [ -n "$LOGGROUPS" ]; then
  echo -e "${YELLOW}Found EKS Log Groups: $LOGGROUPS${NC}"
  for LG in $LOGGROUPS; do
    echo -e "Deleting Log Group: $LG"
    aws logs delete-log-group --log-group-name "$LG"
  done
else
  echo -e "${GREEN}No EKS Log Groups found.${NC}"
fi

# 7. Find and schedule deletion of KMS keys related to EKS/Terraform
echo -e "\n${YELLOW}Checking for EKS/Terraform related KMS keys...${NC}"
KMSKEYS=$(aws kms list-keys --query 'Keys[*].KeyId' --output text)

for KEY in $KMSKEYS; do
  # Check if key has eks-related tags
  TAGS=$(aws kms list-resource-tags --key-id $KEY --query 'Tags[?Value==`eks`]' --output text)
  if [ -n "$TAGS" ]; then
    echo -e "Scheduling deletion for KMS key: $KEY"
    aws kms schedule-key-deletion --key-id $KEY --pending-window-in-days 7 || echo "Key $KEY may already be pending deletion"
  fi
done

# 8. Clean up non-default VPCs and their dependencies
echo -e "\n${YELLOW}Checking for non-default VPCs...${NC}"
VPCS=$(aws ec2 describe-vpcs --filter "Name=isDefault,Values=false" --query 'Vpcs[*].VpcId' --output text)

if [ -n "$VPCS" ]; then
  echo -e "${YELLOW}Found non-default VPCs: $VPCS${NC}"
  for VPC in $VPCS; do
    echo -e "Processing VPC: $VPC"
    
    # Detach and delete Internet Gateways
    IGWs=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC" --query 'InternetGateways[*].InternetGatewayId' --output text)
    for IGW in $IGWs; do
      echo -e "Detaching and deleting Internet Gateway: $IGW"
      aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC
      aws ec2 delete-internet-gateway --internet-gateway-id $IGW
    done
    
    # Delete Subnets
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'Subnets[*].SubnetId' --output text)
    for SUBNET in $SUBNETS; do
      echo -e "Deleting Subnet: $SUBNET"
      aws ec2 delete-subnet --subnet-id $SUBNET
    done
    
    # Delete Route Tables (except main one)
    RTS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    for RT in $RTS; do
      echo -e "Deleting Route Table: $RT"
      aws ec2 delete-route-table --route-table-id $RT
    done
    
    # Delete VPC
    echo -e "Deleting VPC: $VPC"
    aws ec2 delete-vpc --vpc-id $VPC || echo "Failed to delete VPC $VPC - may still have dependencies"
  done
else
  echo -e "${GREEN}No non-default VPCs found.${NC}"
fi

# 9. Delete OIDC Providers related to EKS
echo -e "\n${YELLOW}Checking for EKS OIDC providers...${NC}"
OIDC_PROVIDERS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text)

for OIDC in $OIDC_PROVIDERS; do
  if [[ $OIDC == *"eks"* ]]; then
    echo -e "Deleting EKS OIDC provider: $OIDC"
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $OIDC
  fi
done

echo -e "\n${GREEN}Cleanup completed in region $REGION${NC}"
