#!/usr/local/bin/bash

# AWS Current Bill Checker
# Shows actual month-to-date costs and bill details
# Author: Generated for AWS Cost Management
# Version: 1.0.0

set -e

# Get script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"

# Source library functions
source "$ROOT_DIR/lib/config.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/logging.sh" 2>/dev/null || true

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}=== AWS Current Bill ===${NC}"
echo ""

# Check dependencies
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Get current date info
current_year=$(date +%Y)
current_month=$(date +%m)
current_day=$(date +%d)

# Calculate billing period
month_start="${current_year}-${current_month}-01"
next_month=$(date -v+1m +%Y-%m-01 2>/dev/null || date -d "$(date +%Y-%m-01) +1 month" +%Y-%m-01)
month_end=$(date -v-1d -j -f "%Y-%m-%d" "$next_month" +%Y-%m-%d 2>/dev/null || date -d "$next_month -1 day" +%Y-%m-%d)

# Bill due date (AWS typically bills on the 1st, due by the 10th of the following month)
bill_due_date=$(date -v+1m -v10d -j -f "%Y-%m-%d" "$(date +%Y-%m-01)" +%Y-%m-%d 2>/dev/null || date -d "$(date +%Y-%m-01) +1 month +9 days" +%Y-%m-%d)
bill_due_date_formatted=$(date -j -f "%Y-%m-%d" "$bill_due_date" +"%B %d, %Y" 2>/dev/null || date -d "$bill_due_date" +"%B %d, %Y")

# Grace period (typically payment must be received by the 20th to avoid late fees)
grace_end_date=$(date -v+1m -v20d -j -f "%Y-%m-%d" "$(date +%Y-%m-01)" +%Y-%m-%d 2>/dev/null || date -d "$(date +%Y-%m-01) +1 month +19 days" +%Y-%m-%d)
grace_end_formatted=$(date -j -f "%Y-%m-%d" "$grace_end_date" +"%B %d, %Y" 2>/dev/null || date -d "$grace_end_date" +"%B %d, %Y")

# Calculate days until bill is due
today=$(date +%s)
due_timestamp=$(date -j -f "%Y-%m-%d" "$bill_due_date" +%s 2>/dev/null || date -d "$bill_due_date" +%s)
days_until_due=$(( (due_timestamp - today) / 86400 ))

echo -e "${CYAN}Billing Period:${NC} ${month_start} to ${month_end} (Day ${current_day} of month)"
echo -e "${CYAN}Bill Due Date:${NC}  ${bill_due_date_formatted} (${days_until_due} days from now)"
echo -e "${CYAN}Grace Period:${NC}   Until ${grace_end_formatted}"
echo ""

# Get month-to-date costs
echo -e "${YELLOW}⏳ Fetching actual costs from AWS Cost Explorer...${NC}"

mtd_response=$(aws ce get-cost-and-usage \
    --time-period Start=$month_start,End=$(date +%Y-%m-%d) \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    2>/dev/null)

if [ -z "$mtd_response" ]; then
    echo -e "${RED}ERROR: Failed to retrieve cost data${NC}"
    exit 1
fi

# Calculate total month-to-date
total_mtd=$(echo "$mtd_response" | jq -r '[.ResultsByTime[].Groups[].Metrics.UnblendedCost.Amount | tonumber] | add')

# Get forecast for end of month
echo -e "${YELLOW}📊 Getting cost forecast...${NC}"

tomorrow=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "tomorrow" +%Y-%m-%d)
forecast_response=$(aws ce get-cost-forecast \
    --time-period Start=$tomorrow,End=$next_month \
    --metric UNBLENDED_COST \
    --granularity MONTHLY \
    2>/dev/null)

forecast_total=$(echo "$forecast_response" | jq -r '.Total.Amount // "0"')
forecast_end_month=$(echo "$total_mtd + $forecast_total" | bc -l)

# Get costs by service (top 10)
echo ""
echo -e "${BLUE}${BOLD}=== CURRENT BILL DETAILS ===${NC}"
echo ""
echo -e "${CYAN}Month-to-Date (as of $(date +"%B %d, %Y")):${NC}"

# Extract service costs
service_costs=$(echo "$mtd_response" | jq -r '
    [.ResultsByTime[].Groups[] |
    {service: .Keys[0], cost: (.Metrics.UnblendedCost.Amount | tonumber)}] |
    group_by(.service) |
    map({service: .[0].service, cost: map(.cost) | add}) |
    sort_by(-.cost) |
    .[:15]
')

echo "$service_costs" | jq -r '.[] | "  \(.service): $\(.cost | . * 100 | round / 100)"' | while read line; do
    cost=$(echo "$line" | awk -F'$' '{print $2}')
    if (( $(echo "$cost > 10" | bc -l) )); then
        echo -e "  ${GREEN}$line${NC}"
    elif (( $(echo "$cost > 1" | bc -l) )); then
        echo -e "  ${YELLOW}$line${NC}"
    else
        echo -e "  ${CYAN}$line${NC}"
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${MAGENTA}AMOUNT OWED (Month-to-Date): \$$(printf "%.2f" $total_mtd)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show forecast
if (( $(echo "$forecast_total > 0" | bc -l) )); then
    echo -e "${CYAN}Projected End-of-Month Total:${NC} \$$(printf "%.2f" $forecast_end_month)"
    daily_rate=$(echo "$total_mtd / $current_day" | bc -l)
    days_in_month=$(date -j -f "%Y-%m-%d" "$month_end" +%d 2>/dev/null || date -d "$month_end" +%d)
    simple_forecast=$(echo "$daily_rate * $days_in_month" | bc -l)
    echo -e "${CYAN}Simple Linear Forecast:${NC}       \$$(printf "%.2f" $simple_forecast)"
    echo ""
fi

# Get last month's bill for comparison
last_month_start=$(date -v-1m -j -f "%Y-%m-01" "$(date +%Y-%m-01)" +%Y-%m-01 2>/dev/null || date -d "$(date +%Y-%m-01) -1 month" +%Y-%m-01)
last_month_end=$month_start

last_month_response=$(aws ce get-cost-and-usage \
    --time-period Start=$last_month_start,End=$last_month_end \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    2>/dev/null)

last_month_total=$(echo "$last_month_response" | jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount // "0"')

if (( $(echo "$last_month_total > 0" | bc -l) )); then
    echo -e "${CYAN}Last Month's Total:${NC}           \$$(printf "%.2f" $last_month_total)"
    difference=$(echo "$total_mtd - $last_month_total" | bc -l)
    if (( $(echo "$difference > 0" | bc -l) )); then
        percent_change=$(echo "scale=1; ($difference / $last_month_total) * 100" | bc -l)
        echo -e "${RED}Trending ${percent_change}% higher than last month${NC}"
    else
        percent_change=$(echo "scale=1; ($difference / $last_month_total) * -100" | bc -l)
        echo -e "${GREEN}Trending ${percent_change}% lower than last month${NC}"
    fi
    echo ""
fi

# Show payment information
echo -e "${YELLOW}${BOLD}💳 Payment Information:${NC}"
echo -e "${CYAN}Current charges will appear on your bill dated:${NC} $(date -v+1m -j -f "%Y-%m-01" "$(date +%Y-%m-01)" +"%B 1, %Y" 2>/dev/null || date -d "$(date +%Y-%m-01) +1 month" +"%B 1, %Y")"
echo -e "${CYAN}Payment due:${NC} ${bill_due_date_formatted}"
echo -e "${CYAN}Late fee cutoff:${NC} ${grace_end_formatted}"
echo ""

# Budget warnings
if (( $(echo "$forecast_end_month > 1500" | bc -l) )); then
    echo -e "${RED}⚠️  WARNING: Projected monthly cost exceeds \$1,500${NC}"
elif (( $(echo "$forecast_end_month > 1000" | bc -l) )); then
    echo -e "${YELLOW}⚠️  Notice: Projected monthly cost exceeds \$1,000${NC}"
fi

# Cost optimization reminder
if (( $(echo "$total_mtd > 100" | bc -l) )); then
    echo -e "${BLUE}💡 Tip: Run './cost-check optimize' to find cost-saving opportunities${NC}"
fi

# Save detailed report
report_file="reports/current-bill-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p reports
{
    echo "AWS Current Bill Report"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    echo "Billing Period: ${month_start} to ${month_end}"
    echo "Current Day: ${current_day}"
    echo "Bill Due: ${bill_due_date_formatted}"
    echo "Grace Period Ends: ${grace_end_formatted}"
    echo ""
    echo "Month-to-Date Total: \$$(printf "%.2f" $total_mtd)"
    echo "Projected Month-End: \$$(printf "%.2f" $forecast_end_month)"
    echo "Last Month's Total: \$$(printf "%.2f" $last_month_total)"
    echo ""
    echo "Top Services by Cost:"
    echo "$service_costs" | jq -r '.[] | "  \(.service): $\(.cost | . * 100 | round / 100)"'
} > "$report_file"

echo ""
echo -e "${GREEN}📄 Detailed report saved to: $report_file${NC}"
