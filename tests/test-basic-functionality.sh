#!/bin/bash

# Basic functionality test script for AWS Cost Estimator
# Tests core functionality without requiring AWS credentials

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." &> /dev/null && pwd)"

echo -e "${YELLOW}Running AWS Cost Estimator Tests...${NC}"

# Test 1: Check script syntax
echo -n "Testing script syntax... "
if bash -n "$ROOT_DIR/scripts/aws-cost-estimator.sh"; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 2: Check helper script syntax
echo -n "Testing helper script syntax... "
for script in "$ROOT_DIR/helpers/"*.sh; do
    if ! bash -n "$script"; then
        echo -e "${RED}✗ FAIL: $script${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ PASS${NC}"

# Test 3: Check library syntax
echo -n "Testing library syntax... "
for lib in "$ROOT_DIR/lib/"*.sh; do
    if [ -f "$lib" ]; then
        if ! bash -n "$lib"; then
            echo -e "${RED}✗ FAIL: $lib${NC}"
            exit 1
        fi
    fi
done
echo -e "${GREEN}✓ PASS${NC}"

# Test 4: Check configuration loading
echo -n "Testing configuration loading... "
if source "$ROOT_DIR/lib/config.sh" 2>/dev/null && set_default_config; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 5: Check logging functionality
echo -n "Testing logging functionality... "
if source "$ROOT_DIR/lib/logging.sh" 2>/dev/null; then
    # Test logging without writing to files
    LOG_FILE="/dev/null"
    AUDIT_LOG_FILE="/dev/null"
    setup_logging
    log_info "Test log message"
    log_debug "Test debug message"
    log_warn "Test warning message"
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 6: Check help functionality
echo -n "Testing help functionality... "
if "$ROOT_DIR/scripts/aws-cost-estimator.sh" --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 7: Check cost-check wrapper
echo -n "Testing cost-check wrapper... "
if "$ROOT_DIR/cost-check" help >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 8: Check pricing functions
echo -n "Testing pricing functions... "
source "$ROOT_DIR/lib/config.sh"
set_default_config
price=$(get_ec2_price_from_config "t3.micro")
if [ "$price" = "8.35" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL (expected 8.35, got $price)${NC}"
    exit 1
fi

echo -e "\n${GREEN}All tests passed! ✓${NC}"

# Performance test
echo -e "\n${YELLOW}Performance Test:${NC}"
start_time=$(date +%s)
bash -n "$ROOT_DIR/scripts/aws-cost-estimator.sh"
bash -n "$ROOT_DIR/scripts/optimize-costs.sh"
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Script validation completed in ${duration}s"

echo -e "\n${GREEN}Test suite completed successfully!${NC}"