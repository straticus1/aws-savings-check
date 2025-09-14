#!/bin/bash

# AWS Emergency Infrastructure Destroy Script
# Use with extreme caution - this will terminate all resources
# Author: Generated for AWS Infrastructure Management
# Date: $(date)

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default settings
PRESERVE_EIP=false
CONFIRMED=false

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --preserve-elastic-ip  Keep Elastic IPs even if unattached"
    echo "  --yes                 Skip confirmation (USE WITH EXTREME CAUTION)"
    echo "  -h, --help           Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preserve-elastic-ip)
            PRESERVE_EIP=true
            shift
            ;;
        --yes)
            CONFIRMED=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo -e "${BOLD}${RED}⚠️  AWS EMERGENCY INFRASTRUCTURE DESTROY ⚠️${NC}"
echo -e "${RED}This script will TERMINATE ALL RESOURCES in the current region${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo ""

# Check AWS CLI configuration
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

if [ "$CONFIRMED" != "true" ]; then
    echo -e "${RED}⚠️  WARNING ⚠️${NC}"
    echo -e "${RED}This will:"
    echo "1. Terminate ALL EC2 instances"
    echo "2. Delete ALL RDS databases (with final snapshot)"
    echo "3. Delete ALL ECS services and tasks"
    echo "4. Delete ALL Lambda functions"
    if [ "$PRESERVE_EIP" = "true" ]; then
        echo "5. PRESERVE all Elastic IPs${NC}"
    else
        echo "5. Release ALL Elastic IPs${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Are you absolutely sure you want to continue?${NC}"
    read -p "Type 'DESTROY ALL' to confirm: " -r
    echo
    if [[ ! $REPLY == "DESTROY ALL" ]]; then
        echo -e "${GREEN}Aborted.${NC}"
        exit 1
    fi
fi

# Initialize counters
terminated_instances=0
deleted_databases=0
released_eips=0

echo -e "\n${YELLOW}Starting emergency shutdown...${NC}"

# 1. Terminate EC2 instances
echo -e "\n${BOLD}${YELLOW}1. Terminating EC2 Instances${NC}"
instance_ids=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[*].Instances[*].[InstanceId]' \
    --output text)

if [ -n "$instance_ids" ]; then
    for id in $instance_ids; do
        echo -e "${RED}Terminating${NC} instance $id..."
        aws ec2 terminate-instances --instance-ids "$id" &>/dev/null
        ((terminated_instances++))
    done
else
    echo -e "${GREEN}No EC2 instances found${NC}"
fi

# 2. Delete RDS databases
echo -e "\n${BOLD}${YELLOW}2. Deleting RDS Databases${NC}"
db_instances=$(aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier]' \
    --output text)

if [ -n "$db_instances" ]; then
    for db in $db_instances; do
        snapshot_id="${db}-final-snapshot-$(date +%Y%m%d-%H%M%S)"
        echo -e "${RED}Deleting${NC} database $db (creating final snapshot: $snapshot_id)..."
        aws rds delete-db-instance \
            --db-instance-identifier "$db" \
            --final-db-snapshot-identifier "$snapshot_id" \
            --skip-final-snapshot false &>/dev/null
        ((deleted_databases++))
    done
else
    echo -e "${GREEN}No RDS databases found${NC}"
fi

# 3. Handle Elastic IPs based on preservation setting
if [ "$PRESERVE_EIP" = "false" ]; then
    echo -e "\n${BOLD}${YELLOW}3. Releasing Elastic IPs${NC}"
    eip_allocations=$(aws ec2 describe-addresses \
        --query 'Addresses[*].[AllocationId]' \
        --output text)

    if [ -n "$eip_allocations" ]; then
        for alloc in $eip_allocations; do
            echo -e "${RED}Releasing${NC} Elastic IP $alloc..."
            aws ec2 release-address --allocation-id "$alloc" &>/dev/null
            ((released_eips++))
        done
    else
        echo -e "${GREEN}No Elastic IPs found${NC}"
    fi
else
    echo -e "\n${BOLD}${YELLOW}3. Preserving Elastic IPs as requested${NC}"
    eip_count=$(aws ec2 describe-addresses --query 'length(Addresses)' --output text)
    echo -e "${CYAN}Preserving $eip_count Elastic IP(s)${NC}"
fi

# Summary
echo -e "\n${BOLD}${BLUE}=== EMERGENCY DESTROY SUMMARY ===${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "EC2 Instances Terminated: ${RED}$terminated_instances${NC}"
echo -e "RDS Databases Deleted:    ${RED}$deleted_databases${NC}"
if [ "$PRESERVE_EIP" = "false" ]; then
    echo -e "Elastic IPs Released:    ${RED}$released_eips${NC}"
else
    echo -e "Elastic IPs:            ${GREEN}Preserved${NC}"
fi

echo -e "\n${YELLOW}💡 Next Steps:${NC}"
echo "• Monitor AWS Console for resource deletion progress"
echo "• Check CloudWatch for any remaining resources"
echo "• Review final RDS snapshots if needed"
if [ "$PRESERVE_EIP" = "true" ]; then
    echo "• Elastic IPs have been preserved and may still incur costs"
fi

# Save destroy report
timestamp=$(date +%Y%m%d-%H%M%S)
mkdir -p reports
report_file="reports/emergency-destroy-report-$timestamp.txt"

{
    echo "AWS Emergency Infrastructure Destroy Report"
    echo "Generated: $(date)"
    echo "Region: $(aws configure get region || echo 'default')"
    echo ""
    echo "Resources Destroyed:"
    echo "• EC2 Instances: $terminated_instances"
    echo "• RDS Databases: $deleted_databases"
    if [ "$PRESERVE_EIP" = "false" ]; then
        echo "• Elastic IPs Released: $released_eips"
    else
        echo "• Elastic IPs: Preserved"
    fi
} > "$report_file"

echo -e "\n${GREEN}📄 Destroy report saved to: $report_file${NC}"
