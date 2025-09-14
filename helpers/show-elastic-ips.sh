#!/bin/bash

# Simple AWS Elastic IP Counter
# Shows count and status of all Elastic IPs

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AWS Elastic IP Overview ===${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo ""

# Check AWS CLI configuration
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Get Elastic IPs
eip_data=$(aws ec2 describe-addresses \
    --query 'Addresses[*].[PublicIp,InstanceId,AssociationId]' \
    --output text)

total_count=0
attached_count=0
unattached_count=0
monthly_waste=0

if [ -n "$eip_data" ]; then
    echo -e "${YELLOW}Found Elastic IPs:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-20s %-20s %s\n" "PUBLIC IP" "STATUS" "INSTANCE ID"
    echo "────────────────────────────────────────────"

    while IFS=$'\t' read -r public_ip instance_id association_id; do
        if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
            ((total_count++))
            
            if [ "$instance_id" == "None" ] || [ -z "$instance_id" ]; then
                printf "${RED}%-20s %-20s${NC} %s\n" "$public_ip" "UNATTACHED" "-"
                ((unattached_count++))
                monthly_waste=$(echo "$monthly_waste + 3.65" | bc)
            else
                printf "${GREEN}%-20s %-20s${NC} %s\n" "$public_ip" "ATTACHED" "$instance_id"
                ((attached_count++))
            fi
        fi
    done <<< "$eip_data"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Summary:${NC}"
    echo "Total Elastic IPs:     $total_count"
    echo "Attached:              $attached_count"
    if [ $unattached_count -gt 0 ]; then
        echo -e "${RED}Unattached:            $unattached_count${NC}"
        echo -e "${RED}Monthly waste:         \$${monthly_waste}${NC}"
    else
        echo -e "${GREEN}Unattached:            $unattached_count${NC}"
    fi
else
    echo -e "${GREEN}No Elastic IPs found in this region${NC}"
fi