# Usage Examples

## Quick Start

After cloning the repository and ensuring AWS CLI is configured:

```bash
# Run cost analysis (using wrapper)
./cost-check estimate
# OR directly
./scripts/aws-cost-estimator.sh

# Run interactive optimization (using wrapper)
./cost-check optimize
# OR directly
./scripts/optimize-costs.sh
```

## Sample Output from Your Infrastructure

Based on your actual AWS infrastructure, here's what the cost estimator shows:

```
=== AWS Monthly Cost Estimator ===
Region: us-east-1

📊 Analyzing EC2 Instances...
Running EC2 Instances:
  ✓ i-056bab67c54645d59 (t3.micro) - nitetext-instance - $8.35/month (2 days old)
  ✓ i-09b72622ae7d82664 (t3.medium) - nitetext-instance - $30.37/month (4 days old)
  ✓ i-09f2a819c0140512a (t3.medium) - nitetext-instance - $30.37/month (4 days old)

💾 Analyzing EBS Volumes...
EBS Volumes in use:
  ✓ vol-0a34296637dbea162 (30GB gp3) → i-09b72622ae7d82664 - $2.88/month
  ✓ vol-08b2e9582463f9776 (30GB gp3) → i-056bab67c54645d59 - $2.88/month
  ✓ vol-0c5cf6fa3cb126e15 (30GB gp3) → i-09f2a819c0140512a - $2.88/month

🗄️  Analyzing RDS Instances...
RDS Instances:
  ✓ nitetext-production (db.t3.medium, postgres) - 20GB storage - $69.46/month
    └─ Instance: $67.16, Storage: $2.30

🌐 Analyzing Elastic IPs...
Elastic IPs:
  ⚠️  98.82.211.20 (UNATTACHED - costing money!) - $3.65/month

=== COST SUMMARY ===
EC2 Instances (3):    $   69.09
EBS Storage (3):      $    8.64
RDS Database (1):     $   69.46
Elastic IPs (1):      $    3.65
Data Transfer (est):   $   10.00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL MONTHLY COST:    $  160.84

💡 Cost Optimization Suggestions:
  • Release unattached Elastic IPs to save $3.65/month
  • Consider consolidating EC2 instances if possible
  • Consider downgrading RDS instance class if database load is light
```

## Cost Optimization Opportunities

### Immediate Savings ($3.65/month)
- **Unattached Elastic IP**: 98.82.211.20 is costing $3.65/month
- **Action**: Release this IP if not needed

### Potential Consolidation ($30.37/month)
- **Current**: 3 EC2 instances (1 t3.micro + 2 t3.medium)
- **Suggestion**: Consider consolidating to 2 instances if workload allows
- **Savings**: Up to $30.37/month

### RDS Optimization ($35-40/month)
- **Current**: db.t3.medium ($67.16/month)
- **Suggestion**: Downgrade to db.t3.micro ($16.79/month) if load is light
- **Savings**: ~$50/month

## Total Potential Monthly Savings: $80-90

Your optimized cost could be as low as **$70-80/month** instead of $160.84.

## Interactive Optimization Tool

The `optimize-costs.sh` script provides a menu-driven interface:

```
=== Cost Optimization Options ===
1. Release unattached Elastic IPs
2. Analyze EC2 consolidation opportunities  
3. Analyze RDS optimization opportunities
4. Analyze EBS volume optimization
5. Show cost monitoring recommendations
6. Run all analyses
7. Exit
```

## Security Features

✅ **No credentials stored** - Uses your existing AWS CLI configuration
✅ **Read-only operations** - Never modifies resources without explicit confirmation  
✅ **Safe cleanup** - Interactive prompts before making any changes
✅ **Audit trail** - Generates detailed reports with timestamps

## Report Generation

Each run creates a timestamped report file:
- `aws-cost-report-20240904-142530.txt`
- Contains detailed cost breakdown
- Useful for tracking cost trends over time
- Can be used for budget planning and reporting

## Integration Tips

### Automated Monitoring
```bash
# Run daily cost check (read-only)
./scripts/aws-cost-estimator.sh > daily-cost-$(date +%Y%m%d).txt

# Weekly optimization review
./scripts/optimize-costs.sh
```

### CI/CD Integration
```bash
# Cost gate in deployment pipeline
COST=$(./scripts/aws-cost-estimator.sh | grep "TOTAL MONTHLY COST" | awk '{print $4}' | tr -d '$')
if (( $(echo "$COST > 200" | bc -l) )); then
    echo "Warning: Monthly cost exceeds budget threshold"
fi
```

This tool has already identified real cost optimization opportunities in your AWS infrastructure!
