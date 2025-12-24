# Documentation Index

Quick reference to all documentation files in this repository.

## 📖 Main Documentation

**[README.md](README.md)** - Start here!
- Quick start guide
- Architecture overview
- Feature list
- Setup instructions

**[SHARING_CHECKLIST.md](SHARING_CHECKLIST.md)** - Before sharing with others
- Security verification
- Pre-commit checklist
- Team onboarding instructions

---

## 🔒 Security

**[SECURITY_SETUP.md](SECURITY_SETUP.md)** - Complete security guide
- ASM (Application Security Management) testing
- Cloud SIEM detection rules
- CSM (Cloud Security Management) features
- IAST (Interactive Application Security Testing)
- Code Security setup
- Demo scripts and examples

**What's covered:**
- ✅ Runtime threat detection (ASM, IAST)
- ✅ Log-based security alerts (Cloud SIEM)
- ✅ Container & K8s security (CSM)
- ✅ Vulnerability scanning (Code Security)

---

## 🧪 Synthetic Monitoring

**[PRIVATE_LOCATION_SETUP.md](PRIVATE_LOCATION_SETUP.md)** - Private Location guide
- 5-minute quick start
- Docker vs Kubernetes deployment
- Synthetic test configuration
- Troubleshooting

**Use cases:**
- ✅ Test localhost applications
- ✅ Monitor internal services
- ✅ Run tests behind firewall

---

## 📚 Software Catalog

**[SOFTWARE_CATALOG_TERRAFORM.md](SOFTWARE_CATALOG_TERRAFORM.md)** - Terraform management
- Entity definitions (system, services, datastore)
- Deployment with Terraform
- Customization guide
- Best practices

**What's defined:**
- System: `chatbot-demo-system`
- Services: `chat-backend`, `chat-frontend`, `openai-api`
- Datastore: `chat-postgres`
- Owner: `team:chatbot` (all entities)

---

## 🛠️ Scripts Reference

### Setup & Teardown
- **`scripts/setup.sh`** - Complete environment setup
- **`scripts/teardown.sh`** - Clean up all resources

### Security Testing
- **`scripts/test-security.sh`** - Interactive security feature testing
  - ASM attack simulation
  - SIEM alert triggering
  - CSM verification

### Synthetic Monitoring
- **`scripts/setup-private-location.sh`** - Deploy private location
  - Auto-detects architecture (ARM64 vs x86)
  - Supports Docker or Kubernetes Helm
  - Handles configuration automatically

---

## 📂 Directory Structure

```
datadog-chatbot-demo/
├── README.md                          # Main documentation
├── SECURITY_SETUP.md                  # Security features guide
├── PRIVATE_LOCATION_SETUP.md          # Private location guide
├── SOFTWARE_CATALOG_TERRAFORM.md      # Software Catalog guide
├── SHARING_CHECKLIST.md               # Pre-share checklist
├── DOCUMENTATION_INDEX.md             # This file
│
├── backend/                           # FastAPI backend
│   ├── app/main.py                    # Main application
│   ├── Dockerfile
│   └── requirements.txt
│
├── frontend/                          # Next.js frontend
│   ├── pages/
│   ├── Dockerfile
│   └── package.json
│
├── k8s/                               # Kubernetes manifests
│   ├── namespace.yaml
│   ├── backend.yaml
│   ├── frontend.yaml
│   ├── postgres.yaml
│   └── datadog-agent.yaml
│
├── terraform/                         # Infrastructure as code
│   ├── main.tf
│   ├── datadog_agent.tf              # Agent deployment
│   ├── monitors.tf                   # 6 monitors
│   ├── slos.tf                       # 3 SLOs
│   ├── dashboards.tf                 # Main dashboard
│   ├── synthetics.tf                 # 2 synthetic tests
│   ├── security_rules.tf             # 5 SIEM rules
│   ├── software_catalog.tf           # 5 catalog entities
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
└── scripts/                           # Automation scripts
    ├── setup.sh                       # Main setup
    ├── teardown.sh                    # Cleanup
    ├── test-security.sh               # Security testing
    └── setup-private-location.sh      # Private location
```

---

## 🔗 External Resources

### Datadog Documentation
- [APM](https://docs.datadoghq.com/tracing/)
- [RUM](https://docs.datadoghq.com/real_user_monitoring/)
- [LLM Observability](https://docs.datadoghq.com/llm_observability/)
- [Database Monitoring](https://docs.datadoghq.com/database_monitoring/)
- [Application Security](https://docs.datadoghq.com/security/application_security/)
- [Cloud SIEM](https://docs.datadoghq.com/security/cloud_siem/)
- [Cloud Security Management](https://docs.datadoghq.com/security/cloud_security_management/)
- [Synthetic Monitoring](https://docs.datadoghq.com/synthetics/)
- [Private Locations](https://docs.datadoghq.com/synthetics/private_locations/)
- [Software Catalog](https://docs.datadoghq.com/internal_developer_portal/software_catalog/)

---

## 💡 Quick Navigation

**Setting up from scratch?**
→ Start with [README.md](README.md) → Run `./scripts/setup.sh`

**Want to test security features?**
→ Read [SECURITY_SETUP.md](SECURITY_SETUP.md) → Run `./scripts/test-security.sh`

**Need private location for synthetic tests?**
→ Read [PRIVATE_LOCATION_SETUP.md](PRIVATE_LOCATION_SETUP.md) → Run `./scripts/setup-private-location.sh`

**Want to customize Software Catalog?**
→ Read [SOFTWARE_CATALOG_TERRAFORM.md](SOFTWARE_CATALOG_TERRAFORM.md) → Edit `terraform/software_catalog.tf`

**Sharing with team?**
→ Check [SHARING_CHECKLIST.md](SHARING_CHECKLIST.md) before committing

---

## 📝 Documentation Maintenance

### Adding New Documentation
- Keep focused on specific topics
- Link from README.md
- Update this index
- Include examples and troubleshooting

### Documentation Standards
- ✅ Clear headings and structure
- ✅ Code examples with syntax highlighting
- ✅ Step-by-step instructions
- ✅ Troubleshooting sections
- ✅ Links to official Datadog docs

---

**Last Updated:** 2025-12-24
**Repository:** https://github.com/Aziraphale81/datadog-chatbot-demo

