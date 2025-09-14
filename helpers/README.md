# AWS Helper Scripts

These helper scripts provide visibility and control over your AWS infrastructure to prevent runaway costs.

## 🔍 Infrastructure Visibility

### `./view-infrastructure.sh`
**Safe visibility tool** - Shows all running resources with costs and age tracking.

**Features:**
- Lists all running EC2 instances with daily/monthly costs
- Shows RDS databases with storage costs
- Identifies unattached Elastic IPs (cost wasters)
- Color-coded age warnings (red for resources running >7 days)
- Calculates estimated waste from long-running resources
- Generates timestamped reports

**Usage:**
```bash
./helpers/view-infrastructure.sh
```

**Sample Output:**
```
📊 EC2 INSTANCES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INSTANCE ID          TYPE         NAME            AGE        $/MONTH    $/DAY
────────────────────────────────────────────────────────────────────────────────
i-056bab67c54645d59   t3.micro     nitetext        14d        $   8.35   $ 0.28
i-09b72622ae7d82664   t3.medium    nitetext        14d        $  30.37   $ 1.01

💸 ESTIMATED WASTE: $21.70 (resources running too long)
```

## 🛑 Selective Shutdown

### `./shutdown-infrastructure.sh`
**Interactive shutdown tool** - Safely stops/terminates resources with user confirmation.

**Features:**
- Interactive menu for each resource
- Stop vs Terminate options for EC2
- Stop vs Delete options for RDS (with automatic snapshots)
- Release unattached Elastic IPs
- Calculates savings estimates
- Triple confirmation for destructive actions

**Usage:**
```bash
./helpers/shutdown-infrastructure.sh
```

**Options for each resource:**
- **EC2**: Stop (reversible) or Terminate (permanent)
- **RDS**: Stop (reversible) or Delete (permanent, creates final snapshot)
- **EIPs**: Release unattached IPs (saves $3.65/month each)

## 🚨 Emergency Shutdown

### `./emergency-destroyall.sh`
**DANGEROUS** - Immediately shuts down ALL resources to stop runaway costs.

**⚠️ WARNING: This is a nuclear option!**
- Terminates ALL running EC2 instances (permanent)
- Deletes ALL RDS databases (permanent, creates emergency snapshots)
- Releases ALL unattached Elastic IPs
- Requires triple confirmation to proceed

**Only use when:**
- Costs are spiraling out of control
- You need immediate emergency shutdown
- You understand the consequences

**Usage:**
```bash
./helpers/emergency-destroyall.sh
```

**Required confirmations:**
1. Type `EMERGENCY`
2. Type `DESTROY-ALL`
3. Type `I-UNDERSTAND-THIS-CANNOT-BE-UNDONE`

## 📊 Reports

All scripts generate timestamped reports in the `reports/` directory:
- `infrastructure-report-YYYYMMDD-HHMMSS.txt`
- `shutdown-report-YYYYMMDD-HHMMSS.txt`
- `emergency-destroyall-YYYYMMDD-HHMMSS.txt`

## 🔐 Security Features

✅ **Read-only by default** - Visibility script only reads, never modifies
✅ **Interactive confirmations** - All shutdown actions require explicit confirmation
✅ **Emergency snapshots** - RDS deletions create automatic snapshots for recovery
✅ **Detailed logging** - All actions are logged with timestamps
✅ **No credential storage** - Uses your existing AWS CLI configuration

## 💡 Cost Optimization Workflow

1. **Daily Monitoring**: Run `./view-infrastructure.sh` to check for waste
2. **Weekly Cleanup**: Run `./shutdown-infrastructure.sh` to selectively shutdown unneeded resources
3. **Emergency Only**: Use `./emergency-destroyall.sh` only in true cost emergencies

## 🚀 Quick Start

```bash
# Check what's running and costing money
./helpers/view-infrastructure.sh

# Selectively shutdown resources
./helpers/shutdown-infrastructure.sh

# Emergency shutdown (only if costs are out of control)
# ./helpers/emergency-destroyall.sh  # Commented - use with extreme caution!
```

Based on your current infrastructure (~$249/month), you could potentially save $80-90/month by shutting down unnecessary resources that have been running for weeks!