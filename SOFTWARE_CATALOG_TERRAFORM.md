# Software Catalog - Terraform Management

## Overview

The Software Catalog entities are managed as Terraform resources, ensuring they're version controlled and deployed alongside your infrastructure.

## What's Defined

All entities are in `terraform/software_catalog.tf`:

- **System**: `chatbot-demo-system` *(currently commented out - see note below)*
- **Services**: `chat-backend`, `chat-frontend`, `openai-api`
- **Datastore**: `chat-postgres`

All use standardized `team:chatbot` ownership and the v2.2 service definition schema.

> **⚠️ Note**: Using schema version v2.2 for maximum compatibility with the Terraform provider. The v3.0 schema with `kind` and nested `spec` fields is not yet fully supported.

---

## Deploy Entities

### Initial Deployment

```bash
cd terraform
terraform init    # Initialize providers (if needed)
terraform plan    # Review entities to be created
terraform apply   # Deploy to Software Catalog
```

### View in Datadog

After deployment:

```bash
# Get the Software Catalog URL
terraform output software_catalog_url

# Or view all entity names
terraform output software_catalog_entities
```

Direct URL: https://app.datadoghq.com/software-catalog?owner=team%3Achatbot

---

## Features

### Dynamic Configuration

The Terraform resources use variables for flexibility:

**Service Names:**
- Backend: `var.backend_service` (from terraform.tfvars)
- Frontend: `var.frontend_service` (from terraform.tfvars)

**Contact Information:**
- Email: Uses `var.alert_email` if set
- Slack: Uses `var.alert_slack_channel` if set

**Environment:**
- All tags include `env:${var.environment}`

**Dashboard Link:**
- Automatically uses the dashboard created by Terraform
- Reference: `datadog_dashboard.chatbot_overview.id`

### Service Relationships

Services can reference each other through dependencies:
```hcl
integrations = {
  opsgenie = {
    service_url = "https://app.opsgenie.com/service/..."
    region      = "US"
  }
}

# Dependencies are automatically discovered via APM
# or can be explicitly defined in the service definition
```

---

## Customization

### Update Contact Information

Edit `terraform.tfvars`:

```hcl
alert_email         = "team-chatbot@yourcompany.com"
alert_slack_channel = "@your-slack-channel"
```

Then apply:
```bash
terraform apply
```

### Update GitHub URLs

Edit `terraform/software_catalog.tf` and replace `YOUR_ORG`:

```hcl
links = [
  {
    name = "Backend Code"
    type = "repo"
    url  = "https://github.com/YOUR_ORG/datadog-chatbot-demo/tree/main/backend"
  }
]
```

Then apply:
```bash
terraform apply
```

### Add PagerDuty Integration

Edit `terraform/software_catalog.tf`, find the service entity, and add:

```hcl
integrations = {
  pagerduty = {
    service_url = "https://YOUR_ORG.pagerduty.com/service-directory/PXXXXXX"
  }
}
```

### Change Team Name

If you want to use a different team name:

1. Update `owner` in all entities:
   ```hcl
   owner = "team:platform"  # Or team:demo, team:engineering, etc.
   ```

2. Also update in other Terraform files:
   - `terraform/datadog_agent.tf`
   - `terraform/monitors.tf`
   - `terraform/slos.tf`

3. Apply changes:
   ```bash
   terraform apply
   ```

---

## Verification

### Check Terraform State

```bash
cd terraform

# List Software Catalog resources
terraform state list | grep service_definition

# View specific entity
terraform state show datadog_service_definition_yaml.backend
```

### Verify in Datadog UI

1. **Software Catalog**: https://app.datadoghq.com/software-catalog
2. Filter by `team:chatbot`
3. Click on services to view details

### Check Entity Details

For each service, verify:
- ✅ **Overview**: Metadata, description, links
- ✅ **Definition**: Shows Terraform-managed
- ✅ **Ownership**: `team:chatbot`
- ✅ **Dependencies**: Service relationships
- ✅ **Monitors**: Associated monitors (auto-linked)
- ✅ **SLOs**: Service level objectives (auto-linked)

---

## Updates and Changes

### Modify Entity Metadata

1. Edit `terraform/software_catalog.tf`
2. Update description, links, tags, etc.
3. Run `terraform plan` to see changes
4. Run `terraform apply` to update

**Example: Update backend description**

```hcl
resource "datadog_service_definition_yaml" "backend" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = "chat-backend"
    team           = "team:chatbot"
    description    = "New updated description here"
    # ... other fields at root level
  })
}
```

```bash
terraform apply
```

### Add New Links

```hcl
links = [
  # Existing links...
  {
    name = "Grafana Dashboard"
    type = "other"
    url  = "https://grafana.yourcompany.com/d/backend"
  }
]
```

### Add Tags

```hcl
tags = [
  "env:${var.environment}",
  "service:${var.backend_service}",
  "managed_by:terraform",
  "new-tag:value"  # Add new tags here
]
```

---

## Benefits of Terraform Management

### Infrastructure as Code
- ✅ **Version controlled** with your codebase
- ✅ **Peer reviewed** via pull requests
- ✅ **Change history** in git
- ✅ **Reproducible** across environments

### Consistency
- ✅ **Same workflow** as other Datadog resources
- ✅ **Variable reuse** (service names, emails, etc.)
- ✅ **Automatic references** (dashboard IDs, etc.)
- ✅ **Dependency management** (creation order)

### Maintenance
- ✅ **Single source of truth** in Terraform
- ✅ **Preview changes** with `terraform plan`
- ✅ **Rollback support** via git/Terraform state
- ✅ **Automated deployment** in CI/CD

### Integration
- ✅ **Links to Terraform-created resources** (dashboards, monitors, SLOs)
- ✅ **Dynamic configuration** from variables
- ✅ **Consistent with team standards**

---

## Troubleshooting

### Entities not appearing?

```bash
# Check Terraform state
terraform state list | grep service_definition

# If resources exist but not visible in UI:
# 1. Wait 5-10 minutes for sync
# 2. Refresh Software Catalog page
# 3. Check filters (remove all filters to see all entities)
```

### Terraform plan shows changes every time?

This can happen with YAML encoding. Ensure:
- Consistent indentation
- No trailing whitespace
- Arrays vs single values are consistent

Use `yamlencode()` function to ensure proper formatting.

### Cannot find dashboard ID?

```bash
# Get dashboard ID from Terraform
cd terraform
terraform output dashboard_url

# The ID is in the URL after /dashboard/
# Example: https://app.datadoghq.com/dashboard/abc-123-xyz
# ID is: abc-123-xyz
```

### Schema validation errors?

Check that your schema version matches the provider expectations:
- Use `schema-version = "v2.2"` for Terraform compatibility
- Ensure `dd-service` field is present
- Don't nest fields under `spec` - all fields go at root level
- Required fields: `dd-service`, `team`, `application`, `description`

---

## Migration from API/GitHub

If you previously imported entities via API or GitHub:

### Option 1: Import into Terraform

```bash
cd terraform

# Import existing entities
terraform import datadog_service_definition_yaml.backend "chat-backend:v3"
terraform import datadog_service_definition_yaml.frontend "chat-frontend:v3"
# ... etc
```

### Option 2: Delete and Recreate

```bash
# Let Terraform recreate them (safer for demo environments)
terraform apply

# This will detect entities don't exist and create them
```

### Clean Up Old Entries

If you have duplicates, delete old entries:
1. Go to Software Catalog in Datadog UI
2. Find the old entity
3. Click "..." menu → Delete
4. Then run `terraform apply` to create managed version

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform
        env:
          DD_API_KEY: ${{ secrets.DD_API_KEY }}
          DD_APP_KEY: ${{ secrets.DD_APP_KEY }}
      
      - name: Terraform Plan
        run: terraform plan
        working-directory: ./terraform
        env:
          DD_API_KEY: ${{ secrets.DD_API_KEY }}
          DD_APP_KEY: ${{ secrets.DD_APP_KEY }}
      
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          DD_API_KEY: ${{ secrets.DD_API_KEY }}
          DD_APP_KEY: ${{ secrets.DD_APP_KEY }}
```

This ensures Software Catalog entities are deployed with infrastructure changes.

---

## Best Practices

### Keep It DRY
Use variables for repeated values:
```hcl
locals {
  common_tags = [
    "env:${var.environment}",
    "managed_by:terraform",
    "application:chatbot-demo"
  ]
  
  team_contact = {
    type    = "email"
    contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
  }
}

# Then reference in entities
tags = concat(local.common_tags, ["service:${var.backend_service}"])
```

### Use Comments
Document why entities are configured certain ways:
```hcl
# OpenAI is tier1 because it's an external critical dependency
# that affects our entire service availability
tier = "tier1"
```

### Link to Terraform Resources
Reference other Terraform resources when possible:
```hcl
# Good: Dynamic reference
url = "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.chatbot_overview.id}"

# Avoid: Hardcoded values
url = "https://app.datadoghq.com/dashboard/abc-123-xyz"
```

### Test Changes
Always preview changes:
```bash
terraform plan  # Review BEFORE applying
terraform apply # Then deploy
```

---

## Resources

- **Terraform File**: `terraform/software_catalog.tf`
- **Outputs**: Run `terraform output` to see entity info
- **Datadog Provider**: https://registry.terraform.io/providers/DataDog/datadog/latest/docs
- **Service Definition Resource**: https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/service_definition_yaml

---

**Status**: ✅ **Managed by Terraform!**

Your Software Catalog entities are now infrastructure as code, version controlled, and deployed consistently with your other Datadog resources.

