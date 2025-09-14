#!/bin/bash

# AWS Emergency Destroy-All Tool
# DANGEROUS: Shuts down ALL AWS resources immediately
# Use only in true emergencies to stop runaway costs
# Author: Generated for Emergency Cost Control
# Date: $(date)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
BLINK='\033[5m'
NC='\033[0m' # No Color

echo -e "${BOLD}${RED}${BLINK}⚠️  EMERGENCY DESTROY-ALL ACTIVATED ⚠️${NC}"
echo -e "${BOLD}${RED}════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}This script will IMMEDIATELY shutdown/terminate ALL AWS resources:${NC}"
echo -e "${RED}• ALL running EC2 instances will be TERMINATED (permanent)${NC}"
echo -e "${RED}• ALL RDS databases will be DELETED (with final snapshots)${NC}"
echo -e "${RED}• ALL unattached Elastic IPs will be RELEASED${NC}"
echo ""
echo -e "${YELLOW}This is designed for EMERGENCY use only when costs are spiraling out of control!${NC}"
echo ""
echo -e "${RED}THIS ACTION CANNOT BE EASILY UNDONE!${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Triple confirmation required
echo -e "${BOLD}${RED}EMERGENCY CONFIRMATION REQUIRED${NC}"
echo -e "${RED}You must type exactly what is requested to proceed:${NC}"
echo ""

read -p "Type 'EMERGENCY' to continue: " -r
if [[ "$REPLY" != "EMERGENCY" ]]; then
    echo -e "${GREEN}Emergency shutdown cancelled. Exiting safely.${NC}"
    exit 0
fi

read -p "Type 'DESTROY-ALL' to confirm: " -r
if [[ "$REPLY" != "DESTROY-ALL" ]]; then
    echo -e "${GREEN}Emergency shutdown cancelled. Exiting safely.${NC}"
    exit 0
fi

read -p "Type 'I-UNDERSTAND-THIS-CANNOT-BE-UNDONE' to proceed: " -r
if [[ "$REPLY" != "I-UNDERSTAND-THIS-CANNOT-BE-UNDONE" ]]; then
    echo -e "${GREEN}Emergency shutdown cancelled. Exiting safely.${NC}"
    exit 0
fi

echo ""
echo -e "${RED}🚨 EMERGENCY SHUTDOWN INITIATED 🚨${NC}"
echo -e "${YELLOW}Starting immediate shutdown of all AWS resources...${NC}"
echo ""

total_savings=0

# Emergency EC2 termination
echo -e "${BOLD}${RED}🔥 TERMINATING ALL EC2 INSTANCES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ec2_instances=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)

if [ -n "$ec2_instances" ]; then
    instance_count=0
    for instance_id in $ec2_instances; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            echo -e "${RED}⚡ TERMINATING: $instance_id${NC}"
            aws ec2 terminate-instances --instance-ids "$instance_id" &>/dev/null || echo -e "${RED}  └─ Failed to terminate $instance_id${NC}"
            ((instance_count++))
            # Rough savings estimate
            total_savings=$(echo "$total_savings + 40" | bc -l)
        fi
    done
    echo -e "${GREEN}✓ Initiated termination of $instance_count EC2 instances${NC}"
    echo -e "${GREEN}💰 Estimated EC2 savings: \$$(echo "$instance_count * 40" | bc -l)/month${NC}"
else
    echo -e "${YELLOW}ℹ️  No running EC2 instances found${NC}"
fi

echo ""

# Emergency RDS deletion
echo -e "${BOLD}${RED}🔥 DELETING ALL RDS DATABASES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

rds_instances=$(aws rds describe-db-instances \
    --query 'DBInstances[*].DBInstanceIdentifier' \
    --output text)

if [ -n "$rds_instances" ]; then
    db_count=0
    for db_id in $rds_instances; do
        if [ -n "$db_id" ] && [ "$db_id" != "None" ]; then
            snapshot_id="${db_id}-emergency-snapshot-$(date +%Y%m%d-%H%M%S)"
            echo -e "${RED}⚡ DELETING: $db_id (creating emergency snapshot: $snapshot_id)${NC}"

            # Try to delete with final snapshot first
            if aws rds delete-db-instance \
                --db-instance-identifier "$db_id" \
                --final-db-snapshot-identifier "$snapshot_id" \
                --skip-final-snapshot false &>/dev/null; then
                echo -e "${GREEN}  ✓ Deleted with emergency snapshot${NC}"
            else
                # If that fails, try without snapshot (for read replicas, etc.)
                echo -e "${YELLOW}  └─ Snapshot failed, attempting force delete...${NC}"
                aws rds delete-db-instance \
                    --db-instance-identifier "$db_id" \
                    --skip-final-snapshot true &>/dev/null || echo -e "${RED}  └─ Failed to delete $db_id${NC}"
            fi
            ((db_count++))
            # Rough savings estimate
            total_savings=$(echo "$total_savings + 80" | bc -l)
        fi
    done
    echo -e "${GREEN}✓ Initiated deletion of $db_count RDS databases${NC}"
    echo -e "${GREEN}💰 Estimated RDS savings: \$$(echo "$db_count * 80" | bc -l)/month${NC}"
else
    echo -e "${YELLOW}ℹ️  No RDS databases found${NC}"
fi

echo ""

# Emergency Elastic IP release
echo -e "${BOLD}${RED}🔥 RELEASING ALL UNATTACHED ELASTIC IPs${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

unattached_eips=$(aws ec2 describe-addresses \
    --query 'Addresses[?!InstanceId].[PublicIp,AllocationId]' \
    --output text)

if [ -n "$unattached_eips" ]; then
    eip_count=0
    while IFS=$'\t' read -r public_ip allocation_id; do
        if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
            echo -e "${RED}⚡ RELEASING: $public_ip${NC}"
            aws ec2 release-address --allocation-id "$allocation_id" &>/dev/null || echo -e "${RED}  └─ Failed to release $public_ip${NC}"
            ((eip_count++))
            total_savings=$(echo "$total_savings + 3.65" | bc -l)
        fi
    done <<< "$unattached_eips"
    echo -e "${GREEN}✓ Released $eip_count unattached Elastic IPs${NC}"
    echo -e "${GREEN}💰 EIP savings: \$$(echo "$eip_count * 3.65" | bc -l)/month${NC}"
else
    echo -e "${YELLOW}ℹ️  No unattached Elastic IPs found${NC}"
fi

echo ""

# Emergency completion summary
echo -e "${BOLD}${GREEN}🚨 EMERGENCY SHUTDOWN COMPLETE 🚨${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}💰 Estimated Total Monthly Savings: \$$(printf "%.2f" $total_savings)${NC}"
echo -e "${GREEN}💰 Estimated Annual Savings: \$$(echo "$total_savings * 12" | bc -l | xargs printf "%.2f")${NC}"
echo ""
echo -e "${YELLOW}⚡ EMERGENCY ACTIONS TAKEN:${NC}"
echo -e "${RED}• All running EC2 instances have been TERMINATED${NC}"
echo -e "${RED}• All RDS databases have been DELETED (with emergency snapshots where possible)${NC}"
echo -e "${RED}• All unattached Elastic IPs have been RELEASED${NC}"
echo ""
echo -e "${CYAN}📋 IMPORTANT POST-EMERGENCY NOTES:${NC}"
echo -e "${YELLOW}• EC2 termination is PERMANENT - instances cannot be restarted${NC}"
echo -e "${YELLOW}• RDS deletion is PERMANENT - databases cannot be restored except from snapshots${NC}"
echo -e "${YELLOW}• Elastic IP releases are PERMANENT - you'll get new IPs if you allocate again${NC}"
echo -e "${GREEN}• Emergency snapshots were created where possible for data recovery${NC}"
echo ""
echo -e "${BLUE}🔍 NEXT STEPS:${NC}"
echo -e "1. Monitor AWS billing to confirm cost reductions"
echo -e "2. Review emergency snapshots for data recovery needs"
echo -e "3. Set up AWS Budgets and alerts to prevent future emergencies"
echo -e "4. Use ${GREEN}./view-infrastructure.sh${NC} to verify all resources are shutdown"
echo -e "5. Plan your infrastructure rebuild carefully with cost controls"

# Save emergency report
timestamp=$(date +%Y%m%d-%H%M%S)
mkdir -p reports
report_file="reports/emergency-destroyall-$timestamp.txt"
{
    echo "AWS EMERGENCY DESTROY-ALL REPORT - Generated $(date)"
    echo "=================================================="
    echo ""
    echo "⚠️  EMERGENCY SHUTDOWN EXECUTED ⚠️"
    echo ""
    echo "Estimated Total Monthly Savings: \$$(printf "%.2f" $total_savings)"
    echo "Estimated Annual Savings: \$$(echo "$total_savings * 12" | bc -l | xargs printf "%.2f")"
    echo ""
    echo "ACTIONS TAKEN:"
    echo "• ALL running EC2 instances TERMINATED"
    echo "• ALL RDS databases DELETED (with emergency snapshots where possible)"
    echo "• ALL unattached Elastic IPs RELEASED"
    echo ""
    echo "This was an EMERGENCY shutdown to prevent runaway AWS costs."
    echo "All actions were PERMANENT and cannot be easily undone."
    echo ""
    echo "Emergency snapshots were created where possible for data recovery."
} > "$report_file"

echo -e "\n${RED}📄 EMERGENCY REPORT SAVED: $report_file${NC}"

# Final warning
echo ""
echo -e "${BOLD}${RED}⚠️  EMERGENCY SHUTDOWN COMPLETE ⚠️${NC}"
echo -e "${RED}Your AWS infrastructure has been destroyed to prevent further costs.${NC}"
echo -e "${YELLOW}Review the emergency snapshots for any data recovery needs.${NC}"