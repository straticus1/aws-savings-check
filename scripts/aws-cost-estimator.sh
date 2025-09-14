#!/bin/bash

# AWS Monthly Cost Estimator
# Analyzes running AWS services and estimates monthly costs
# Author: Generated for NiteText AWS Cost Analysis
# Version: 2.0.0
# Date: $(date)

set -e

# Get script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"

# Source library functions
source "$ROOT_DIR/lib/config.sh" 2>/dev/null || echo "Config library not found"
source "$ROOT_DIR/lib/logging.sh" 2>/dev/null || echo "Logging library not found"
source "$ROOT_DIR/lib/aws-services.sh" 2>/dev/null || echo "AWS services library not found"

# Default options
CREATE_JSON=false
OUTPUT_FILE=""

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --createjson         Generate JSON output in addition to text output"
    echo "  --outjson FILE       Specify JSON output file (implies --createjson)"
    echo "  -h, --help          Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --createjson)
            CREATE_JSON=true
            shift
            ;;
        --outjson)
            CREATE_JSON=true
            OUTPUT_FILE="$2"
            shift 2
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

# Load configuration
load_config

# Initialize logging
setup_logging

log_info "AWS Cost Estimator v2.0.0 starting..."
start_timer "total_analysis"

# Check dependencies
log_info "Checking dependencies..."

if ! command -v aws &> /dev/null; then
    log_error_with_context "AWS CLI is not installed" "dependency_check"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    log_error_with_context "bc calculator is not installed. Please install it first." "dependency_check"
    exit 1
fi

if ! command -v jq &> /dev/null && [ "$CREATE_JSON" = true ]; then
    log_error_with_context "jq is required for JSON output but not installed" "dependency_check"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    log_error_with_context "AWS CLI is not configured or credentials are invalid" "aws_auth"
    exit 1
fi

log_success "All dependencies verified"

total_cost=0

# Initialize JSON data structure
json_data="{"
json_ec2_instances="[]"
json_ebs_volumes="[]"
json_rds_instances="[]"
json_elastic_ips="[]"

# Cross-platform date parsing function
parse_date() {
    local date_string="$1"
    # Try GNU date first (Linux)
    if date -d "$date_string" +%s 2>/dev/null; then
        return
    fi
    # Try BSD date (macOS)
    if date -j -f "%Y-%m-%dT%H:%M:%S" "${date_string%+*}" +%s 2>/dev/null; then
        return
    fi
    # Fallback
    echo "0"
}

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
            instance_cost=$(get_ec2_price_from_config "$instance_type")
            if [ "$instance_cost" == "0" ]; then
                echo -e "  ${RED}⚠️  Unknown pricing for $instance_type${NC}"
                instance_cost="50.00"  # Default estimate
            fi

            # Calculate days running using improved date parsing
            launch_date=$(parse_date "$launch_time")
            current_date=$(date +%s)
            days_running=$(( (current_date - launch_date) / 86400 ))

            echo -e "  ${GREEN}✓${NC} $instance_id ($instance_type) - ${name:-'Unnamed'} - \$${instance_cost}/month (${days_running} days old)"
            ec2_cost=$(echo "$ec2_cost + $instance_cost" | bc -l)
            ((ec2_count++))

            # Add to JSON data if requested
            if [ "$CREATE_JSON" = true ]; then
                instance_json="{\"instance_id\":\"$instance_id\",\"instance_type\":\"$instance_type\",\"name\":\"${name:-'Unnamed'}\",\"monthly_cost\":$instance_cost,\"days_running\":$days_running,\"launch_time\":\"$launch_time\"}"
                if [ "$json_ec2_instances" = "[]" ]; then
                    json_ec2_instances="[$instance_json]"
                else
                    json_ec2_instances="${json_ec2_instances%]*},$instance_json]"
                fi
            fi
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

            # Add to JSON data if requested
            if [ "$CREATE_JSON" = true ]; then
                volume_json="{\"volume_id\":\"$volume_id\",\"size_gb\":$size,\"volume_type\":\"$volume_type\",\"instance_id\":\"${instance_id:-null}\",\"monthly_cost\":$(printf "%.2f" $volume_cost)}"
                if [ "$json_ebs_volumes" = "[]" ]; then
                    json_ebs_volumes="[$volume_json]"
                else
                    json_ebs_volumes="${json_ebs_volumes%]*},$volume_json]"
                fi
            fi
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
            db_instance_cost=$(get_rds_price_from_config "$db_class")
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

            # Add to JSON data if requested
            if [ "$CREATE_JSON" = true ]; then
                rds_json="{\"db_identifier\":\"$db_id\",\"db_class\":\"$db_class\",\"engine\":\"$engine\",\"status\":\"$status\",\"storage_gb\":$storage,\"instance_cost\":$(printf "%.2f" $db_instance_cost),\"storage_cost\":$(printf "%.2f" $storage_cost),\"total_monthly_cost\":$(printf "%.2f" $total_db_cost)}"
                if [ "$json_rds_instances" = "[]" ]; then
                    json_rds_instances="[$rds_json]"
                else
                    json_rds_instances="${json_rds_instances%]*},$rds_json]"
                fi
            fi
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
                current_eip_cost="$ELASTIC_IP_PRICE"
                attached_status="false"
            else
                echo -e "  ${GREEN}✓${NC} $public_ip → $instance_id - \$0.00/month (attached)"
                current_eip_cost="0.00"
                attached_status="true"
            fi
            ((eip_count++))

            # Add to JSON data if requested
            if [ "$CREATE_JSON" = true ]; then
                eip_json="{\"public_ip\":\"$public_ip\",\"instance_id\":\"${instance_id:-null}\",\"attached\":$attached_status,\"monthly_cost\":$current_eip_cost}"
                if [ "$json_elastic_ips" = "[]" ]; then
                    json_elastic_ips="[$eip_json]"
                else
                    json_elastic_ips="${json_elastic_ips%]*},$eip_json]"
                fi
            fi
        fi
    done <<< "$eip_data"
else
    echo "  No Elastic IPs found"
fi

# Extended AWS Service Analysis
additional_services_cost=0
json_additional_services="{}"

# Lambda Functions
if is_service_enabled "lambda"; then
    echo -e "\n${YELLOW}⚡ Analyzing Lambda Functions...${NC}"
    lambda_result=$(analyze_lambda_functions)
    lambda_cost=$(echo "$lambda_result" | cut -d: -f1)
    lambda_count=$(echo "$lambda_result" | cut -d: -f2)
    json_lambda=$(echo "$lambda_result" | cut -d: -f3-)

    if [ "$lambda_count" -gt 0 ]; then
        echo -e "  Found $lambda_count Lambda functions - \$$(printf "%.2f" $lambda_cost)/month (estimated)"
    else
        echo -e "  ${GREEN}✓ No Lambda functions found${NC}"
    fi
    additional_services_cost=$(echo "$additional_services_cost + $lambda_cost" | bc -l)
fi

# S3 Buckets
if is_service_enabled "s3"; then
    echo -e "\n${YELLOW}🪣 Analyzing S3 Buckets...${NC}"
    s3_result=$(analyze_s3_buckets)
    s3_cost=$(echo "$s3_result" | cut -d: -f1)
    s3_count=$(echo "$s3_result" | cut -d: -f2)
    json_s3=$(echo "$s3_result" | cut -d: -f3-)

    if [ "$s3_count" -gt 0 ]; then
        echo -e "  Found $s3_count S3 buckets - \$$(printf "%.2f" $s3_cost)/month (estimated)"
    else
        echo -e "  ${GREEN}✓ No S3 buckets found${NC}"
    fi
    additional_services_cost=$(echo "$additional_services_cost + $s3_cost" | bc -l)
fi

# CloudWatch Logs
if is_service_enabled "cloudwatch"; then
    echo -e "\n${YELLOW}📊 Analyzing CloudWatch Logs...${NC}"
    logs_result=$(analyze_cloudwatch_logs)
    logs_cost=$(echo "$logs_result" | cut -d: -f1)
    logs_count=$(echo "$logs_result" | cut -d: -f2)
    json_logs=$(echo "$logs_result" | cut -d: -f3-)

    if [ "$logs_count" -gt 0 ]; then
        echo -e "  Found $logs_count log groups - \$$(printf "%.2f" $logs_cost)/month"
    else
        echo -e "  ${GREEN}✓ No CloudWatch log groups found${NC}"
    fi
    additional_services_cost=$(echo "$additional_services_cost + $logs_cost" | bc -l)
fi

# Load Balancers
echo -e "\n${YELLOW}⚖️  Analyzing Load Balancers...${NC}"
lb_result=$(analyze_load_balancers)
lb_cost=$(echo "$lb_result" | cut -d: -f1)
lb_count=$(echo "$lb_result" | cut -d: -f2)
json_lb=$(echo "$lb_result" | cut -d: -f3-)

if [ "$lb_count" -gt 0 ]; then
    echo -e "  Found $lb_count load balancers - \$$(printf "%.2f" $lb_cost)/month"
else
    echo -e "  ${GREEN}✓ No load balancers found${NC}"
fi
additional_services_cost=$(echo "$additional_services_cost + $lb_cost" | bc -l)

# NAT Gateways
echo -e "\n${YELLOW}🌐 Analyzing NAT Gateways...${NC}"
nat_result=$(analyze_nat_gateways)
nat_cost=$(echo "$nat_result" | cut -d: -f1)
nat_count=$(echo "$nat_result" | cut -d: -f2)
json_nat=$(echo "$nat_result" | cut -d: -f3-)

if [ "$nat_count" -gt 0 ]; then
    echo -e "  Found $nat_count NAT gateways - \$$(printf "%.2f" $nat_cost)/month"
else
    echo -e "  ${GREEN}✓ No NAT gateways found${NC}"
fi
additional_services_cost=$(echo "$additional_services_cost + $nat_cost" | bc -l)

# Calculate totals
core_services_cost=$(echo "$ec2_cost + $ebs_cost + $rds_cost + $eip_cost" | bc -l)
data_transfer_estimate="${DATA_TRANSFER_ESTIMATE:-10.00}"
total_with_all_services=$(echo "$core_services_cost + $additional_services_cost + $data_transfer_estimate" | bc -l)

echo -e "\n${BLUE}=== COMPREHENSIVE COST SUMMARY ===${NC}"
echo -e "${CYAN}Core Services:${NC}"
echo -e "  EC2 Instances ($ec2_count):    \$$(printf "%8.2f" $ec2_cost)"
echo -e "  EBS Storage ($ebs_count):      \$$(printf "%8.2f" $ebs_cost)"
echo -e "  RDS Database ($rds_count):     \$$(printf "%8.2f" $rds_cost)"
echo -e "  Elastic IPs ($eip_count):      \$$(printf "%8.2f" $eip_cost)"

if [ $(echo "$additional_services_cost > 0" | bc -l) -eq 1 ]; then
    echo -e "${CYAN}Additional Services:${NC}"
    [ "${lambda_cost:-0}" != "0" ] && echo -e "  Lambda Functions ($lambda_count):  \$$(printf "%8.2f" ${lambda_cost:-0})"
    [ "${s3_cost:-0}" != "0" ] && echo -e "  S3 Buckets ($s3_count):       \$$(printf "%8.2f" ${s3_cost:-0})"
    [ "${logs_cost:-0}" != "0" ] && echo -e "  CloudWatch Logs ($logs_count):  \$$(printf "%8.2f" ${logs_cost:-0})"
    [ "${lb_cost:-0}" != "0" ] && echo -e "  Load Balancers ($lb_count):    \$$(printf "%8.2f" ${lb_cost:-0})"
    [ "${nat_cost:-0}" != "0" ] && echo -e "  NAT Gateways ($nat_count):     \$$(printf "%8.2f" ${nat_cost:-0})"
fi

echo -e "${CYAN}Other Costs:${NC}"
echo -e "  Data Transfer (est):   \$$(printf "%8.2f" $data_transfer_estimate)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}TOTAL MONTHLY COST:    \$$(printf "%8.2f" $total_with_all_services)${NC}"

# Performance summary
end_timer "total_analysis"
log_success "Cost analysis completed successfully"

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

# Generate JSON output if requested
if [ "$CREATE_JSON" = true ]; then
    current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    aws_region=$(aws configure get region || echo 'default')

    # Set output file
    if [ -n "$OUTPUT_FILE" ]; then
        json_file="$OUTPUT_FILE"
    else
        json_file="aws-cost-report-$(date +%Y%m%d-%H%M%S).json"
    fi

    # Build complete JSON structure
    cat > "$json_file" << EOF
{
  "report_metadata": {
    "generated_at": "$current_date",
    "aws_region": "$aws_region",
    "report_type": "monthly_cost_estimate"
  },
  "cost_summary": {
    "core_services": {
      "ec2_cost": $(printf "%.2f" $ec2_cost),
      "ebs_cost": $(printf "%.2f" $ebs_cost),
      "rds_cost": $(printf "%.2f" $rds_cost),
      "elastic_ip_cost": $(printf "%.2f" $eip_cost)
    },
    "additional_services": {
      "lambda_cost": $(printf "%.2f" ${lambda_cost:-0}),
      "s3_cost": $(printf "%.2f" ${s3_cost:-0}),
      "cloudwatch_logs_cost": $(printf "%.2f" ${logs_cost:-0}),
      "load_balancer_cost": $(printf "%.2f" ${lb_cost:-0}),
      "nat_gateway_cost": $(printf "%.2f" ${nat_cost:-0})
    },
    "data_transfer_estimate": $(printf "%.2f" $data_transfer_estimate),
    "total_monthly_cost": $(printf "%.2f" $total_with_all_services)
  },
  "resource_counts": {
    "ec2_instances": $ec2_count,
    "ebs_volumes": $ebs_count,
    "rds_instances": $rds_count,
    "elastic_ips": $eip_count,
    "lambda_functions": ${lambda_count:-0},
    "s3_buckets": ${s3_count:-0},
    "cloudwatch_log_groups": ${logs_count:-0},
    "load_balancers": ${lb_count:-0},
    "nat_gateways": ${nat_count:-0}
  },
  "resources": {
    "ec2_instances": $json_ec2_instances,
    "ebs_volumes": $json_ebs_volumes,
    "rds_instances": $json_rds_instances,
    "elastic_ips": $json_elastic_ips,
    "lambda_functions": ${json_lambda:-[]},
    "s3_buckets": ${json_s3:-[]},
    "cloudwatch_log_groups": ${json_logs:-[]},
    "load_balancers": ${json_lb:-[]},
    "nat_gateways": ${json_nat:-[]}
  },
  "optimization_suggestions": [
$(if (( $(echo "$eip_cost > 0" | bc -l) )); then echo "    \"Release unattached Elastic IPs to save \$$(printf "%.2f" $eip_cost)/month\","; fi)
$(if (( ec2_count > 2 )); then echo "    \"Consider consolidating EC2 instances if possible\","; fi)
$(if (( $(echo "$rds_cost > 60" | bc -l) )); then echo "    \"Consider downgrading RDS instance class if database load is light\","; fi)
    "Monitor AWS Cost Explorer for detailed usage patterns",
    "Set up AWS Budgets and billing alerts"
  ]
}
EOF

    # Clean up trailing commas in the suggestions array
    sed -i.bak 's/,$//' "$json_file" && rm -f "${json_file}.bak" 2>/dev/null || true

    echo -e "${GREEN}📊 JSON report saved to: $json_file${NC}"
fi
