# Changelog

All notable changes to AWS Savings Check will be documented in this file.

## [2.1.0] - 2025-11-09

### Added
- **Current Bill Checker**: New `current-bill.sh` script to view real-time AWS billing
  - Shows current month-to-date charges (actual amount owed)
  - Displays bill due date (typically 10th of following month)
  - Shows grace period (typically 20th of following month)
  - Service-level cost breakdown with actual costs from AWS Cost Explorer
  - Month-over-month comparison
  - End-of-month forecast using AWS prediction and linear projection
  - Budget warning system
  - Accessible via `./cost-check bill`

### Fixed
- **Bash Compatibility**: Updated all script shebangs from `#!/bin/bash` to `#!/usr/local/bin/bash`
  - Fixes associative array support (requires bash 4.0+)
  - macOS ships with bash 3.2, now uses installed bash 5.3.3
  - Affects all scripts in `scripts/`, `helpers/`, and `lib/`
- **Configuration Parser**: Fixed inline comment handling
  - Now properly strips inline comments (e.g., `LOG_LEVEL="INFO" # Comment`)
  - Added trailing newline to config file to prevent parsing errors
- **Counter Increment Bug**: Fixed `set -e` compatibility issue
  - Changed `((count++))` to `count=$((count + 1))` to prevent premature script exit
  - Affects `aws-cost-estimator.sh` and `lib/aws-services.sh`
- **Logging Output**: Redirected all log output to stderr
  - Prevents logging from contaminating function return values
  - Fixes issues in library functions

### Changed
- Enhanced `cost-check` wrapper to include new `bill` command
- Improved error handling across all scripts

### Security
- Requires additional AWS permissions for current bill feature:
  - `ce:GetCostAndUsage` - For actual costs
  - `ce:GetCostForecast` - For projections

## [2.0.0] - 2024-09-14

### Added
- Comprehensive AWS Cost Estimator Enhancement

## [1.0.0] - 2025-09-14

### Added
- Core Cost Analysis
  - Real-time AWS infrastructure cost estimation
  - Support for EC2, RDS, EBS, and Elastic IP cost analysis
  - Monthly and annual cost projections
  - Resource age and utilization tracking
  - Waste detection algorithms

- Infrastructure Management
  - Interactive resource management interface
  - Safe shutdown procedures
  - Emergency infrastructure control
  - Resource visualization tools

- Optimization Tools
  - Cost optimization recommendations
  - Resource consolidation analysis
  - Database sizing suggestions
  - Storage optimization checks

- Reporting System
  - JSON and text report generation
  - Timestamped audit trails
  - Cost trend analysis
  - Utilization metrics

### Security Features
- AWS credential validation
- Read-only analysis mode
- Interactive confirmation system
- Audit logging
- Safe resource management

### Documentation
- Comprehensive usage examples
- Integration guidelines
- Security documentation
- API documentation

## [0.1.0] - 2025-09-14

### Added
- Initial project structure
- Basic AWS infrastructure analysis
- Cost estimation framework
- Helper script foundation
- Documentation templates