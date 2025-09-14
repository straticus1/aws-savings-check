#!/bin/bash

# AWS Selective Infrastructure Shutdown Tool
# Safely stops/terminates AWS resources with user confirmation
# Author: Generated for AWS Cost Control
# Date: $(date)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}=== AWS Selective Infrastructure Shutdown ===${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo -e "${YELLOW}⚠️  This tool will help you safely shutdown AWS resources to save costs${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Function to confirm action
confirm_action() {
    local action="$1"
    local resource="$2"
    echo -e "${YELLOW}Do you want to $action $resource?${NC}"
    echo -e "${RED}This action cannot be easily undone!${NC}"
    read -p "Type 'yes' to confirm: " -r
    if [[ "$REPLY" == "yes" ]]; then
        return 0
    else
        echo -e "${CYAN}Skipped $resource${NC}"
        return 1
    fi
}

# Function to get cost savings estimate
get_ec2_savings() {
    case "$1" in
        "t3.nano") echo "3.80" ;;
        "t3.micro") echo "8.35" ;;
        "t3.small") echo "16.70" ;;
        "t3.medium") echo "30.37" ;;
        "t3.large") echo "66.77" ;;
        "t3.xlarge") echo "133.54" ;;
        "t3.2xlarge") echo "267.07" ;;
        "t4g.nano") echo "3.26" ;;
        "t4g.micro") echo "6.53" ;;
        "t4g.small") echo "13.06" ;;
        "t4g.medium") echo "26.11" ;;
        "m5.large") echo "69.35" ;;
        "m5.xlarge") echo "138.70" ;;
        *) echo "50.00" ;;
    esac
}

get_rds_savings() {
    case "$1" in
        "db.t3.micro") echo "16.79" ;;
        "db.t3.small") echo "33.58" ;;
        "db.t3.medium") echo "67.16" ;;
        "db.t3.large") echo "134.33" ;;
        "db.t4g.micro") echo "13.43" ;;
        "db.t4g.small") echo "26.86" ;;
        "db.t4g.medium") echo "53.73" ;;
        *) echo "100.00" ;;
    esac
}

total_savings=0

# EC2 Instance Management
echo -e "${BOLD}${YELLOW}📊 EC2 INSTANCES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ec2_data=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -n "$ec2_data" ]; then
    echo -e "Found running EC2 instances:\n"

    while IFS=$'\t' read -r instance_id instance_type launch_time name; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            savings=$(get_ec2_savings "$instance_type")
            launch_date=$(date -d "$launch_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${launch_time%+*}" +%s 2>/dev/null || echo "0")
            current_date=$(date +%s)
            days_running=$(( (current_date - launch_date) / 86400 ))

            echo -e "${CYAN}Instance:${NC} $instance_id ($instance_type)"
            echo -e "${CYAN}Name:${NC}     ${name:-'Unnamed'}"
            echo -e "${CYAN}Running:${NC}  ${days_running} days"
            echo -e "${GREEN}Savings:${NC}  \$${savings}/month if stopped"
            echo ""

            echo -e "${YELLOW}Options:${NC}"
            echo "1. Stop (can restart later)"
            echo "2. Terminate (permanent deletion)"
            echo "3. Skip this instance"
            echo ""

            read -p "Choose option (1-3): " -n 1 -r
            echo ""

            case $REPLY in
                1)
                    if confirm_action "STOP" "$instance_id ($instance_type)"; then
                        echo -e "${YELLOW}Stopping $instance_id...${NC}"
                        if aws ec2 stop-instances --instance-ids "$instance_id" &>/dev/null; then
                            echo -e "${GREEN}✓ Successfully stopped $instance_id${NC}"
                            echo -e "${GREEN}💰 Monthly savings: \$${savings}${NC}"
                            total_savings=$(echo "$total_savings + $savings" | bc -l)
                        else
                            echo -e "${RED}✗ Failed to stop $instance_id${NC}"
                        fi
                    fi
                    ;;
                2)
                    echo -e "${RED}⚠️  TERMINATION WARNING ⚠️${NC}"
                    echo -e "${RED}Terminating will permanently delete this instance and all data!${NC}"
                    echo -e "${RED}This includes any files, applications, or configurations on the instance.${NC}"
                    echo ""
                    if confirm_action "TERMINATE (PERMANENTLY DELETE)" "$instance_id ($instance_type)"; then
                        echo -e "${RED}Terminating $instance_id...${NC}"
                        if aws ec2 terminate-instances --instance-ids "$instance_id" &>/dev/null; then
                            echo -e "${GREEN}✓ Successfully terminated $instance_id${NC}"
                            echo -e "${GREEN}💰 Monthly savings: \$${savings}${NC}"
                            total_savings=$(echo "$total_savings + $savings" | bc -l)
                        else
                            echo -e "${RED}✗ Failed to terminate $instance_id${NC}"
                        fi
                    fi
                    ;;
                3)
                    echo -e "${CYAN}Skipped $instance_id${NC}"
                    ;;
                *)
                    echo -e "${RED}Invalid option, skipping $instance_id${NC}"
                    ;;
            esac
            echo ""
        fi
    done <<< "$ec2_data"
else
    echo -e "${GREEN}✓ No running EC2 instances found${NC}"
fi

# RDS Instance Management
echo -e "\n${BOLD}${YELLOW}🗄️  RDS DATABASES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

rds_data=$(aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus,AllocatedStorage]' \
    --output text)

if [ -n "$rds_data" ]; then
    echo -e "Found RDS databases:\n"

    while IFS=$'\t' read -r db_id db_class engine status storage; do
        if [ -n "$db_id" ] && [ "$db_id" != "None" ]; then
            instance_savings=$(get_rds_savings "$db_class")
            storage_savings=$(echo "$storage * 0.115" | bc -l)
            total_db_savings=$(echo "$instance_savings + $storage_savings" | bc -l)

            echo -e "${CYAN}Database:${NC} $db_id ($db_class)"
            echo -e "${CYAN}Engine:${NC}   $engine"
            echo -e "${CYAN}Storage:${NC}  ${storage}GB"
            echo -e "${CYAN}Status:${NC}   $status"
            echo -e "${GREEN}Savings:${NC}  \$$(printf "%.2f" $total_db_savings)/month if stopped"
            echo ""

            echo -e "${YELLOW}Options:${NC}"
            echo "1. Stop (can restart later, keeps data)"
            echo "2. Delete (permanent deletion - creates final snapshot)"
            echo "3. Skip this database"
            echo ""

            read -p "Choose option (1-3): " -n 1 -r
            echo ""

            case $REPLY in
                1)
                    if confirm_action "STOP" "$db_id ($db_class)"; then
                        echo -e "${YELLOW}Stopping $db_id...${NC}"
                        if aws rds stop-db-instance --db-instance-identifier "$db_id" &>/dev/null; then
                            echo -e "${GREEN}✓ Successfully stopped $db_id${NC}"
                            echo -e "${GREEN}💰 Monthly savings: \$$(printf "%.2f" $total_db_savings)${NC}"
                            total_savings=$(echo "$total_savings + $total_db_savings" | bc -l)
                        else
                            echo -e "${RED}✗ Failed to stop $db_id (may not support stopping)${NC}"
                        fi
                    fi
                    ;;
                2)
                    echo -e "${RED}⚠️  DATABASE DELETION WARNING ⚠️${NC}"
                    echo -e "${RED}Deleting will permanently remove this database!${NC}"
                    echo -e "${YELLOW}A final snapshot will be created automatically.${NC}"
                    echo ""
                    if confirm_action "DELETE (with final snapshot)" "$db_id ($db_class)"; then
                        snapshot_id="${db_id}-final-snapshot-$(date +%Y%m%d-%H%M%S)"
                        echo -e "${YELLOW}Deleting $db_id (creating final snapshot: $snapshot_id)...${NC}"
                        if aws rds delete-db-instance \
                            --db-instance-identifier "$db_id" \
                            --final-db-snapshot-identifier "$snapshot_id" \
                            --skip-final-snapshot false &>/dev/null; then
                            echo -e "${GREEN}✓ Successfully deleted $db_id${NC}"
                            echo -e "${GREEN}📸 Final snapshot created: $snapshot_id${NC}"
                            echo -e "${GREEN}💰 Monthly savings: \$$(printf "%.2f" $total_db_savings)${NC}"
                            total_savings=$(echo "$total_savings + $total_db_savings" | bc -l)
                        else
                            echo -e "${RED}✗ Failed to delete $db_id${NC}"
                        fi
                    fi
                    ;;
                3)
                    echo -e "${CYAN}Skipped $db_id${NC}"
                    ;;
                *)
                    echo -e "${RED}Invalid option, skipping $db_id${NC}"
                    ;;
            esac
            echo ""
        fi
    done <<< "$rds_data"
else
    echo -e "${GREEN}✓ No RDS databases found${NC}"
fi

# Unattached Elastic IPs
echo -e "\n${BOLD}${YELLOW}🌐 UNATTACHED ELASTIC IPs${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

unattached_eips=$(aws ec2 describe-addresses \
    --query 'Addresses[?!InstanceId].[PublicIp,AllocationId]' \
    --output text)

if [ -n "$unattached_eips" ]; then
    echo -e "Found unattached Elastic IPs (each costs \$3.65/month):\n"

    while IFS=$'\t' read -r public_ip allocation_id; do
        if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
            echo -e "${CYAN}Elastic IP:${NC} $public_ip"
            echo -e "${CYAN}Allocation:${NC} $allocation_id"
            echo -e "${RED}Status:${NC}     UNATTACHED (wasting money!)"
            echo -e "${GREEN}Savings:${NC}    \$3.65/month if released"
            echo ""

            if confirm_action "RELEASE" "$public_ip"; then
                echo -e "${YELLOW}Releasing $public_ip...${NC}"
                if aws ec2 release-address --allocation-id "$allocation_id" &>/dev/null; then
                    echo -e "${GREEN}✓ Successfully released $public_ip${NC}"
                    echo -e "${GREEN}💰 Monthly savings: \$3.65${NC}"
                    total_savings=$(echo "$total_savings + 3.65" | bc -l)
                else
                    echo -e "${RED}✗ Failed to release $public_ip${NC}"
                fi
            fi
            echo ""
        fi
    done <<< "$unattached_eips"
else
    echo -e "${GREEN}✓ No unattached Elastic IPs found${NC}"
fi

# Summary
echo -e "\n${BOLD}${BLUE}=== SHUTDOWN SUMMARY ===${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( $(echo "$total_savings > 0" | bc -l) )); then
    echo -e "${GREEN}💰 Total Monthly Savings: \$$(printf "%.2f" $total_savings)${NC}"
    echo -e "${GREEN}💰 Annual Savings: \$$(echo "$total_savings * 12" | bc -l | xargs printf "%.2f")${NC}"
    echo ""
    echo -e "${YELLOW}Resources have been shutdown successfully!${NC}"
    echo -e "${BLUE}You can restart stopped instances/databases anytime through AWS console or CLI.${NC}"
else
    echo -e "${YELLOW}No resources were shutdown.${NC}"
fi

echo ""
echo -e "${CYAN}💡 Next Steps:${NC}"
echo -e "  • Monitor your AWS billing to see cost reductions"
echo -e "  • Use ${GREEN}./view-infrastructure.sh${NC} to check remaining resources"
echo -e "  • Set up AWS Budgets for ongoing cost monitoring"

# Save shutdown report
timestamp=$(date +%Y%m%d-%H%M%S)
mkdir -p reports
report_file="reports/shutdown-report-$timestamp.txt"
{
    echo "AWS Infrastructure Shutdown Report - Generated $(date)"
    echo "===================================================="
    echo ""
    echo "Total Monthly Savings: \$$(printf "%.2f" $total_savings)"
    echo "Annual Savings: \$$(echo "$total_savings * 12" | bc -l | xargs printf "%.2f")"
    echo ""
    echo "Actions taken during this session have been logged above."
} > "$report_file"

echo -e "\n${GREEN}📄 Shutdown report saved to: $report_file${NC}"