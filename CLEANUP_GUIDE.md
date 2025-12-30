# Datadog Resource Cleanup Guide

## When to Use This

If the teardown script fails to destroy Terraform resources (common with TLS/network issues), you'll have "orphaned" resources in Datadog that prevent `terraform apply` from succeeding.

## Important: Tags vs Team Objects

This script **only deletes resources tagged with `team:chatbot`** (monitors, SLOs, synthetic tests, security rules).

**It does NOT delete:**
- Team objects (Settings → Organization → Teams)
- Team memberships or settings
- Manually created dashboards or other resources

The demo uses `team:chatbot` as a **tag** for organization, not as a Team object. You can optionally create a Team object manually in your Datadog org if you want Team-based features (@mentions, permissions, etc.).

## Symptoms

When running `terraform apply`, you see errors like:
```
Error: error creating monitor from /api/v1/monitor: 400 Bad Request: 
{"errors":["Duplicate of an existing monitor_id:XXXXXX org_id:XXXXXX"]}
```

## Solution: API-Based Cleanup

### Step 1: Get Your Datadog API Keys

1. Navigate to: https://app.datadoghq.com/organization-settings/api-keys
2. Copy your **API Key**
3. Navigate to: https://app.datadoghq.com/organization-settings/application-keys
4. Copy your **Application Key** (create one if needed)

### Step 2: Set Environment Variables

```bash
export DD_API_KEY='your-api-key-here'
export DD_APP_KEY='your-app-key-here'
export DD_SITE='datadoghq.com'  # or your site (datadoghq.eu, etc.)
```

### Step 3: Run the Cleanup Script

```bash
./scripts/cleanup-datadog-v2.sh
```

The script will:
- ✅ Find all monitors with `[demo]` prefix or "demo"/"chatbot" in name
- ✅ Find all SLOs with "demo"/"chatbot" in name
- ✅ Find all security monitoring rules (Cloud SIEM) with "demo"/"chatbot" in name
- ✅ Find all synthetic tests with "demo" in name
- ✅ Delete them all via Datadog API
- ✅ Show you what's being deleted (names and IDs)

### Step 4: Verify Cleanup

Check Datadog UI to confirm resources are deleted:
- Monitors: https://app.datadoghq.com/monitors/manage
- SLOs: https://app.datadoghq.com/slo/manage
- Synthetic Tests: https://app.datadoghq.com/synthetics/tests

### Step 5: Run Terraform Apply

```bash
cd terraform
terraform apply -auto-approve
```

---

## Alternative: Manual Cleanup

If you prefer to delete resources manually from the Datadog UI:

1. **Monitors**: Go to Monitors → Manage Monitors
   - Filter by tag: `team:chatbot` or `managed_by:terraform`
   - Select all → Delete

2. **SLOs**: Go to Service Management → SLOs
   - Filter by tag: `team:chatbot`
   - Delete each one

3. **Synthetic Tests**: Go to Synthetic Monitoring → Tests
   - Filter by tag: `team:chatbot`
   - Select all → Delete

4. **Security Rules**: Go to Security → Cloud SIEM → Rules
   - Search for "demo" or "chatbot"
   - Delete matching rules

---

## Updated Teardown Script

The improved `scripts/teardown.sh` now:

1. Tries `terraform destroy` first
2. If it fails (TLS/network issues), offers to run `cleanup-datadog.sh` instead
3. Handles new resources: worker, rabbitmq, airflow
4. Provides better error messages and recovery options

---

## Troubleshooting

### "401 Unauthorized"
- Check your API/App keys are correct
- Ensure the App Key has appropriate permissions

### "Resources still exist after cleanup"
- Some resources might not have the expected tags
- Delete them manually from Datadog UI
- Check the script output for specific errors

### "Terraform still sees duplicates"
- Wait 1-2 minutes after cleanup (Datadog API propagation)
- Verify resources are gone in Datadog UI
- Run `terraform apply` again

