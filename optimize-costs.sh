#!/bin/bash

# AWS Cost Optimization Script
# Provides safe cost optimization actions
# Author: Generated for AWS Cost Optimization
# Date: $(date)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AWS Cost Optimization Tool ===${NC}"
echo -e "${BLUE}Region: $(aws configure get region || echo 'default')${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Function to safely release unattached Elastic IPs
release_unattached_eips() {
    echo -e "${YELLOW}🌐 Checking for unattached Elastic IPs...${NC}"
    
    unattached_eips=$(aws ec2 describe-addresses \
        --query 'Addresses[?!InstanceId].[PublicIp,AllocationId]' \
        --output text)
    
    if [ -n "$unattached_eips" ]; then
        echo "Found unattached Elastic IPs:"
        while IFS=$'\t' read -r public_ip allocation_id; do
            if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
                echo -e "  ${RED}•${NC} $public_ip (Allocation: $allocation_id) - Costing \$3.65/month"
                
                read -p "Release this Elastic IP? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "  ${GREEN}Releasing${NC} $public_ip..."
                    if aws ec2 release-address --allocation-id "$allocation_id"; then
                        echo -e "  ${GREEN}✓ Successfully released${NC} $public_ip"
                        echo -e "  ${GREEN}💰 Monthly savings: \$3.65${NC}"
                    else
                        echo -e "  ${RED}✗ Failed to release${NC} $public_ip"
                    fi
                else
                    echo -e "  ${YELLOW}Skipped${NC} $public_ip"
                fi
            fi
        done <<< "$unattached_eips"
    else
        echo -e "  ${GREEN}✓ No unattached Elastic IPs found${NC}"
    fi
}

# Function to analyze and suggest EC2 consolidation
analyze_ec2_consolidation() {
    echo -e "\n${YELLOW}📊 Analyzing EC2 Instance Consolidation Opportunities...${NC}"
    
    running_instances=$(aws ec2 describe-instances \
        --filters Name=instance-state-name,Values=running \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0],CpuOptions.CoreCount,State.Name]' \
        --output text)
    
    if [ -n "$running_instances" ]; then
        instance_count=0
        echo "Running EC2 Instances:"
        
        while IFS=$'\t' read -r instance_id instance_type launch_time name core_count state; do
            if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
                # Calculate days running
                launch_date=$(date -d "$launch_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${launch_time%+*}" +%s 2>/dev/null || echo "0")
                current_date=$(date +%s)
                days_running=$(( (current_date - launch_date) / 86400 ))
                
                echo -e "  ${BLUE}•${NC} $instance_id ($instance_type) - ${name:-'Unnamed'} - ${days_running} days old"
                ((instance_count++))
            fi
        done <<< "$running_instances"
        
        if (( instance_count > 2 )); then
            echo -e "\n${YELLOW}💡 Consolidation Suggestion:${NC}"
            echo -e "  You have $instance_count running instances. Consider:"
            echo -e "  • Consolidating workloads onto fewer, larger instances"
            echo -e "  • Using Application Load Balancer for high availability"
            echo -e "  • Implementing auto-scaling groups for dynamic workloads"
            echo -e "  ${RED}⚠️  Always test consolidation in a staging environment first${NC}"
        else
            echo -e "  ${GREEN}✓ Instance count looks reasonable${NC}"
        fi
    else
        echo -e "  ${GREEN}✓ No running EC2 instances found${NC}"
    fi
}

# Function to analyze RDS right-sizing opportunities
analyze_rds_optimization() {
    echo -e "\n${YELLOW}🗄️  Analyzing RDS Optimization Opportunities...${NC}"
    
    rds_instances=$(aws rds describe-db-instances \
        --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus,AllocatedStorage,MultiAZ]' \
        --output text)
    
    if [ -n "$rds_instances" ]; then
        echo "RDS Instances:"
        while IFS=$'\t' read -r db_id db_class engine status storage multi_az; do
            if [ -n "$db_id" ] && [ "$db_id" != "None" ]; then
                echo -e "  ${BLUE}•${NC} $db_id ($db_class, $engine) - ${storage}GB storage"
                echo -e "    └─ Multi-AZ: ${multi_az}"
                
                # Suggest downsizing for medium instances
                if [[ "$db_class" == *"medium"* ]]; then
                    smaller_class="${db_class/medium/micro}"
                    echo -e "  ${YELLOW}💡 Consider downsizing to $smaller_class if load is light${NC}"
                    echo -e "    └─ Potential savings: ~\$35-40/month"
                fi
                
                # Suggest disabling Multi-AZ for non-production
                if [ "$multi_az" == "true" ]; then
                    echo -e "  ${YELLOW}💡 Consider disabling Multi-AZ for development/staging${NC}"
                    echo -e "    └─ Potential savings: ~50% of instance cost"
                fi
            fi
        done <<< "$rds_instances"
    else
        echo -e "  ${GREEN}✓ No RDS instances found${NC}"
    fi
}

# Function to analyze EBS volume optimization
analyze_ebs_optimization() {
    echo -e "\n${YELLOW}💾 Analyzing EBS Volume Optimization...${NC}"
    
    volumes=$(aws ec2 describe-volumes \
        --filters Name=status,Values=in-use \
        --query 'Volumes[*].[VolumeId,Size,VolumeType,Iops,Throughput]' \
        --output text)
    
    if [ -n "$volumes" ]; then
        echo "EBS Volumes:"
        total_oversized=0
        while IFS=$'\t' read -r volume_id size volume_type iops throughput; do
            if [ -n "$volume_id" ] && [ "$volume_id" != "None" ]; then
                echo -e "  ${BLUE}•${NC} $volume_id (${size}GB $volume_type)"
                
                # Suggest optimization for large volumes
                if (( size > 50 )); then
                    echo -e "    ${YELLOW}💡 Large volume detected${NC}"
                    echo -e "    └─ Consider if full capacity is needed"
                    ((total_oversized++))
                fi
                
                # Suggest GP3 migration for GP2 volumes
                if [ "$volume_type" == "gp2" ]; then
                    echo -e "    ${YELLOW}💡 Consider migrating to gp3 for cost savings${NC}"
                    echo -e "    └─ GP3 offers better price/performance ratio"
                fi
            fi
        done <<< "$volumes"
        
        if (( total_oversized > 0 )); then
            echo -e "\n${YELLOW}💡 EBS Optimization Summary:${NC}"
            echo -e "  • $total_oversized volumes may be over-provisioned"
            echo -e "  • Consider using EBS snapshots before resizing"
            echo -e "  • Monitor actual usage with CloudWatch metrics"
        fi
    else
        echo -e "  ${GREEN}✓ No EBS volumes found${NC}"
    fi
}

# Function to show cost monitoring setup
setup_cost_monitoring() {
    echo -e "\n${YELLOW}📈 Cost Monitoring Recommendations:${NC}"
    echo -e "  ${BLUE}1. AWS Budgets:${NC}"
    echo -e "     • Set up monthly spending alerts"
    echo -e "     • Create budget for each service"
    echo -e "     • Configure email notifications"
    
    echo -e "\n  ${BLUE}2. Cost Explorer:${NC}"
    echo -e "     • Review monthly cost trends"
    echo -e "     • Analyze cost by service"
    echo -e "     • Identify usage patterns"
    
    echo -e "\n  ${BLUE}3. CloudWatch Billing Alerts:${NC}"
    echo -e "     • Enable billing alerts in preferences"
    echo -e "     • Set threshold-based notifications"
    echo -e "     • Monitor unusual spending spikes"
    
    echo -e "\n  ${BLUE}4. AWS Cost Anomaly Detection:${NC}"
    echo -e "     • Automatically detect unusual costs"
    echo -e "     • Machine learning-based alerts"
    echo -e "     • Proactive cost management"
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}=== Cost Optimization Options ===${NC}"
    echo "1. Release unattached Elastic IPs"
    echo "2. Analyze EC2 consolidation opportunities"
    echo "3. Analyze RDS optimization opportunities"
    echo "4. Analyze EBS volume optimization"
    echo "5. Show cost monitoring recommendations"
    echo "6. Run all analyses"
    echo "7. Exit"
    echo ""
}

# Main execution
while true; do
    show_menu
    read -p "Select an option (1-7): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            release_unattached_eips
            ;;
        2)
            analyze_ec2_consolidation
            ;;
        3)
            analyze_rds_optimization
            ;;
        4)
            analyze_ebs_optimization
            ;;
        5)
            setup_cost_monitoring
            ;;
        6)
            release_unattached_eips
            analyze_ec2_consolidation
            analyze_rds_optimization
            analyze_ebs_optimization
            setup_cost_monitoring
            ;;
        7)
            echo -e "${GREEN}Thanks for using AWS Cost Optimization Tool!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-7.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
