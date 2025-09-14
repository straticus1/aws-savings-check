#!/bin/bash

# AWS Services Library
# Provides unified interface for analyzing various AWS services

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Service analysis functions
analyze_lambda_functions() {
    log_info "Analyzing Lambda functions..."
    start_timer "lambda_analysis"

    local functions_data=$(aws lambda list-functions \
        --query 'Functions[*].[FunctionName,Runtime,MemorySize,LastModified,CodeSize]' \
        --output text 2>/dev/null)

    local lambda_cost=0
    local lambda_count=0
    local json_lambda_functions="[]"

    if [ -n "$functions_data" ]; then
        while IFS=$'\t' read -r function_name runtime memory_size last_modified code_size; do
            if [ -n "$function_name" ] && [ "$function_name" != "None" ]; then
                # Estimate Lambda costs (very rough - based on memory and potential usage)
                local monthly_estimate=$(echo "scale=2; ($memory_size / 1024) * 0.0000166667 * 1000000" | bc -l)

                log_debug "Found Lambda function: $function_name ($runtime, ${memory_size}MB)"
                lambda_cost=$(echo "$lambda_cost + $monthly_estimate" | bc -l)
                ((lambda_count++))

                # Add to JSON if requested
                if [ "$CREATE_JSON" = "true" ]; then
                    local func_json="{\"function_name\":\"$function_name\",\"runtime\":\"$runtime\",\"memory_mb\":$memory_size,\"code_size_bytes\":$code_size,\"estimated_monthly_cost\":$(printf "%.2f" $monthly_estimate)}"
                    if [ "$json_lambda_functions" = "[]" ]; then
                        json_lambda_functions="[$func_json]"
                    else
                        json_lambda_functions="${json_lambda_functions%]*},$func_json]"
                    fi
                fi
            fi
        done <<< "$functions_data"
    fi

    log_cost_analysis "Lambda" "$lambda_count" "$lambda_cost"
    end_timer "lambda_analysis"

    echo "$lambda_cost:$lambda_count:$json_lambda_functions"
}

analyze_s3_buckets() {
    log_info "Analyzing S3 buckets..."
    start_timer "s3_analysis"

    local buckets_data=$(aws s3api list-buckets \
        --query 'Buckets[*].[Name,CreationDate]' \
        --output text 2>/dev/null)

    local s3_cost=0
    local s3_count=0
    local json_s3_buckets="[]"

    if [ -n "$buckets_data" ]; then
        while IFS=$'\t' read -r bucket_name creation_date; do
            if [ -n "$bucket_name" ] && [ "$bucket_name" != "None" ]; then
                # Get bucket size (this is expensive, so we'll estimate)
                local bucket_size_gb=1  # Default estimate
                local storage_cost=$(echo "$bucket_size_gb * 0.023" | bc -l)  # Standard storage pricing

                log_debug "Found S3 bucket: $bucket_name"
                s3_cost=$(echo "$s3_cost + $storage_cost" | bc -l)
                ((s3_count++))

                # Add to JSON if requested
                if [ "$CREATE_JSON" = "true" ]; then
                    local bucket_json="{\"bucket_name\":\"$bucket_name\",\"creation_date\":\"$creation_date\",\"estimated_size_gb\":$bucket_size_gb,\"estimated_monthly_cost\":$(printf "%.2f" $storage_cost)}"
                    if [ "$json_s3_buckets" = "[]" ]; then
                        json_s3_buckets="[$bucket_json]"
                    else
                        json_s3_buckets="${json_s3_buckets%]*},$bucket_json]"
                    fi
                fi
            fi
        done <<< "$buckets_data"
    fi

    log_cost_analysis "S3" "$s3_count" "$s3_cost"
    end_timer "s3_analysis"

    echo "$s3_cost:$s3_count:$json_s3_buckets"
}

analyze_cloudwatch_logs() {
    log_info "Analyzing CloudWatch Log Groups..."
    start_timer "cloudwatch_analysis"

    local log_groups_data=$(aws logs describe-log-groups \
        --query 'logGroups[*].[logGroupName,creationTime,storedBytes]' \
        --output text 2>/dev/null)

    local logs_cost=0
    local logs_count=0
    local json_log_groups="[]"

    if [ -n "$log_groups_data" ]; then
        while IFS=$'\t' read -r log_group_name creation_time stored_bytes; do
            if [ -n "$log_group_name" ] && [ "$log_group_name" != "None" ]; then
                # Convert bytes to GB and calculate storage cost
                local stored_gb=$(echo "scale=4; $stored_bytes / 1024 / 1024 / 1024" | bc -l)
                local storage_cost=$(echo "$stored_gb * 0.50" | bc -l)  # CloudWatch Logs pricing

                log_debug "Found log group: $log_group_name ($(printf "%.2f" $stored_gb)GB)"
                logs_cost=$(echo "$logs_cost + $storage_cost" | bc -l)
                ((logs_count++))

                # Add to JSON if requested
                if [ "$CREATE_JSON" = "true" ]; then
                    local log_json="{\"log_group_name\":\"$log_group_name\",\"creation_time\":$creation_time,\"stored_gb\":$(printf "%.2f" $stored_gb),\"monthly_cost\":$(printf "%.2f" $storage_cost)}"
                    if [ "$json_log_groups" = "[]" ]; then
                        json_log_groups="[$log_json]"
                    else
                        json_log_groups="${json_log_groups%]*},$log_json]"
                    fi
                fi
            fi
        done <<< "$log_groups_data"
    fi

    log_cost_analysis "CloudWatch Logs" "$logs_count" "$logs_cost"
    end_timer "cloudwatch_analysis"

    echo "$logs_cost:$logs_count:$json_log_groups"
}

analyze_load_balancers() {
    log_info "Analyzing Load Balancers..."
    start_timer "load_balancer_analysis"

    # Application Load Balancers
    local alb_data=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[?Type==`application`].[LoadBalancerName,LoadBalancerArn,CreatedTime,State.Code]' \
        --output text 2>/dev/null)

    # Classic Load Balancers
    local clb_data=$(aws elb describe-load-balancers \
        --query 'LoadBalancerDescriptions[*].[LoadBalancerName,CreatedTime]' \
        --output text 2>/dev/null)

    local lb_cost=0
    local lb_count=0
    local json_load_balancers="[]"

    # Process ALBs
    if [ -n "$alb_data" ]; then
        while IFS=$'\t' read -r lb_name lb_arn created_time state; do
            if [ -n "$lb_name" ] && [ "$lb_name" != "None" ]; then
                local monthly_cost=22.27  # Standard ALB pricing
                log_debug "Found Application Load Balancer: $lb_name"
                lb_cost=$(echo "$lb_cost + $monthly_cost" | bc -l)
                ((lb_count++))

                if [ "$CREATE_JSON" = "true" ]; then
                    local lb_json="{\"name\":\"$lb_name\",\"type\":\"application\",\"state\":\"$state\",\"monthly_cost\":$monthly_cost}"
                    if [ "$json_load_balancers" = "[]" ]; then
                        json_load_balancers="[$lb_json]"
                    else
                        json_load_balancers="${json_load_balancers%]*},$lb_json]"
                    fi
                fi
            fi
        done <<< "$alb_data"
    fi

    # Process Classic LBs
    if [ -n "$clb_data" ]; then
        while IFS=$'\t' read -r lb_name created_time; do
            if [ -n "$lb_name" ] && [ "$lb_name" != "None" ]; then
                local monthly_cost=20.44  # Classic LB pricing
                log_debug "Found Classic Load Balancer: $lb_name"
                lb_cost=$(echo "$lb_cost + $monthly_cost" | bc -l)
                ((lb_count++))

                if [ "$CREATE_JSON" = "true" ]; then
                    local lb_json="{\"name\":\"$lb_name\",\"type\":\"classic\",\"state\":\"active\",\"monthly_cost\":$monthly_cost}"
                    if [ "$json_load_balancers" = "[]" ]; then
                        json_load_balancers="[$lb_json]"
                    else
                        json_load_balancers="${json_load_balancers%]*},$lb_json]"
                    fi
                fi
            fi
        done <<< "$clb_data"
    fi

    log_cost_analysis "Load Balancers" "$lb_count" "$lb_cost"
    end_timer "load_balancer_analysis"

    echo "$lb_cost:$lb_count:$json_load_balancers"
}

analyze_nat_gateways() {
    log_info "Analyzing NAT Gateways..."
    start_timer "nat_gateway_analysis"

    local nat_data=$(aws ec2 describe-nat-gateways \
        --query 'NatGateways[?State==`available`].[NatGatewayId,SubnetId,State,CreateTime]' \
        --output text 2>/dev/null)

    local nat_cost=0
    local nat_count=0
    local json_nat_gateways="[]"

    if [ -n "$nat_data" ]; then
        while IFS=$'\t' read -r nat_id subnet_id state create_time; do
            if [ -n "$nat_id" ] && [ "$nat_id" != "None" ]; then
                local monthly_cost=32.85  # NAT Gateway pricing (hours) + data processing
                log_debug "Found NAT Gateway: $nat_id in $subnet_id"
                nat_cost=$(echo "$nat_cost + $monthly_cost" | bc -l)
                ((nat_count++))

                if [ "$CREATE_JSON" = "true" ]; then
                    local nat_json="{\"nat_gateway_id\":\"$nat_id\",\"subnet_id\":\"$subnet_id\",\"state\":\"$state\",\"monthly_cost\":$monthly_cost}"
                    if [ "$json_nat_gateways" = "[]" ]; then
                        json_nat_gateways="[$nat_json]"
                    else
                        json_nat_gateways="${json_nat_gateways%]*},$nat_json]"
                    fi
                fi
            fi
        done <<< "$nat_data"
    fi

    log_cost_analysis "NAT Gateways" "$nat_count" "$nat_cost"
    end_timer "nat_gateway_analysis"

    echo "$nat_cost:$nat_count:$json_nat_gateways"
}

# Helper function to check if a service is enabled
is_service_enabled() {
    local service="$1"
    local config_var="ENABLE_${service^^}_ANALYSIS"
    local enabled="${!config_var:-true}"
    [ "$enabled" = "true" ]
}