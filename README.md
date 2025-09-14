# AWS Cost Estimator & Savings Checker

A comprehensive toolset to analyze your AWS infrastructure and estimate monthly costs, with optimization suggestions to reduce your AWS bill.

## Features

### Core Analysis
- 📊 **Comprehensive Cost Analysis**: Analyzes running AWS services with monthly cost calculations
- 💰 **Detailed Cost Breakdown**: Service-by-service cost analysis with resource-level details
- 💡 **Smart Optimization Suggestions**: AI-driven recommendations for cost reduction
- 📄 **Multi-format Reports**: JSON and text reports with timestamped audit trails
- 🎨 **Enhanced Terminal Output**: Colorized, structured output with progress indicators
- 🔍 **Resource Age & Waste Tracking**: Identifies long-running resources and potential waste

### Extended Service Coverage
- ⚡ **Lambda Functions**: Memory-based cost estimation and invocation analysis
- 🪣 **S3 Storage**: Bucket analysis with storage class recommendations
- 📊 **CloudWatch Logs**: Log group storage costs and retention optimization
- ⚖️ **Load Balancers**: ALB, NLB, and Classic Load Balancer cost analysis
- 🌐 **NAT Gateways**: Data processing and hourly charge calculations
- 🗄️ **Traditional Services**: EC2, RDS, EBS, Elastic IPs with enhanced analysis

### Advanced Capabilities
- ⚙️ **Configuration Management**: Flexible config files for pricing and behavior customization
- 📝 **Structured Logging**: Multiple log levels with audit trail capabilities
- 🔄 **Cross-platform Support**: Works seamlessly on Linux and macOS
- ⚡ **Performance Monitoring**: Built-in timing and performance analysis
- 🧪 **Testing Framework**: Automated validation and CI/CD integration
- 🔌 **API Integration**: Rich JSON output for dashboard and monitoring integration

## Supported Services

### Core Infrastructure
- **EC2 Instances**: All instance families (t3, t4g, m5, c5, r5, etc.) with accurate pricing
- **RDS Databases**: PostgreSQL, MySQL, Aurora with Multi-AZ analysis
- **EBS Storage**: GP3, GP2, io1, io2 with optimization recommendations
- **Elastic IPs**: Attached/unattached detection with cost implications

### Additional Services
- **Lambda Functions**: Memory-based pricing with invocation estimation
- **S3 Buckets**: Storage analysis with lifecycle recommendations
- **CloudWatch Logs**: Log group storage and retention optimization
- **Load Balancers**: Application, Network, and Classic Load Balancers
- **NAT Gateways**: Data processing and availability zone optimization
- **Data Transfer**: Regional and internet transfer cost estimation

### Coming Soon
- **CloudFront**: CDN distribution analysis
- **Route53**: DNS service costs
- **EFS**: Elastic File System storage
- **Redshift**: Data warehouse cost analysis

## Prerequisites

- AWS CLI installed and configured
- `bc` calculator (usually pre-installed on macOS/Linux)
- Bash shell
- Valid AWS credentials with read permissions for:
  - EC2
  - RDS
  - EBS

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/aws-savings-check.git
cd aws-savings-check
```

2. Make the scripts executable:
```bash
chmod +x scripts/*.sh
```

3. Ensure your AWS CLI is configured:
```bash
aws configure list
```

## Usage

### Basic Cost Analysis
```bash
./scripts/aws-cost-estimator.sh
```

This will:
- Scan all your running AWS services
- Calculate monthly costs
- Provide optimization suggestions
- Save a detailed report

### Sample Output
```
=== AWS Monthly Cost Estimator ===
Region: us-east-1

📊 Analyzing EC2 Instances...
Running EC2 Instances:
  ✓ i-056bab67c54645d59 (t3.micro) - nitetext-instance - $8.35/month (3 days old)
  ✓ i-09b72622ae7d82664 (t3.medium) - nitetext-instance - $30.37/month (5 days old)

💾 Analyzing EBS Volumes...
EBS Volumes in use:
  ✓ vol-0a34296637dbea162 (30GB gp3) → i-09b72622ae7d82664 - $2.88/month

🗄️  Analyzing RDS Instances...
RDS Instances:
  ✓ nitetext-production (db.t3.medium, postgres) - 20GB storage - $69.46/month

🌐 Analyzing Elastic IPs...
Elastic IPs:
  ⚠️  98.82.211.20 (UNATTACHED - costing money!) - $3.65/month

=== COST SUMMARY ===
EC2 Instances (2):    $   38.72
EBS Storage (3):      $    8.64
RDS Database (1):     $   69.46
Elastic IPs (1):      $    3.65
Data Transfer (est):  $   10.00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL MONTHLY COST:    $  130.47

💡 Cost Optimization Suggestions:
  • Release unattached Elastic IPs to save $3.65/month
  • Consider consolidating EC2 instances if possible
  • Consider downgrading RDS instance class if database load is light
```

## Cost Optimization Features

The script automatically identifies common cost optimization opportunities:

- **Unattached Elastic IPs**: Highlights IPs that are costing money unnecessarily
- **Over-provisioned Instances**: Suggests consolidation when multiple instances exist
- **RDS Right-sizing**: Recommends smaller instance classes for light workloads
- **Instance Age Tracking**: Shows how long resources have been running

## Pricing Data

The script includes current AWS pricing for US-East-1 region as of September 2024:

### EC2 Instance Pricing (Monthly)
- t3.micro: $8.35
- t3.medium: $30.37
- t3.large: $66.77
- And more...

### RDS Instance Pricing (Monthly)
- db.t3.micro: $16.79
- db.t3.medium: $67.16
- And more...

### Storage Pricing
- EBS GP3: $0.096/GB/month
- RDS Storage: $0.115/GB/month
- Elastic IPs: $3.65/month (unattached)

## Report Generation

Each run generates a timestamped report file:
```
aws-cost-report-20240904-142530.txt
```

Reports include:
- Total cost breakdown by service
- Individual resource costs
- Optimization recommendations
- Generation timestamp

## Limitations

- Pricing is based on US-East-1 region
- Data transfer costs are estimated
- Does not include Reserved Instance discounts
- Free tier benefits not automatically calculated

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Security

- **No credentials are stored**: The script only uses your existing AWS CLI configuration
- **Read-only operations**: Only performs describe/list operations, never modifies resources
- **No sensitive data**: Reports contain only resource IDs and cost estimates

## Support

For issues or questions:
1. Check the AWS CLI configuration: `aws configure list`
2. Verify permissions with: `aws sts get-caller-identity`
3. Ensure all required services are accessible in your region

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Documentation

For detailed usage examples and advanced features, see:
- [Usage Examples](docs/USAGE_EXAMPLES.md) - Real-world examples and optimization opportunities

## Project Structure

```
aws-savings-check/
├── scripts/              # Executable shell scripts
│   ├── aws-cost-estimator.sh    # Main cost analysis tool
│   └── optimize-costs.sh        # Interactive optimization tool
├── docs/                # Documentation files
│   └── USAGE_EXAMPLES.md       # Detailed usage examples
├── README.md           # This file
├── LICENSE             # MIT License
└── .gitignore         # Git ignore patterns
```

## Changelog

- **v1.1.0** (2024-09-04): Repository organization
  - Organized scripts into `scripts/` directory
  - Moved documentation to `docs/` directory
  - Updated paths and improved project structure
- **v1.0.0** (2024-09-04): Initial release
  - Basic cost analysis for EC2, RDS, EBS, and Elastic IPs
  - Colorized output and optimization suggestions
  - Report generation functionality
