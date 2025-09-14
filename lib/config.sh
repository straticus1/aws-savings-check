#!/bin/bash

# Configuration Management for AWS Cost Estimator
# Handles loading and validation of configuration files

# Default configuration file locations
DEFAULT_CONFIG_FILE="config/aws-cost-estimator.conf"
USER_CONFIG_FILE="$HOME/.aws-cost-estimator.conf"
LOCAL_CONFIG_FILE=".aws-cost-estimator.conf"

# Configuration loading
load_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"

    # Try multiple config file locations in order of preference
    local config_files=(
        "$LOCAL_CONFIG_FILE"
        "$USER_CONFIG_FILE"
        "$config_file"
    )

    local loaded_config=false

    for conf_file in "${config_files[@]}"; do
        if [ -f "$conf_file" ]; then
            log_debug "Loading configuration from: $conf_file"

            # Source the configuration file safely
            while IFS='=' read -r key value; do
                # Skip comments and empty lines
                [[ $key =~ ^[[:space:]]*# ]] && continue
                [[ -z "$key" ]] && continue

                # Remove leading/trailing whitespace
                key=$(echo "$key" | xargs)
                value=$(echo "$value" | xargs)

                # Export the variable
                if [ -n "$key" ] && [ -n "$value" ]; then
                    export "$key"="$value"
                fi
            done < "$conf_file"

            loaded_config=true
            log_info "Configuration loaded from: $conf_file"
            break
        fi
    done

    if [ "$loaded_config" = false ]; then
        log_warn "No configuration file found, using defaults"
        set_default_config
    fi

    validate_config
}

# Set default configuration values
set_default_config() {
    # Pricing defaults (US-East-1)
    export PRICING_REGION="${PRICING_REGION:-us-east-1}"
    export EC2_T3_MICRO_PRICE="${EC2_T3_MICRO_PRICE:-8.35}"
    export EC2_T3_MEDIUM_PRICE="${EC2_T3_MEDIUM_PRICE:-30.37}"
    export RDS_T3_MICRO_PRICE="${RDS_T3_MICRO_PRICE:-16.79}"
    export RDS_T3_MEDIUM_PRICE="${RDS_T3_MEDIUM_PRICE:-67.16}"
    export EBS_GP3_PRICE="${EBS_GP3_PRICE:-0.096}"
    export RDS_STORAGE_PRICE="${RDS_STORAGE_PRICE:-0.115}"
    export ELASTIC_IP_PRICE="${ELASTIC_IP_PRICE:-3.65}"
    export DATA_TRANSFER_ESTIMATE="${DATA_TRANSFER_ESTIMATE:-10.00}"

    # Analysis defaults
    export WASTE_THRESHOLD_DAYS="${WASTE_THRESHOLD_DAYS:-7}"
    export RDS_WASTE_THRESHOLD_DAYS="${RDS_WASTE_THRESHOLD_DAYS:-14}"
    export COST_OPTIMIZATION_THRESHOLD="${COST_OPTIMIZATION_THRESHOLD:-200.00}"

    # Reporting defaults
    export ENABLE_JSON_OUTPUT="${ENABLE_JSON_OUTPUT:-true}"
    export REPORT_DIRECTORY="${REPORT_DIRECTORY:-reports}"
    export ARCHIVE_OLD_REPORTS="${ARCHIVE_OLD_REPORTS:-true}"
    export ARCHIVE_AFTER_DAYS="${ARCHIVE_AFTER_DAYS:-30}"

    # Logging defaults
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export LOG_FILE="${LOG_FILE:-logs/aws-cost-estimator.log}"
    export ENABLE_AUDIT_LOG="${ENABLE_AUDIT_LOG:-true}"

    # Security defaults
    export REQUIRE_CONFIRMATION="${REQUIRE_CONFIRMATION:-true}"
    export ALLOW_DESTRUCTIVE_OPERATIONS="${ALLOW_DESTRUCTIVE_OPERATIONS:-false}"
    export MAX_COST_THRESHOLD="${MAX_COST_THRESHOLD:-1000.00}"

    # Feature flags
    export ENABLE_LAMBDA_ANALYSIS="${ENABLE_LAMBDA_ANALYSIS:-true}"
    export ENABLE_S3_ANALYSIS="${ENABLE_S3_ANALYSIS:-true}"
    export ENABLE_CLOUDWATCH_ANALYSIS="${ENABLE_CLOUDWATCH_ANALYSIS:-true}"
    export ENABLE_ROUTE53_ANALYSIS="${ENABLE_ROUTE53_ANALYSIS:-true}"

    # log_debug "Default configuration values set" - logging not available yet
}

# Validate configuration values
validate_config() {
    local validation_errors=0

    # Validate numeric values
    local numeric_configs=(
        "EC2_T3_MICRO_PRICE"
        "EC2_T3_MEDIUM_PRICE"
        "RDS_T3_MICRO_PRICE"
        "RDS_T3_MEDIUM_PRICE"
        "EBS_GP3_PRICE"
        "RDS_STORAGE_PRICE"
        "ELASTIC_IP_PRICE"
        "DATA_TRANSFER_ESTIMATE"
        "WASTE_THRESHOLD_DAYS"
        "RDS_WASTE_THRESHOLD_DAYS"
        "COST_OPTIMIZATION_THRESHOLD"
        "ARCHIVE_AFTER_DAYS"
        "MAX_COST_THRESHOLD"
    )

    for config in "${numeric_configs[@]}"; do
        local value="${!config}"
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            echo "Error: Invalid numeric value for $config: $value" >&2
            ((validation_errors++))
        fi
    done

    # Validate boolean values
    local boolean_configs=(
        "ENABLE_JSON_OUTPUT"
        "ARCHIVE_OLD_REPORTS"
        "ENABLE_AUDIT_LOG"
        "REQUIRE_CONFIRMATION"
        "ALLOW_DESTRUCTIVE_OPERATIONS"
        "ENABLE_LAMBDA_ANALYSIS"
        "ENABLE_S3_ANALYSIS"
        "ENABLE_CLOUDWATCH_ANALYSIS"
        "ENABLE_ROUTE53_ANALYSIS"
    )

    for config in "${boolean_configs[@]}"; do
        local value="${!config}"
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            echo "Error: Invalid boolean value for $config: $value (must be true or false)" >&2
            ((validation_errors++))
        fi
    done

    # Validate directories exist or can be created
    local directories=(
        "$REPORT_DIRECTORY"
        "$(dirname "$LOG_FILE")"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            if ! mkdir -p "$dir" 2>/dev/null; then
                echo "Error: Cannot create directory: $dir" >&2
                ((validation_errors++))
            else
                # log_debug "Created directory: $dir" - logging not available yet
                true  # placeholder to fix syntax
            fi
        fi
    done

    # Validate log level
    local valid_log_levels=("DEBUG" "INFO" "WARN" "ERROR")
    local log_level_valid=false
    for level in "${valid_log_levels[@]}"; do
        if [ "$LOG_LEVEL" = "$level" ]; then
            log_level_valid=true
            break
        fi
    done

    if [ "$log_level_valid" = false ]; then
        echo "Error: Invalid log level: $LOG_LEVEL (must be one of: ${valid_log_levels[*]})" >&2
        ((validation_errors++))
    fi

    if [ $validation_errors -gt 0 ]; then
        echo "Error: Configuration validation failed with $validation_errors errors" >&2
        return 1
    fi

    # log_debug "Configuration validation passed" - logging not available yet
    return 0
}

# Get EC2 price with fallback to config
get_ec2_price_from_config() {
    local instance_type="$1"

    case "$instance_type" in
        "t3.nano") echo "${EC2_T3_NANO_PRICE:-3.80}" ;;
        "t3.micro") echo "${EC2_T3_MICRO_PRICE:-8.35}" ;;
        "t3.small") echo "${EC2_T3_SMALL_PRICE:-16.70}" ;;
        "t3.medium") echo "${EC2_T3_MEDIUM_PRICE:-30.37}" ;;
        "t3.large") echo "${EC2_T3_LARGE_PRICE:-66.77}" ;;
        "t3.xlarge") echo "${EC2_T3_XLARGE_PRICE:-133.54}" ;;
        "t3.2xlarge") echo "${EC2_T3_2XLARGE_PRICE:-267.07}" ;;
        "t4g.nano") echo "${EC2_T4G_NANO_PRICE:-3.26}" ;;
        "t4g.micro") echo "${EC2_T4G_MICRO_PRICE:-6.53}" ;;
        "t4g.small") echo "${EC2_T4G_SMALL_PRICE:-13.06}" ;;
        "t4g.medium") echo "${EC2_T4G_MEDIUM_PRICE:-26.11}" ;;
        "m5.large") echo "${EC2_M5_LARGE_PRICE:-69.35}" ;;
        "m5.xlarge") echo "${EC2_M5_XLARGE_PRICE:-138.70}" ;;
        *) echo "50.00" ;;  # Default estimate
    esac
}

# Get RDS price with fallback to config
get_rds_price_from_config() {
    local instance_class="$1"

    case "$instance_class" in
        "db.t3.micro") echo "${RDS_T3_MICRO_PRICE:-16.79}" ;;
        "db.t3.small") echo "${RDS_T3_SMALL_PRICE:-33.58}" ;;
        "db.t3.medium") echo "${RDS_T3_MEDIUM_PRICE:-67.16}" ;;
        "db.t3.large") echo "${RDS_T3_LARGE_PRICE:-134.33}" ;;
        "db.t4g.micro") echo "${RDS_T4G_MICRO_PRICE:-13.43}" ;;
        "db.t4g.small") echo "${RDS_T4G_SMALL_PRICE:-26.86}" ;;
        "db.t4g.medium") echo "${RDS_T4G_MEDIUM_PRICE:-53.73}" ;;
        *) echo "100.00" ;;  # Default estimate
    esac
}

# Display current configuration
show_config() {
    log_info "Current Configuration:"
    log_info "  Pricing Region: $PRICING_REGION"
    log_info "  Log Level: $LOG_LEVEL"
    log_info "  Log File: $LOG_FILE"
    log_info "  Report Directory: $REPORT_DIRECTORY"
    log_info "  JSON Output: $ENABLE_JSON_OUTPUT"
    log_info "  Lambda Analysis: $ENABLE_LAMBDA_ANALYSIS"
    log_info "  S3 Analysis: $ENABLE_S3_ANALYSIS"
    log_info "  CloudWatch Analysis: $ENABLE_CLOUDWATCH_ANALYSIS"
}