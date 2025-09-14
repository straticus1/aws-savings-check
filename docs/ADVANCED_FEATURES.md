# Advanced Features

## Configuration Management

### Configuration Files

The AWS Cost Estimator now supports configuration files for customizing behavior:

1. **Global config**: `config/aws-cost-estimator.conf`
2. **User config**: `~/.aws-cost-estimator.conf`
3. **Local config**: `.aws-cost-estimator.conf`

Configuration files are loaded in order of preference (local > user > global).

### Sample Configuration

```bash
# Pricing Configuration (US-East-1)
EC2_T3_MICRO_PRICE=8.35
EC2_T3_MEDIUM_PRICE=30.37
RDS_T3_MICRO_PRICE=16.79

# Feature Flags
ENABLE_LAMBDA_ANALYSIS=true
ENABLE_S3_ANALYSIS=true
ENABLE_CLOUDWATCH_ANALYSIS=true

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=logs/aws-cost-estimator.log
```

## Extended AWS Service Support

### New Services Analyzed

- **Lambda Functions**: Estimates based on memory allocation and potential usage
- **S3 Buckets**: Basic storage cost estimation
- **CloudWatch Logs**: Storage costs for log retention
- **Load Balancers**: Application and Classic Load Balancer costs
- **NAT Gateways**: Data processing and hourly charges

### Service Toggle

Each service can be enabled/disabled via configuration:

```bash
ENABLE_LAMBDA_ANALYSIS=false   # Disable Lambda analysis
ENABLE_S3_ANALYSIS=true        # Enable S3 analysis
```

## Enhanced JSON Output

### Comprehensive Data Structure

```json
{
  "report_metadata": {
    "generated_at": "2024-09-14T10:30:00Z",
    "aws_region": "us-east-1",
    "report_type": "monthly_cost_estimate"
  },
  "cost_summary": {
    "core_services": {
      "ec2_cost": 69.09,
      "ebs_cost": 8.64,
      "rds_cost": 69.46,
      "elastic_ip_cost": 3.65
    },
    "additional_services": {
      "lambda_cost": 12.50,
      "s3_cost": 5.23,
      "cloudwatch_logs_cost": 2.10,
      "load_balancer_cost": 45.54,
      "nat_gateway_cost": 65.70
    },
    "total_monthly_cost": 281.91
  },
  "resources": {
    "lambda_functions": [
      {
        "function_name": "my-function",
        "runtime": "nodejs18.x",
        "memory_mb": 512,
        "estimated_monthly_cost": 12.50
      }
    ]
  }
}
```

## Advanced Logging System

### Log Levels

- **DEBUG**: Detailed execution information
- **INFO**: General information about operations
- **WARN**: Warning messages for potential issues
- **ERROR**: Error messages for failures

### Audit Trail

All cost analysis operations and resource actions are logged to an audit file for compliance and tracking.

### Log Configuration

```bash
LOG_LEVEL=INFO
LOG_FILE=logs/aws-cost-estimator.log
ENABLE_AUDIT_LOG=true
```

## Performance Monitoring

### Built-in Timing

The script now includes performance timing for each analysis phase:

```
[INFO] Lambda analysis completed in 2s
[INFO] S3 analysis completed in 1s
[INFO] Total analysis completed in 8s
```

### Optimization Tracking

Track the effectiveness of cost optimization suggestions over time through audit logs.

## Command Line Enhancements

### Extended Options

```bash
# Generate JSON output
./scripts/aws-cost-estimator.sh --createjson

# Specify custom JSON output file
./scripts/aws-cost-estimator.sh --outjson /path/to/report.json

# Show current configuration
./scripts/aws-cost-estimator.sh --show-config

# Enable debug mode
LOG_LEVEL=DEBUG ./scripts/aws-cost-estimator.sh
```

### Configuration Override

Environment variables override configuration file settings:

```bash
# Temporary price override
EC2_T3_MICRO_PRICE=10.00 ./scripts/aws-cost-estimator.sh
```

## Cross-Platform Compatibility

### Date Parsing

Improved date parsing works on both Linux and macOS:

```bash
# Handles both GNU date and BSD date formats
parse_date "2024-09-14T10:30:00.000Z"
```

### Dependency Checking

Automatic detection and validation of required tools:
- AWS CLI
- bc (calculator)
- jq (for JSON processing)

## Error Handling & Recovery

### Graceful Degradation

- Services that can't be analyzed are skipped with warnings
- Unknown instance types get default estimates
- Network timeouts don't crash the entire analysis

### Contextual Error Reporting

```bash
[ERROR] Lambda analysis failed
[ERROR] Context: Insufficient permissions for lambda:ListFunctions
```

## Testing Framework

### Automated Tests

```bash
# Run basic functionality tests
./tests/test-basic-functionality.sh

# Validate syntax of all scripts
./tests/validate-syntax.sh
```

### Continuous Integration Ready

Tests can run without AWS credentials, making them suitable for CI/CD pipelines.

## Integration Examples

### Slack Integration

```bash
#!/bin/bash
COST_REPORT=$(./scripts/aws-cost-estimator.sh --createjson --outjson /tmp/cost.json)
TOTAL_COST=$(jq -r '.cost_summary.total_monthly_cost' /tmp/cost.json)

if (( $(echo "$TOTAL_COST > 200" | bc -l) )); then
    slack-cli "Warning: AWS costs are $${TOTAL_COST}/month"
fi
```

### Cron Job Setup

```bash
# Daily cost monitoring
0 9 * * * /path/to/aws-cost-estimator.sh --createjson --outjson /var/log/daily-cost.json

# Weekly optimization report
0 9 * * 1 /path/to/optimize-costs.sh --non-interactive --createjson
```

### API Integration

The JSON output format makes it easy to integrate with monitoring dashboards, cost management platforms, and custom applications.

## Security Enhancements

### Configuration Validation

All configuration values are validated for type and range:

```bash
[ERROR] Invalid numeric value for EC2_T3_MICRO_PRICE: abc
[ERROR] Invalid boolean value for ENABLE_LAMBDA_ANALYSIS: maybe
```

### Safe Defaults

Conservative defaults prevent unexpected behavior:
- All destructive operations disabled by default
- Confirmation required for cost changes
- Maximum cost thresholds prevent runaway estimates

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure AWS credentials have read permissions for all analyzed services
2. **Region Mismatch**: Cost estimates are region-specific
3. **Large Accounts**: Analysis may take longer for accounts with many resources

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
LOG_LEVEL=DEBUG ./scripts/aws-cost-estimator.sh
```

### Performance Tuning

For large AWS accounts:
- Disable unused service analysis
- Use regional filtering
- Run analysis during off-peak hours