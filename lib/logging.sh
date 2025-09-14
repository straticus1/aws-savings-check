#!/bin/bash

# Logging utility functions for AWS Cost Estimator
# Provides structured logging with levels and file output

# Default configuration
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-logs/aws-cost-estimator.log}"
ENABLE_AUDIT_LOG="${ENABLE_AUDIT_LOG:-true}"
AUDIT_LOG_FILE="logs/audit.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# Log levels (numeric for comparison)
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
)

# Get current log level numeric value
get_log_level_numeric() {
    echo "${LOG_LEVELS[${LOG_LEVEL}]:-1}"
}

# Ensure log directory exists
setup_logging() {
    local log_dir=$(dirname "$LOG_FILE")
    local audit_log_dir=$(dirname "$AUDIT_LOG_FILE")

    mkdir -p "$log_dir" 2>/dev/null || true
    mkdir -p "$audit_log_dir" 2>/dev/null || true

    # Initialize log files with headers if they don't exist
    if [ ! -f "$LOG_FILE" ]; then
        echo "# AWS Cost Estimator Log - Started $(date)" > "$LOG_FILE"
    fi

    if [ "$ENABLE_AUDIT_LOG" = "true" ] && [ ! -f "$AUDIT_LOG_FILE" ]; then
        echo "# AWS Cost Estimator Audit Log - Started $(date)" > "$AUDIT_LOG_FILE"
    fi
}

# Generic logging function
log_message() {
    local level="$1"
    local message="$2"
    local color="$3"

    local current_level_num=$(get_log_level_numeric)
    local message_level_num="${LOG_LEVELS[$level]:-1}"

    # Check if message should be logged based on level
    if [ "$message_level_num" -ge "$current_level_num" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local formatted_message="[$timestamp] [$level] $message"

        # Console output with color
        echo -e "${color}$formatted_message${NC}"

        # File output without color
        echo "$formatted_message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Specific log level functions
log_debug() {
    log_message "DEBUG" "$1" "$GRAY"
}

log_info() {
    log_message "INFO" "$1" "$BLUE"
}

log_warn() {
    log_message "WARN" "$1" "$YELLOW"
}

log_error() {
    log_message "ERROR" "$1" "$RED"
}

log_success() {
    log_message "INFO" "✓ $1" "$GREEN"
}

# Audit logging for important actions
log_audit() {
    if [ "$ENABLE_AUDIT_LOG" = "true" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local audit_message="[$timestamp] [AUDIT] $1"
        echo "$audit_message" >> "$AUDIT_LOG_FILE" 2>/dev/null || true
    fi
}

# Cost analysis specific logging
log_cost_analysis() {
    local service="$1"
    local count="$2"
    local cost="$3"

    log_info "$service analysis: $count resources, \$$(printf "%.2f" $cost)/month"
    log_audit "Cost analysis - $service: $count resources, \$$(printf "%.2f" $cost)/month"
}

# Resource action logging
log_resource_action() {
    local action="$1"
    local resource_type="$2"
    local resource_id="$3"
    local result="$4"

    log_info "$action $resource_type $resource_id: $result"
    log_audit "Resource action - $action $resource_type $resource_id: $result"
}

# Error with context logging
log_error_with_context() {
    local error_message="$1"
    local context="$2"
    local exit_code="${3:-1}"

    log_error "$error_message"
    if [ -n "$context" ]; then
        log_error "Context: $context"
    fi
    log_audit "Error occurred - $error_message (Context: $context)"

    return $exit_code
}

# Log file cleanup
cleanup_old_logs() {
    local archive_after_days="${ARCHIVE_AFTER_DAYS:-30}"

    if [ "$ARCHIVE_OLD_REPORTS" = "true" ]; then
        # Find and archive old log files
        find "$(dirname "$LOG_FILE")" -name "*.log" -type f -mtime +$archive_after_days -exec gzip {} \; 2>/dev/null || true
        log_info "Archived log files older than $archive_after_days days"
    fi
}

# Performance timing
declare -A TIMERS

start_timer() {
    local timer_name="$1"
    TIMERS[$timer_name]=$(date +%s)
}

end_timer() {
    local timer_name="$1"
    local start_time="${TIMERS[$timer_name]}"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_debug "$timer_name completed in ${duration}s"
    unset TIMERS[$timer_name]
}

# Initialize logging
setup_logging