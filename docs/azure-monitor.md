# Azure Monitor & Alerts Guide

## Overview
This POC provisions three Azure Monitor resources automatically via Bicep:
1. **Log Analytics Workspace** — centralized log storage (30-day retention)
2. **Application Insights** — APM, distributed tracing, performance metrics
3. **Azure Monitor Metric Alerts** — proactive notifications based on thresholds

## Alerts Provisioned
| Alert Name | Metric | Condition | Severity | When It Fires |
|------------|--------|-----------|----------|---------------|
| HTTP 5xx Errors | `Http5xx` | > 10 requests in 5 min | 1 (Critical) | High error rate |
| High CPU | `CpuPercentage` | > 80% avg in 5 min | 2 (Warning) | CPU bottleneck |
| High Memory | `MemoryPercentage` | > 80% avg in 5 min | 2 (Warning) | Memory leak |

## Action Group
All alerts route to: `ag-<appName>-<environment>` which includes:
- Email notification (configure to your ops team)
- Webhook (placeholder — update URL in `alerts.bicep`)

## Verifying Alerts
```bash
# List all metric alerts in the resource group
az monitor metrics alert list --resource-group rg-hello-world-dev --output table

# Get alert history
az monitor alert-history list --resource-group rg-hello-world-dev
```

## Sample KQL Queries (Log Analytics)
```kql
// HTTP 5xx errors in last hour
AppServiceHTTPLogs
| where ScStatus >= 500
| summarize count() by bin(TimeGenerated, 5m), CsUriStem
| render timechart

// Application exceptions
exceptions
| where timestamp > ago(1h)
| project timestamp, problemId, outerMessage
| order by timestamp desc

// App performance (failed requests by URL)
requests
| where success == false
| summarize count() by name, bin(timestamp, 1h)
| render columnchart

// CPU and Memory trends
union AppServiceAppLogs, AppServiceHTTPLogs
| where TimeGenerated > ago(1d)
| summarize avg(CpuPercentage), avg(MemoryPercentage) by bin(TimeGenerated, 1h)
| render timechart
```

## Diagnostic Settings
The Web App automatically forwards these logs to Log Analytics:
- AppServiceConsoleLogs (stdout/stderr)
- AppServiceHTTPLogs (all HTTP requests)
- AppServiceAppLogs (application logs)

These are configured declaratively in the Bicep `diagnostics.bicep` module (extend as needed).