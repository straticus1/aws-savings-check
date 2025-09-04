#!/bin/bash

# AWS Monthly Cost Estimator
# Analyzes running AWS services and estimates monthly costs
# Author: Generated for NiteText AWS Cost Analysis
# Date: $(date)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        *) echo "0" ;;
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
        *) echo "0" ;;
    esac
}

# Storage pricing per GB/month
EBS_GP3_PRICE="0.096"
RDS_STORAGE_PRICE="0.115"
ELASTIC_IP_PRICE="3.65"

echo -e "${BLUE}=== AWS Monthly Cost Estimator ===${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

total_cost=0

echo -e "${YELLOW}📊 Analyzing EC2 Instances...${NC}"
ec2_cost=0
ec2_count=0

# Get running EC2 instances
ec2_data=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -n "$ec2_data" ]; then
    echo "Running EC2 Instances:"
    while IFS=$'\t' read -r instance_id instance_type launch_time name; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            instance_cost=$(get_ec2_price "$instance_type")
            if [ "$instance_cost" == "0" ]; then
                echo -e "  ${RED}⚠️  Unknown pricing for $instance_type${NC}"
                instance_cost="50.00"  # Default estimate
            fi
            
            # Calculate days running
            launch_date=$(date -d "$launch_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${launch_time%+*}" +%s 2>/dev/null || echo "0")
            current_date=$(date +%s)
            days_running=$(( (current_date - launch_date) / 86400 ))
            
            echo -e "  ${GREEN}✓${NC} $instance_id ($instance_type) - ${name:-'Unnamed'} - \$${instance_cost}/month (${days_running} days old)"
            ec2_cost=$(echo "$ec2_cost + $instance_cost" | bc -l)
            ((ec2_count++))
        fi
    done <<< "$ec2_data"
else
    echo "  No running EC2 instances found"
fi

echo -e "\n${YELLOW}💾 Analyzing EBS Volumes...${NC}"
ebs_cost=0
ebs_count=0

# Get EBS volumes in use
ebs_data=$(aws ec2 describe-volumes \
    --filters Name=status,Values=in-use \
    --query 'Volumes[*].[VolumeId,Size,VolumeType,Attachments[0].InstanceId]' \
    --output text)

if [ -n "$ebs_data" ]; then
    echo "EBS Volumes in use:"
    while IFS=$'\t' read -r volume_id size volume_type instance_id; do
        if [ -n "$volume_id" ] && [ "$volume_id" != "None" ]; then
            volume_cost=$(echo "$size * $EBS_GP3_PRICE" | bc -l)
            echo -e "  ${GREEN}✓${NC} $volume_id (${size}GB $volume_type) → $instance_id - \$$(printf "%.2f" $volume_cost)/month"
            ebs_cost=$(echo "$ebs_cost + $volume_cost" | bc -l)
            ((ebs_count++))
        fi
    done <<< "$ebs_data"
else
    echo "  No EBS volumes found"
fi

echo -e "\n${YELLOW}🗄️  Analyzing RDS Instances...${NC}"
rds_cost=0
rds_count=0

# Get RDS instances
rds_data=$(aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus,AllocatedStorage]' \
    --output text)

if [ -n "$rds_data" ]; then
    echo "RDS Instances:"
    while IFS=$'\t' read -r db_id db_class engine status storage; do
        if [ -n "$db_id" ] && [ "$db_id" != "None" ]; then
            db_instance_cost=$(get_rds_price "$db_class")
            if [ "$db_instance_cost" == "0" ]; then
                echo -e "  ${RED}⚠️  Unknown pricing for $db_class${NC}"
                db_instance_cost="100.00"  # Default estimate
            fi
            
            storage_cost=$(echo "$storage * $RDS_STORAGE_PRICE" | bc -l)
            total_db_cost=$(echo "$db_instance_cost + $storage_cost" | bc -l)
            
            echo -e "  ${GREEN}✓${NC} $db_id ($db_class, $engine) - ${storage}GB storage - \$$(printf "%.2f" $total_db_cost)/month"
            echo -e "    └─ Instance: \$$(printf "%.2f" $db_instance_cost), Storage: \$$(printf "%.2f" $storage_cost)"
            rds_cost=$(echo "$rds_cost + $total_db_cost" | bc -l)
            ((rds_count++))
        fi
    done <<< "$rds_data"
else
    echo "  No RDS instances found"
fi

echo -e "\n${YELLOW}🌐 Analyzing Elastic IPs...${NC}"
eip_cost=0
eip_count=0

# Get Elastic IPs
eip_data=$(aws ec2 describe-addresses \
    --query 'Addresses[*].[PublicIp,InstanceId,AssociationId]' \
    --output text)

if [ -n "$eip_data" ]; then
    echo "Elastic IPs:"
    while IFS=$'\t' read -r public_ip instance_id association_id; do
        if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
            if [ "$instance_id" == "None" ] || [ -z "$instance_id" ]; then
                echo -e "  ${RED}⚠️${NC}  $public_ip (UNATTACHED - costing money!) - \$${ELASTIC_IP_PRICE}/month"
                eip_cost=$(echo "$eip_cost + $ELASTIC_IP_PRICE" | bc -l)
            else
                echo -e "  ${GREEN}✓${NC} $public_ip → $instance_id - \$0.00/month (attached)"
            fi
            ((eip_count++))
        fi
    done <<< "$eip_data"
else
    echo "  No Elastic IPs found"
fi

# Calculate total
total_cost=$(echo "$ec2_cost + $ebs_cost + $rds_cost + $eip_cost" | bc -l)

# Add estimated data transfer costs
data_transfer_estimate="10.00"
total_with_transfer=$(echo "$total_cost + $data_transfer_estimate" | bc -l)

echo -e "\n${BLUE}=== COST SUMMARY ===${NC}"
echo -e "EC2 Instances ($ec2_count):    \$$(printf "%8.2f" $ec2_cost)"
echo -e "EBS Storage ($ebs_count):      \$$(printf "%8.2f" $ebs_cost)"
echo -e "RDS Database ($rds_count):     \$$(printf "%8.2f" $rds_cost)"
echo -e "Elastic IPs ($eip_count):      \$$(printf "%8.2f" $eip_cost)"
echo -e "Data Transfer (est):   \$$(printf "%8.2f" $data_transfer_estimate)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}TOTAL MONTHLY COST:    \$$(printf "%8.2f" $total_with_transfer)${NC}"

# Cost optimization suggestions
echo -e "\n${YELLOW}💡 Cost Optimization Suggestions:${NC}"

if (( $(echo "$eip_cost > 0" | bc -l) )); then
    echo -e "  ${RED}•${NC} Release unattached Elastic IPs to save \$$(printf "%.2f" $eip_cost)/month"
fi

if (( ec2_count > 2 )); then
    echo -e "  ${YELLOW}•${NC} Consider consolidating EC2 instances if possible"
fi

if (( $(echo "$rds_cost > 60" | bc -l) )); then
    echo -e "  ${YELLOW}•${NC} Consider downgrading RDS instance class if database load is light"
fi

echo -e "  ${BLUE}•${NC} Monitor AWS Cost Explorer for detailed usage patterns"
echo -e "  ${BLUE}•${NC} Set up AWS Budgets and billing alerts"

# Save detailed report
report_file="aws-cost-report-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "AWS Cost Report - Generated $(date)"
    echo "======================================"
    echo ""
    echo "EC2 Cost: \$$(printf "%.2f" $ec2_cost)"
    echo "EBS Cost: \$$(printf "%.2f" $ebs_cost)" 
    echo "RDS Cost: \$$(printf "%.2f" $rds_cost)"
    echo "EIP Cost: \$$(printf "%.2f" $eip_cost)"
    echo "Data Transfer (estimated): \$$(printf "%.2f" $data_transfer_estimate)"
    echo "Total Monthly Cost: \$$(printf "%.2f" $total_with_transfer)"
} > "$report_file"

echo -e "\n${GREEN}📄 Detailed report saved to: $report_file${NC}"
