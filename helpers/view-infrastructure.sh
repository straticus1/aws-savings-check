#!/bin/bash

# AWS Infrastructure Visibility Tool
# Shows all running resources with costs and age
# Author: Generated for AWS Infrastructure Management
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

# AWS Pricing (US-East-1) - Updated as of September 2024
get_ec2_price() {
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
        *) echo "50.00" ;;  # Default estimate
    esac
}

get_rds_price() {
    case "$1" in
        "db.t3.micro") echo "16.79" ;;
        "db.t3.small") echo "33.58" ;;
        "db.t3.medium") echo "67.16" ;;
        "db.t3.large") echo "134.33" ;;
        "db.t4g.micro") echo "13.43" ;;
        "db.t4g.small") echo "26.86" ;;
        "db.t4g.medium") echo "53.73" ;;
        *) echo "100.00" ;;  # Default estimate
    esac
}

# Storage pricing per GB/month
EBS_GP3_PRICE="0.096"
RDS_STORAGE_PRICE="0.115"
ELASTIC_IP_PRICE="3.65"

echo -e "${BOLD}${BLUE}=== AWS Infrastructure Overview ===${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo -e "${BLUE}Time: $(date)${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Function to calculate days running
calculate_days_running() {
    local launch_time="$1"
    local launch_date=$(date -d "$launch_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${launch_time%+*}" +%s 2>/dev/null || echo "0")
    local current_date=$(date +%s)
    echo $(( (current_date - launch_date) / 86400 ))
}

# Function to calculate cost per day
calculate_daily_cost() {
    local monthly_cost="$1"
    echo "scale=2; $monthly_cost / 30" | bc -l
}

total_monthly_cost=0
total_daily_waste=0

echo -e "${BOLD}${YELLOW}📊 EC2 INSTANCES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get running EC2 instances
ec2_data=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output text)

ec2_total_cost=0
ec2_count=0

if [ -n "$ec2_data" ]; then
    printf "%-20s %-12s %-15s %-12s %-10s %s\n" "INSTANCE ID" "TYPE" "NAME" "AGE" "$/MONTH" "$/DAY"
    echo "────────────────────────────────────────────────────────────────────────────────"

    while IFS=$'\t' read -r instance_id instance_type launch_time name state; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            instance_cost=$(get_ec2_price "$instance_type")
            daily_cost=$(calculate_daily_cost "$instance_cost")
            days_running=$(calculate_days_running "$launch_time")

            # Color coding based on age (red for old instances)
            if (( days_running > 7 )); then
                age_color="${RED}"
            elif (( days_running > 3 )); then
                age_color="${YELLOW}"
            else
                age_color="${GREEN}"
            fi

            printf "%-20s %-12s %-15s ${age_color}%-10s${NC} ${GREEN}\$%-8.2f${NC} ${CYAN}\$%-6.2f${NC}\n" \
                "$instance_id" "$instance_type" "${name:-'Unnamed'}" "${days_running}d" "$instance_cost" "$daily_cost"

            ec2_total_cost=$(echo "$ec2_total_cost + $instance_cost" | bc -l)
            ((ec2_count++))

            # Calculate waste for instances running > 7 days
            if (( days_running > 7 )); then
                waste_days=$((days_running - 7))
                waste_cost=$(echo "$daily_cost * $waste_days" | bc -l)
                total_daily_waste=$(echo "$total_daily_waste + $waste_cost" | bc -l)
            fi
        fi
    done <<< "$ec2_data"

    echo "────────────────────────────────────────────────────────────────────────────────"
    printf "${BOLD}TOTAL EC2 (%d instances): \$%.2f/month${NC}\n" $ec2_count $(printf "%.2f" $ec2_total_cost)
else
    echo -e "${GREEN}✓ No running EC2 instances${NC}"
fi

total_monthly_cost=$(echo "$total_monthly_cost + $ec2_total_cost" | bc -l)

echo -e "\n${BOLD}${YELLOW}🗄️  RDS DATABASES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get RDS instances
rds_data=$(aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus,AllocatedStorage,InstanceCreateTime]' \
    --output text)

rds_total_cost=0
rds_count=0

if [ -n "$rds_data" ]; then
    printf "%-25s %-15s %-10s %-8s %-10s %s\n" "DATABASE ID" "CLASS" "ENGINE" "STORAGE" "AGE" "$/MONTH"
    echo "────────────────────────────────────────────────────────────────────────────────"

    while IFS=$'\t' read -r db_id db_class engine status storage create_time; do
        if [ -n "$db_id" ] && [ "$db_id" != "None" ]; then
            db_instance_cost=$(get_rds_price "$db_class")
            storage_cost=$(echo "$storage * $RDS_STORAGE_PRICE" | bc -l)
            total_db_cost=$(echo "$db_instance_cost + $storage_cost" | bc -l)
            days_running=$(calculate_days_running "$create_time")

            # Color coding based on age
            if (( days_running > 14 )); then
                age_color="${RED}"
            elif (( days_running > 7 )); then
                age_color="${YELLOW}"
            else
                age_color="${GREEN}"
            fi

            printf "%-25s %-15s %-10s %-8s ${age_color}%-8s${NC} ${GREEN}\$%-8.2f${NC}\n" \
                "$db_id" "$db_class" "$engine" "${storage}GB" "${days_running}d" "$total_db_cost"

            rds_total_cost=$(echo "$rds_total_cost + $total_db_cost" | bc -l)
            ((rds_count++))

            # Calculate waste for RDS running > 14 days
            if (( days_running > 14 )); then
                daily_db_cost=$(calculate_daily_cost "$total_db_cost")
                waste_days=$((days_running - 14))
                waste_cost=$(echo "$daily_db_cost * $waste_days" | bc -l)
                total_daily_waste=$(echo "$total_daily_waste + $waste_cost" | bc -l)
            fi
        fi
    done <<< "$rds_data"

    echo "────────────────────────────────────────────────────────────────────────────────"
    printf "${BOLD}TOTAL RDS (%d databases): \$%.2f/month${NC}\n" $rds_count $(printf "%.2f" $rds_total_cost)
else
    echo -e "${GREEN}✓ No RDS databases running${NC}"
fi

total_monthly_cost=$(echo "$total_monthly_cost + $rds_total_cost" | bc -l)

echo -e "\n${BOLD}${YELLOW}🌐 ELASTIC IPs${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get Elastic IPs
eip_data=$(aws ec2 describe-addresses \
    --query 'Addresses[*].[PublicIp,InstanceId,AssociationId]' \
    --output text)

eip_cost=0
eip_count=0
unattached_eips=0

if [ -n "$eip_data" ]; then
    printf "%-18s %-20s %-10s %s\n" "ELASTIC IP" "ATTACHED TO" "STATUS" "$/MONTH"
    echo "────────────────────────────────────────────────────────────────────────────────"

    while IFS=$'\t' read -r public_ip instance_id association_id; do
        if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
            if [ "$instance_id" == "None" ] || [ -z "$instance_id" ]; then
                printf "%-18s %-20s ${RED}%-10s${NC} ${RED}\$%-8.2f${NC}\n" \
                    "$public_ip" "UNATTACHED" "WASTING" "$ELASTIC_IP_PRICE"
                eip_cost=$(echo "$eip_cost + $ELASTIC_IP_PRICE" | bc -l)
                ((unattached_eips++))
            else
                printf "%-18s %-20s ${GREEN}%-10s${NC} ${GREEN}\$%-8.2f${NC}\n" \
                    "$public_ip" "$instance_id" "ATTACHED" "0.00"
            fi
            ((eip_count++))
        fi
    done <<< "$eip_data"

    echo "────────────────────────────────────────────────────────────────────────────────"
    if (( unattached_eips > 0 )); then
        printf "${BOLD}${RED}WARNING: %d unattached EIPs costing \$%.2f/month!${NC}\n" $unattached_eips $(printf "%.2f" $eip_cost)
    else
        printf "${BOLD}${GREEN}All EIPs properly attached${NC}\n"
    fi
else
    echo -e "${GREEN}✓ No Elastic IPs found${NC}"
fi

total_monthly_cost=$(echo "$total_monthly_cost + $eip_cost" | bc -l)

# Summary
echo -e "\n${BOLD}${BLUE}=== COST SUMMARY ===${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "EC2 Instances (%d):     ${GREEN}\$%8.2f/month${NC}\n" $ec2_count $(printf "%.2f" $ec2_total_cost)
printf "RDS Databases (%d):     ${GREEN}\$%8.2f/month${NC}\n" $rds_count $(printf "%.2f" $rds_total_cost)
printf "Unattached EIPs (%d):   ${RED}\$%8.2f/month${NC}\n" $unattached_eips $(printf "%.2f" $eip_cost)
echo "────────────────────────────────────────────────────────────────────────────────"
printf "${BOLD}TOTAL CURRENT COST:     \$%8.2f/month${NC}\n" $(printf "%.2f" $total_monthly_cost)

if (( $(echo "$total_daily_waste > 0" | bc -l) )); then
    echo ""
    printf "${BOLD}${RED}💸 ESTIMATED WASTE (resources running too long): \$%.2f${NC}\n" $(printf "%.2f" $total_daily_waste)
    echo -e "${YELLOW}   (Based on EC2 instances running >7 days, RDS >14 days)${NC}"
fi

echo ""
echo -e "${BOLD}${CYAN}💡 QUICK ACTIONS:${NC}"
echo -e "  • Run ${YELLOW}./helpers/shutdown-infrastructure.sh${NC} for selective shutdown"
echo -e "  • Run ${RED}./helpers/emergency-destroyall.sh${NC} for emergency shutdown"
echo -e "  • Use ${BLUE}../scripts/optimize-costs.sh${NC} for detailed optimization"

# Save report
timestamp=$(date +%Y%m%d-%H%M%S)
report_file="infrastructure-report-$timestamp.txt"
{
    echo "AWS Infrastructure Report - Generated $(date)"
    echo "============================================"
    echo ""
    echo "EC2 Instances: $ec2_count (\$$(printf "%.2f" $ec2_total_cost)/month)"
    echo "RDS Databases: $rds_count (\$$(printf "%.2f" $rds_total_cost)/month)"
    echo "Unattached EIPs: $unattached_eips (\$$(printf "%.2f" $eip_cost)/month)"
    echo "Total Monthly Cost: \$$(printf "%.2f" $total_monthly_cost)"
    if (( $(echo "$total_daily_waste > 0" | bc -l) )); then
        echo "Estimated Waste: \$$(printf "%.2f" $total_daily_waste)"
    fi
} > "reports/$report_file"

echo -e "\n${GREEN}📄 Report saved to: reports/$report_file${NC}"