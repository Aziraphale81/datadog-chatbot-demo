# Security Features Setup Guide

This demo includes comprehensive security monitoring across Application Security, Code Security, Cloud SIEM, and Cloud Security Management.

## 🔒 Security Products Enabled

### ✅ 1. Application Security Management (ASM)
**Status**: Automatically enabled via Terraform

ASM is already configured and will start detecting threats as soon as the app is deployed.

**What it monitors:**
- SQL injection attempts
- XSS (Cross-Site Scripting) attacks
- Server-Side Request Forgery (SSRF)
- Remote Code Execution (RCE) attempts
- Authentication/authorization bypass
- Suspicious user activity

**To view ASM data:**
1. Go to [Datadog Security → Application Security](https://app.datadoghq.com/security/appsec)
2. Check **Security Signals** for detected attacks
3. Review **Traces** with security flags
4. Explore **Attacker Explorer** to see threat actors

**Testing ASM (safe attacks for demo):**
```bash
# Simulate SQL injection attempt
curl -X POST http://localhost:30080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello' OR '1'='1"}'

# Simulate XSS attempt
curl -X POST http://localhost:30080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "<script>alert(1)</script>"}'
```

ASM will detect and flag these attempts (may block depending on configuration).

---

### ✅ 2. Code Security (SAST)
**Status**: Requires GitHub/GitLab integration (one-time setup)

Code Security scans your repositories for vulnerabilities, code quality issues, and secrets.

#### Setup Steps:

1. **Enable Code Security in Datadog:**
   - Navigate to [Security → Code Security → Setup](https://app.datadoghq.com/security/code-security/setup)
   - Click **"Connect a Repository"**

2. **Install GitHub Integration:**
   - Choose **GitHub** (or GitLab/Bitbucket)
   - Authorize Datadog GitHub App
   - Select repositories to scan (or grant access to all)

3. **Configure Repository:**
   - Select this repository: `your-org/datadog-chatbot-demo`
   - Click **"Enable Code Security"**
   - Optionally enable PR comments for vulnerabilities

4. **Trigger Initial Scan:**
   - Push a commit or manually trigger scan
   - Wait 2-5 minutes for results

5. **View Results:**
   - Go to [Security → Code Security → Vulnerabilities](https://app.datadoghq.com/security/code-security/vulnerabilities)
   - Review:
     - **Vulnerabilities**: Code-level security issues
     - **Libraries**: Vulnerable dependencies (Python/npm packages)
     - **Secrets**: Accidentally committed credentials (if any)
     - **Code Quality**: Best practices violations

#### What Code Security Will Find:

**Backend (Python):**
- Vulnerable packages in `requirements.txt` (e.g., outdated `openai`, `fastapi`, `psycopg`)
- SQL injection risks
- Insecure random number generation
- Hardcoded secrets (if any)
- Insecure dependencies

**Frontend (JavaScript):**
- Vulnerable npm packages in `package.json` (e.g., React, Next.js vulnerabilities)
- XSS risks
- Prototype pollution
- Insecure dependencies

**Expected Findings** (examples):
- `psycopg` or `asyncpg` older versions with CVEs
- `next` framework vulnerabilities
- Missing security headers
- Weak cryptography usage

#### Enable PR Comments (Optional):
1. Go to repository settings in Code Security
2. Enable **"Comment on Pull Requests"**
3. New PRs will show inline vulnerability comments

---

### ✅ 3. Cloud SIEM
**Status**: Automatically enabled via Terraform

Cloud SIEM rules are deployed and monitoring your logs for security threats.

**Detection Rules Created:**
1. **High Rate of API Errors**: Detects potential brute force or scanning attacks
2. **SQL Injection Attempts**: Flags SQL injection patterns in requests
3. **Unusual OpenAI Usage**: Detects API abuse or cost anomalies
4. **Suspicious Container Activity**: Flags potential container escapes
5. **Database Auth Failures**: Detects credential stuffing attacks

**To view SIEM signals:**
1. Go to [Security → Security Signals Explorer](https://app.datadoghq.com/security)
2. Filter by `env:demo` or `service:chat-backend`
3. Investigate triggered signals
4. Review attacker IP addresses and patterns

**Triggering SIEM Alerts (for demo):**
```bash
# Trigger high error rate alert
for i in {1..60}; do
  curl http://localhost:30080/nonexistent-endpoint
done

# Trigger OpenAI abuse alert (send many requests)
for i in {1..150}; do
  curl -X POST http://localhost:30080/api/chat \
    -H "Content-Type: application/json" \
    -d '{"prompt": "Hello world"}'
done
```

---

### ✅ 4. Cloud Security Management (CSM)
**Status**: Automatically enabled via Terraform

CSM includes three sub-products:

#### a) **CSM Threats** (Runtime Security)
- Monitors process execution in containers
- Detects file access anomalies
- Flags privilege escalation attempts
- Identifies network anomalies

**To view threats:**
- Go to [Security → CSM Threats](https://app.datadoghq.com/security/csm)
- Review **Runtime Security Signals**

**Testing (advanced):**
```bash
# Exec into backend pod and run suspicious command
kubectl exec -it -n chat-demo deployment/backend -- /bin/bash
# Inside pod: try installing packages, network tools, etc.
```

#### b) **CSM Misconfigurations** (CSPM)
- Scans Kubernetes resources for security misconfigurations
- Checks compliance against CIS benchmarks
- Identifies exposed secrets, privileged containers

**What it checks:**
- Containers running as root
- Missing resource limits
- Exposed services
- Insecure RBAC policies
- Secrets in plain text

**To view findings:**
- Go to [Security → CSM → Misconfigurations](https://app.datadoghq.com/security/csm/misconfigurations)
- Filter by `kube_cluster_name:docker-desktop`

**Expected Findings:**
- Backend/frontend may be running without `readOnlyRootFilesystem`
- Missing `runAsNonRoot: true`
- Privileged pods (Datadog agent system-probe)

#### c) **Container Image Vulnerabilities**
- Scans Docker images for CVEs
- Identifies vulnerable packages in container layers
- Tracks base image vulnerabilities

**To view vulnerabilities:**
- Go to [Security → CSM → Container Images](https://app.datadoghq.com/security/csm/container-images)
- Review `chat-backend:latest` and `chat-frontend:latest`

**Expected Findings:**
- Python base image CVEs (if using outdated Python image)
- Node.js base image CVEs (if using outdated Node image)
- OS package vulnerabilities (apt packages in Debian/Ubuntu base)

---

## 🎯 Quick Demo Flow

**Show the full security stack in 5 minutes:**

1. **Start with Code Security:**
   - Show vulnerable dependencies in both repos
   - Highlight CVE details and remediation steps

2. **Deploy and trigger ASM:**
   ```bash
   # Send attack payloads
   curl -X POST http://localhost:30080/api/chat -H "Content-Type: application/json" \
     -d '{"prompt": "Hello'\'' OR 1=1--"}'
   ```
   - Show detected attack in ASM Security Signals
   - Explore attacker IP and user context

3. **Trigger SIEM alerts:**
   ```bash
   # Send 100 errors
   for i in {1..100}; do curl http://localhost:30080/nonexistent; done
   ```
   - Show "High Rate of API Errors" signal in SIEM

4. **Review CSM Threats:**
   - Show container runtime monitoring
   - Highlight any misconfigurations found

5. **Show Container Vulnerabilities:**
   - Navigate to container images
   - Show CVEs in base images

---

## 📊 Security Dashboards

All security data is visible in:
- **Main Dashboard**: `terraform output -raw dashboard_url`
- **Security → Application Security**: ASM traces and signals
- **Security → Cloud SIEM**: All security signals
- **Security → CSM**: Cloud security posture and threats

---

## 🔧 Troubleshooting

### ASM not showing data?
- Verify `DD_APPSEC_ENABLED=true` in backend pod: `kubectl get deployment backend -n chat-demo -o yaml`
- Check agent logs: `kubectl logs -n chat-demo -l app=datadog-agent -c agent`
- Send test attack payloads (see above)

### Code Security not scanning?
- Ensure GitHub integration is installed and authorized
- Check repository permissions (Datadog needs read access)
- Manually trigger scan in UI

### SIEM rules not triggering?
- Verify log collection is working: Check [Logs Explorer](https://app.datadoghq.com/logs)
- Ensure logs have required attributes (`service`, `env`, `http.status_code`)
- Rules have evaluation windows (5-15 min), so wait before expecting signals

### CSM showing no data?
- Verify security-agent is running: `kubectl get pods -n chat-demo -l app=datadog-agent`
- Check system-probe logs: `kubectl logs -n chat-demo -l app=datadog-agent -c system-probe`
- CSM requires privileged access (already configured in Terraform)

---

## 🚨 Production Considerations

This demo enables **all security features at maximum sensitivity** for learning purposes.

**For production:**
1. **ASM**: Tune detection rules to reduce false positives
2. **Code Security**: Enable PR blocking for critical vulnerabilities
3. **SIEM**: Adjust thresholds based on normal traffic patterns
4. **CSM**: Focus on critical misconfigurations, suppress low-risk findings
5. **Alerting**: Route security signals to PagerDuty/Slack/email with appropriate severity

**Cost Optimization:**
- Code Security: Free (up to 5 committers)
- ASM: Pay per traced request with ASM analysis
- SIEM: Pay per analyzed log
- CSM: Pay per host for runtime security

Adjust sampling rates and log exclusions to manage costs in production.

---

## 📚 Additional Resources

- [ASM Documentation](https://docs.datadoghq.com/security/application_security/)
- [Code Security Documentation](https://docs.datadoghq.com/security/code_security/)
- [Cloud SIEM Documentation](https://docs.datadoghq.com/security/cloud_siem/)
- [CSM Documentation](https://docs.datadoghq.com/security/cloud_security_management/)
- [Security Signals Explorer](https://app.datadoghq.com/security)


