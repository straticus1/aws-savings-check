# Fixes and Updates - November 9, 2025

## Issues Fixed

### 1. Bash Version Compatibility
**Problem**: Scripts required bash 4.0+ for associative arrays (`declare -A`), but macOS ships with bash 3.2.

**Solution**: Updated all script shebangs from `#!/bin/bash` to `#!/usr/local/bin/bash` to use the newer bash 5.3.3 installation.

**Files affected**:
- `cost-check`
- `scripts/aws-cost-estimator.sh`
- `scripts/optimize-costs.sh`
- `scripts/current-bill.sh`
- All files in `helpers/*.sh`
- All files in `lib/*.sh`

### 2. Configuration File Parsing
**Problem**:
- Parser didn't handle inline comments (e.g., `LOG_LEVEL="INFO" # Comment`)
- Config file missing trailing newline caused parsing errors

**Solution**:
- Updated config parser to strip inline comments using `${value%%#*}`
- Added newline to end of config file

**Files affected**:
- `lib/config.sh`
- `config/aws-cost-estimator.conf`

### 3. Counter Increment Bug with `set -e`
**Problem**: Using `((count++))` with `set -e` caused scripts to exit when counter was 0, because post-increment returns 0 (which is treated as false/error with `set -e`).

**Solution**: Changed all instances of `((count++))` to `count=$((count + 1))`

**Files affected**:
- `scripts/aws-cost-estimator.sh`
- `lib/aws-services.sh`

### 4. Logging Output Contamination
**Problem**: Logging functions output to stdout, which contaminated function return values in library functions.

**Solution**: Redirected all log output to stderr (`>&2`) in `lib/logging.sh`

**Files affected**:
- `lib/logging.sh`

## New Features

### Current Bill Checker
**New Script**: `scripts/current-bill.sh`

Shows your actual AWS bill with real costs from AWS Cost Explorer:

- ✅ **Current month-to-date charges** (what you actually owe right now)
- ✅ **Bill due date** (typically 10th of following month)
- ✅ **Grace period** (typically 20th of following month)
- ✅ **Service breakdown** with actual costs
- ✅ **Month-over-month comparison**
- ✅ **End-of-month forecast** using both AWS forecast and linear projection
- ✅ **Budget warnings** when costs exceed thresholds

**Usage**:
```bash
./cost-check bill
# or
./scripts/current-bill.sh
```

**Sample Output**:
```
=== AWS Current Bill ===

Billing Period: 2025-11-01 to 2025-11-30 (Day 09 of month)
Bill Due Date:  December 10, 2025 (31 days from now)
Grace Period:   Until December 20, 2025

AMOUNT OWED (Month-to-Date): $785.38
Projected End-of-Month Total: $3794.97
Simple Linear Forecast:       $2617.93

Last Month's Total:           $2215.09
```

## Testing Results

All scripts now work correctly:

- ✅ `./cost-check` - Main wrapper
- ✅ `./cost-check estimate` - Cost estimation (analyzes 9 EC2, 9 EBS, 5 RDS, 37 Lambda, 52 S3, 95 CloudWatch Logs, 10 LBs, 4 NAT Gateways)
- ✅ `./cost-check bill` - Current bill checker
- ✅ `./cost-check optimize` - Cost optimizer
- ✅ `./cost-check view` - Infrastructure viewer

## Performance

Scripts now complete successfully with AWS API calls taking the expected time:
- Cost estimation: ~60-90 seconds (due to multiple AWS API calls)
- Current bill: ~10-15 seconds (Cost Explorer API)

## Reports Generated

Reports are saved to:
- Cost estimates: `aws-cost-report-YYYYMMDD-HHMMSS.txt`
- Current bill: `reports/current-bill-YYYYMMDD-HHMMSS.txt`
- JSON reports: Available with `--createjson` flag

## AWS Permissions Required

The current bill feature requires:
- `ce:GetCostAndUsage` - For actual costs
- `ce:GetCostForecast` - For projections

Existing permissions still needed:
- EC2, RDS, EBS read permissions
- Lambda, S3, CloudWatch, ELB read permissions
