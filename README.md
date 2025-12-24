# Local Chatbot + Datadog on Docker Desktop Kubernetes

Minimal FastAPI + Postgres backend and Next.js frontend, fully instrumented with Datadog (APM, Logs, Metrics, RUM, DBM, LLM Observability, Profiler, Processes, Orchestrator Explorer, **Application Security, Cloud SIEM, Cloud Security Management**). Runs on the Docker Desktop Kubernetes cluster in a single namespace (`chat-demo`), exposed via NodePort.

All Datadog resources (monitors, SLOs, dashboards, synthetics, security rules) are managed via Terraform for easy version control and team sharing.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/1dd5cc07-409f-4f06-a88b-43010b8a8123" />

## Quick Start (Automated)

```bash
# Make setup script executable
chmod +x scripts/setup.sh scripts/teardown.sh

# Run setup (will prompt for secrets if not found)
./scripts/setup.sh
```

This script will:
1. Build Docker images for backend and frontend
2. Create Kubernetes namespace
3. Prompt for secrets if not already created
4. Deploy application stack (Postgres, backend, frontend)
5. Deploy Datadog Agent via Terraform
6. Create monitors, SLOs, dashboards, and synthetic tests

After setup completes, access the app at `http://localhost:30080`.

---

## Manual Setup

If you prefer step-by-step control:

### 1) Create namespace and secrets

```bash
kubectl apply -f k8s/namespace.yaml

kubectl create secret generic datadog-keys -n chat-demo \
  --from-literal=api-key='<DD_API_KEY>' \
  --from-literal=app-key='<DD_APP_KEY>' \
  --from-literal=rum-client-token='<DD_RUM_CLIENT_TOKEN>' \
  --from-literal=rum-app-id='<DD_RUM_APP_ID>'

kubectl create secret generic openai-key -n chat-demo \
  --from-literal=openai-api-key='<OPENAI_API_KEY>'
```

### 2) Build Docker images

```bash
docker build -t chat-backend:latest ./backend

# Frontend needs RUM credentials at build time
export DD_RUM_CLIENT_TOKEN=$(kubectl get secret datadog-keys -n chat-demo -o jsonpath='{.data.rum-client-token}' | base64 -d)
export DD_RUM_APP_ID=$(kubectl get secret datadog-keys -n chat-demo -o jsonpath='{.data.rum-app-id}' | base64 -d)

docker build -t chat-frontend:latest \
  --build-arg NEXT_PUBLIC_DD_CLIENT_TOKEN=$DD_RUM_CLIENT_TOKEN \
  --build-arg NEXT_PUBLIC_DD_APP_ID=$DD_RUM_APP_ID \
  --build-arg NEXT_PUBLIC_DD_SITE=datadoghq.com \
  --build-arg NEXT_PUBLIC_DD_SERVICE=chat-frontend \
  --build-arg NEXT_PUBLIC_DD_ENV=demo \
  --build-arg NEXT_PUBLIC_DD_VERSION=1.0.0 \
  --build-arg BACKEND_INTERNAL_BASE=http://backend.chat-demo.svc.cluster.local:8000 \
  ./frontend
```

### 3) Deploy app stack

```bash
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
```

### 4) Deploy Datadog resources via Terraform

```bash
cd terraform

# Copy example tfvars and fill in your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Datadog API/App keys

# Initialize and apply
terraform init
terraform plan
terraform apply
```

This will:
- Deploy Datadog Agent via Helm (with ASM, CSM, and all security features)
- Create 6 monitors (latency, errors, OpenAI, RUM, DB, K8s)
- Create 3 SLOs (backend availability/latency, frontend error rate)
- Create 5 Cloud SIEM detection rules
- Create a comprehensive dashboard
- Create 2 synthetic tests (frontend uptime, backend health)

### 5) Access the application

```bash
# Frontend is exposed on NodePort 30080
open http://localhost:30080

# View your dashboard
terraform -chdir=terraform output -raw dashboard_url
```

---

## What's Included

### Application Stack
- **Backend**: FastAPI with OpenAI integration, Postgres persistence
- **Frontend**: Next.js with RUM + Session Replay
- **Database**: Postgres with DBM enabled
- **Kubernetes**: Single namespace deployment on Docker Desktop

### Datadog Observability (Full Stack)
- ✅ **APM**: Distributed traces for FastAPI → OpenAI → Postgres
- ✅ **Logs**: JSON structured logs with trace correlation
- ✅ **DBM**: Postgres query samples and execution plans
- ✅ **RUM**: Browser telemetry, Session Replay, dummy user tracking
- ✅ **LLM Observability**: OpenAI prompts, completions, tokens, latency
- ✅ **Profiler**: Python continuous profiling
- ✅ **Processes**: Live process monitoring
- ✅ **Orchestrator Explorer**: K8s resource visibility
- ✅ **Metrics**: Infrastructure and custom business metrics

### Datadog Security (Full Platform)
- ✅ **Application Security (ASM)**: Runtime threat detection, attack blocking, vulnerability management
- ✅ **Code Security**: SAST scanning for vulnerabilities in code and dependencies
- ✅ **Cloud SIEM**: Log-based security threat detection with 5 custom rules
- ✅ **CSM Threats**: Runtime container security monitoring
- ✅ **CSM Misconfigurations**: Kubernetes security posture management
- ✅ **Container Vulnerabilities**: Docker image CVE scanning

### Terraform-Managed Resources
- **6 Monitors**: Backend latency/errors, OpenAI failures, RUM errors, DB slow queries, K8s restarts
- **3 SLOs**: Backend availability (99.5%), backend latency (p95 < 2s), frontend error-free sessions (99%)
- **1 Dashboard**: Comprehensive overview with APM, LLM, DBM, RUM, K8s sections
- **2 Synthetic Tests**: Frontend uptime check, backend health check (supports private location)
- **5 SIEM Rules**: High error rate, SQL injection, OpenAI abuse, container escape, DB auth failures
- **Datadog Agent**: Deployed via Helm with full observability + security config
- **Private Location** (optional): Run synthetic tests against localhost apps

---

## Teardown

To completely remove all resources:

```bash
./scripts/teardown.sh
```

Or manually:

```bash
cd terraform && terraform destroy
kubectl delete namespace chat-demo
helm uninstall datadog-agent -n chat-demo
```

---

## For Team Members / GitHub Sharing

### Prerequisites
- Docker Desktop with Kubernetes enabled
- kubectl, helm, terraform installed
- Datadog account (US1) with API key, App key, RUM credentials
- OpenAI API key

### Setup from Clone
1. Clone this repo
2. Ensure Docker Desktop Kubernetes is running
3. Run `./scripts/setup.sh` and follow prompts for secrets
4. Access `http://localhost:30080`
5. View dashboard URL from `terraform output -raw dashboard_url`

### Customization
- Monitors/SLOs/Dashboards: Edit `terraform/*.tf` files and re-apply
- Alert destinations: Set `alert_email` and `alert_slack_channel` in `terraform/terraform.tfvars`
- App config: Modify `k8s/*.yaml` manifests and `kubectl apply`

---

## Production Readiness

This sandbox is optimized for **demos and learning**. For production deployments, consider these adjustments:

### **Observability Configuration**

| Component | Demo Setting | Production Recommendation |
|-----------|--------------|---------------------------|
| **RUM Sampling** | 100% | 20-30% (cost optimization) |
| **Session Replay** | 100% | 10-20% (cost optimization) |
| **Log Indexing** | All logs indexed | Exclude debug logs, use sampling for high-volume services |
| **APM Sampling** | Default (100%) | Adjust ingestion rate based on traffic volume |
| **Synthetics** | Single location | 2-3 locations for geographic coverage |
| **Synthetic Frequency** | 5 minutes | 1-5 minutes based on criticality |

### **Monitor Configuration**

- **Adjust thresholds** based on your SLAs and traffic patterns
- **Add composite monitors** for complex failure scenarios (e.g., high latency AND high error rate)
- **Configure downtime schedules** for planned maintenance
- **Set up escalation policies** with PagerDuty/OpsGenie integration
- **Review alert fatigue** - add `min_failure_duration` to prevent flapping

### **Tagging Strategy**

Add these production tags:
```yaml
- cost_center: "engineering"      # For cost allocation
- owner: "team-name"               # Clear ownership
- criticality: "tier1"             # SLA classification
- DD_VERSION: "git-sha"            # Track deployments
```

### **Security Hardening**

- **Secrets Management**: Use AWS Secrets Manager, HashiCorp Vault, or sealed-secrets instead of plain K8s Secrets
- **Network Policies**: Restrict pod-to-pod communication
- **RBAC**: Limit Datadog Agent permissions to only required namespaces
- **Log Scrubbing**: Configure sensitive data scrubbing rules (credit cards, PII, API keys)
- **TLS**: Enable TLS for external endpoints

### **Scalability Considerations**

- **Resource Limits**: Adjust CPU/memory requests and limits based on load testing
- **HPA (Horizontal Pod Autoscaler)**: Add autoscaling for backend/frontend pods
- **Database**: Use managed Postgres (RDS, Cloud SQL) with automated backups
- **Datadog Agent**: Consider cluster agent for improved performance at scale
- **Connection Pooling**: Tune Postgres connection pool sizes

### **Cost Optimization**

- **Log Exclusion Filters**: Aggressively filter noisy logs (health checks, debug logs)
- **Log Sampling**: Sample high-volume logs (1 in 10 or 1 in 100)
- **Index Configuration**: Use multiple indexes with different retention periods
- **Metric Cardinality**: Monitor and limit high-cardinality tags
- **Synthetic Test Budget**: Limit test frequency for non-critical endpoints

### **Synthetic Tests**

⚠️ **For Local Testing**: Set up a Private Location to test your localhost app.

**Quick Setup:**
1. Create Private Location in Datadog UI
2. Run: `./scripts/setup-private-location.sh /path/to/config.json`
3. Add Private Location ID to `terraform/terraform.tfvars`
4. Run: `terraform apply`

See [PRIVATE_LOCATION_SETUP.md](PRIVATE_LOCATION_SETUP.md) for detailed instructions.

**For Production:**
1. Deploy app with public endpoint or Private Location in production environment
2. Update `terraform/synthetics.tf` with real URLs
3. Add multi-step API tests for critical user journeys
4. Consider browser tests for complex UI interactions

### **Deployment Tracking**

Correlate deployments with performance changes:
1. Set `DD_VERSION` to git SHA or semantic version
2. Use Deployment Tracking API to mark releases
3. Create deployment markers on dashboards
4. Set up deployment-triggered monitors

---

## Demo Use Cases

This sandbox demonstrates:
- **End-to-end observability**: RUM → APM → Logs → DBM correlation
- **Service Management**: Monitors → Incidents → Case Management
- **SLO tracking**: Availability and latency SLOs with burn rate alerts
- **LLM monitoring**: OpenAI usage, costs, latency, errors
- **Kubernetes observability**: Orchestrator Explorer, resource utilization
- **Synthetic monitoring**: Proactive uptime checks
- **Application security**: Runtime threat detection, attack blocking (ASM)
- **Code security**: Vulnerable dependency scanning, SAST analysis
- **Cloud SIEM**: Log-based threat detection, security analytics
- **Cloud security**: Container vulnerabilities, runtime threats, compliance

---

## 🔒 Security Features

This demo includes **full Datadog Security Platform**:

### Quick Start
See [SECURITY_SETUP.md](SECURITY_SETUP.md) for detailed setup and demo instructions.

### What's Included

**Application Security Management (ASM)**
- ✅ Enabled automatically
- Detects SQL injection, XSS, RCE, SSRF attacks
- Test with: `curl -X POST http://localhost:30080/api/chat -d '{"prompt":"Hello'\'' OR 1=1--"}'`

**Code Security (SAST)**
- ⚠️ Requires GitHub integration (one-time setup)
- Scans Python/JavaScript code for vulnerabilities
- Detects vulnerable dependencies in requirements.txt and package.json

**Cloud SIEM**
- ✅ Enabled automatically with 5 detection rules
- Monitors for: High error rates, SQL injection, OpenAI abuse, container escapes, DB auth failures
- View signals: [Security Signals Explorer](https://app.datadoghq.com/security)

**Cloud Security Management (CSM)**
- ✅ Enabled automatically
- **CSM Threats**: Runtime container security
- **CSM Misconfigurations**: K8s security posture (CIS benchmarks)
- **Container Vulnerabilities**: Docker image CVE scanning

### Demo Flow
```bash
# 1. Send attack payload (ASM will detect)
curl -X POST http://localhost:30080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello'\'' OR 1=1--"}'

# 2. Trigger SIEM alert (high error rate)
for i in {1..60}; do curl http://localhost:30080/nonexistent; done

# 3. View results
open https://app.datadoghq.com/security
```

See [SECURITY_SETUP.md](SECURITY_SETUP.md) for complete testing guide.

---

## Local Development (Optional)

### Backend
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

DD_API_KEY=xxx DD_SITE=datadoghq.com DD_ENV=dev \
OPENAI_API_KEY=zzz \
POSTGRES_DSN=postgresql://postgres:postgres@localhost:5432/postgres \
ddtrace-run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend
```bash
cd frontend
npm install

# Create .env.local with:
# NEXT_PUBLIC_DD_CLIENT_TOKEN=your_rum_client_token
# NEXT_PUBLIC_DD_APP_ID=your_rum_app_id
# NEXT_PUBLIC_DD_SITE=datadoghq.com
# NEXT_PUBLIC_DD_SERVICE=chat-frontend
# NEXT_PUBLIC_DD_ENV=dev
# BACKEND_INTERNAL_BASE=http://localhost:8000

npm run dev
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Desktop Kubernetes                     │
│                                                                   │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐   │
│  │  Frontend   │───▶│   Backend    │───▶│   Postgres      │   │
│  │  (Next.js)  │    │  (FastAPI)   │    │   (DBM)         │   │
│  │  NodePort   │    │              │───▶│                 │   │
│  │  :30080     │    │              │    │   OpenAI API    │   │
│  └─────────────┘    └──────────────┘    └─────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Datadog Agent (DaemonSet)                      │  │
│  │   APM • Logs • DBM • Metrics • Profiler • Processes      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Datadog US1     │
                    │  • Monitors      │
                    │  • SLOs          │
                    │  • Dashboards    │
                    │  • Synthetics    │
                    │  • RUM           │
                    │  • LLM Obs       │
                    └──────────────────┘
```
