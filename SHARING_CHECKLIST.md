# 🚀 Pre-Share Safety Checklist

## ✅ Security Verification

### 1. Secrets Management
- [x] No API keys, tokens, or passwords in code
- [x] All secrets use Kubernetes Secrets or Terraform variables
- [x] `.gitignore` excludes `*.tfvars`, `.tfstate`, `.env` files
- [x] `terraform.tfvars.example` provided as template
- [x] Setup script prompts for secrets if missing

### 2. Files to Share (Safe)
```
✅ Source code (backend/, frontend/)
✅ Kubernetes manifests (k8s/*.yaml)
✅ Terraform configs (terraform/*.tf)
✅ Scripts (scripts/*.sh)
✅ Documentation (README.md, .gitignore)
✅ Example configs (terraform.tfvars.example)
```

### 3. Files Excluded (Sensitive - DO NOT COMMIT)
```
❌ terraform/terraform.tfvars (your actual keys)
❌ terraform/*.tfstate (Terraform state with secrets)
❌ terraform/.terraform/ (provider binaries)
❌ .env files (local overrides)
❌ k8s/secrets/ (if manually generated)
```

---

## 📝 Pre-Commit Steps

Before pushing to GitHub, verify:

```bash
# 1. Check git will NOT commit sensitive files
git status --ignored | grep -E "(tfvars|tfstate|.env)"
# Should show: !! terraform/terraform.tfvars (ignored)

# 2. Scan for accidental secrets
grep -r "sk-" . --exclude-dir=.git  # No OpenAI keys
grep -r "pub[a-z0-9]{32}" . --exclude-dir=.git  # No DD client tokens

# 3. Test setup script on clean clone (optional but recommended)
git clone <your-repo> /tmp/test-clone
cd /tmp/test-clone
./scripts/setup.sh  # Should prompt for all secrets
```

---

## 👥 For Team Members Cloning

### Prerequisites
- Docker Desktop with Kubernetes enabled
- Tools: `kubectl`, `helm`, `terraform`, `docker`
- Datadog account (US1 site)
- OpenAI API key

### Quick Setup
```bash
git clone <repo-url>
cd tem-sandbox

# Ensure Kubernetes is running
kubectl config use-context docker-desktop
kubectl get nodes  # Should show docker-desktop Ready

# Run automated setup (will prompt for secrets)
chmod +x scripts/setup.sh scripts/teardown.sh
./scripts/setup.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Build Docker images
3. ✅ Create namespace
4. ⚠️ **Prompt for secrets** (paste your keys here)
5. ✅ Deploy application
6. ✅ Deploy Datadog resources via Terraform
7. ✅ Output dashboard URL

### Manual Secret Creation (Alternative)
```bash
# Datadog
kubectl create secret generic datadog-keys -n chat-demo \
  --from-literal=api-key='<YOUR_DD_API_KEY>' \
  --from-literal=app-key='<YOUR_DD_APP_KEY>' \
  --from-literal=rum-client-token='<YOUR_DD_RUM_CLIENT_TOKEN>' \
  --from-literal=rum-app-id='<YOUR_DD_RUM_APP_ID>'

# OpenAI
kubectl create secret generic openai-key -n chat-demo \
  --from-literal=openai-api-key='<YOUR_OPENAI_API_KEY>'

# Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your values
```

---

## 🧪 Testing Checklist

After setup, verify:

```bash
# 1. All pods running
kubectl get pods -n chat-demo
# Should show: backend, frontend, postgres all Running

# 2. App accessible
open http://localhost:30080
# Should load chat UI

# 3. Send a test message
# Type "Hello" → Should get OpenAI response

# 4. Verify observability in Datadog
# - APM: traces.datadoghq.com → search service:chat-backend
# - Logs: logs.datadoghq.com → search service:chat-backend
# - RUM: rum.datadoghq.com → search service:chat-frontend
# - LLM Obs: llm.datadoghq.com → search chat-backend
# - DBM: dbm.datadoghq.com → search postgres

# 5. Check Terraform outputs
cd terraform
terraform output dashboard_url
# Open URL → Should show dashboard with data
```

---

## 🎯 What Makes This Demo Valuable

### For Customer Demonstrations
1. **End-to-End Observability**: RUM → APM → Logs → DBM all correlated
2. **Modern Stack**: K8s, AI/LLM, microservices
3. **Real Scenarios**: Latency tracking, error monitoring, cost optimization
4. **IaC Best Practices**: Terraform-managed monitors, SLOs, dashboards
5. **Service Management**: Ready for Incidents, Cases, Event Correlation demos

### Key Demo Flows
- **Trace a user action**: Click in RUM → APM trace → OpenAI span → DB query
- **Troubleshoot an error**: Monitor alert → Logs correlation → Root cause
- **Track LLM costs**: Dashboard → Token usage → Cost attribution
- **SLO burn rate**: Show degrading latency → SLO burn → Alert

---

## 🔧 Customization Points

Team members can easily customize:

```bash
# Change alert destinations
# Edit: terraform/terraform.tfvars
alert_email = "team@company.com"
alert_slack_channel = "@slack-devops"

# Add new monitors/SLOs
# Edit: terraform/monitors.tf, terraform/slos.tf
# Then: terraform apply

# Adjust app config
# Edit: k8s/*.yaml (resources, env vars, etc.)
# Then: kubectl apply -f k8s/
```

---

## 🧹 Cleanup

```bash
./scripts/teardown.sh
# Removes: K8s resources, Datadog monitors/SLOs, Helm release
# Optionally deletes Docker images
```

---

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| Pods CrashLoopBackOff | Check secrets: `kubectl logs -n chat-demo deploy/backend` |
| No data in Datadog | Verify API key: `kubectl get secret datadog-keys -n chat-demo -o yaml` |
| RUM not loading | Clear browser cache, rebuild frontend with RUM args |
| OpenAI errors | Check API key, quota, network |
| Terraform fails | Verify `terraform.tfvars` has all required variables |

---

## 📧 Support

For issues with this demo:
1. Check logs: `kubectl logs -n chat-demo deploy/<pod-name>`
2. Verify secrets are created correctly
3. Check Datadog Agent: `kubectl logs -n chat-demo -l app=datadog-agent`
4. Review README.md for manual setup steps

---

**Ready to share!** ✨

This demo is production-safe, secrets-free, and ready for team distribution.

