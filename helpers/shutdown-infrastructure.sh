#!/bin/bash

# AWS Infrastructure Shutdown Script
# Safely shuts down infrastructure components
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

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --preserve-elastic-ip  Keep Elastic IPs even if unattached"
    echo "  -h, --help            Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preserve-elastic-ip)
            PRESERVE_EIP=true
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

echo -e "${BOLD}${BLUE}=== AWS Infrastructure Shutdown ===${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo -e "${YELLOW}This tool will help you safely shutdown AWS resources to save costs${NC}"
echo ""

# Check AWS CLI configuration
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

# Get running EC2 instances
ec2_data=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -n "$ec2_data" ]; then
    echo "Running EC2 Instances:"
    while IFS=$'\t' read -r instance_id instance_type launch_time name; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            instance_cost=$(get_ec2_savings "$instance_type")
            launch_date=$(date -d "$launch_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${launch_time%+*}" +%s 2>/dev/null || echo "0")
            current_date=$(date +%s)
            days_running=$(( (current_date - launch_date) / 86400 ))

            echo -e "${CYAN}Instance:${NC} $instance_id ($instance_type)"
            echo -e "${CYAN}Name:${NC}     ${name:-'Unnamed'}"
            echo -e "${CYAN}Running:${NC}  ${days_running} days"
            echo -e "${GREEN}Savings:${NC}  \$${instance_cost}/month if stopped"
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
                            echo -e "${GREEN}💰 Monthly savings: \$${instance_cost}${NC}"
                            total_savings=$(echo "$total_savings + $instance_cost" | bc -l)
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
                            echo -e "${GREEN}💰 Monthly savings: \$${instance_cost}${NC}"
                            total_savings=$(echo "$total_savings + $instance_cost" | bc -l)
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

# Handle Elastic IPs based on preservation setting
if [ "$PRESERVE_EIP" = "true" ]; then
    echo -e "\n${BOLD}${YELLOW}🌐 ELASTIC IPs${NC} (preservation enabled)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Elastic IPs will be preserved as requested.${NC}"
    echo -e "${CYAN}Tip: Remove --preserve-elastic-ip option to clean up unattached IPs.${NC}"
    eip_count=$(aws ec2 describe-addresses --query 'length(Addresses)' --output text)
    echo -e "${CYAN}Currently preserving $eip_count Elastic IP(s)${NC}"
else
    echo -e "\n${BOLD}${YELLOW}🌐 UNATTACHED ELASTIC IPs${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
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
fi

# Summary
echo -e "\n${BOLD}${BLUE}=== SHUTDOWN SUMMARY ===${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
echo "  • Monitor your AWS billing to see cost reductions"
echo "  • Use ${GREEN}./view-infrastructure.sh${NC} to check remaining resources"
echo "  • Set up AWS Budgets for ongoing cost monitoring"

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
    if [ "$PRESERVE_EIP" = "true" ]; then
        echo "Note: Elastic IPs were preserved as requested"
    fi
    echo "Actions taken during this session have been logged above."
} > "$report_file"

echo -e "\n${GREEN}📄 Shutdown report saved to: $report_file${NC}"
