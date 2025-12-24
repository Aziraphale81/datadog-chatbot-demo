# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2024-12-24

### Added - Software Catalog Integration
- **Software Catalog Entities**: Created 4 service definitions managed by Terraform
  - `chat-backend`: Backend API service with APM, LLM Observability, ASM, IAST
  - `chat-frontend`: Frontend UI service with RUM and Session Replay
  - `chat-postgres`: Database datastore with DBM
  - `openai-api`: External AI service dependency
- **System Entity**: Manual UI-managed system entity (`chatbot-demo-system`) grouping all components
- **Standardized Ownership**: All entities owned by `team:chatbot`
- **Documentation**: Added `SOFTWARE_CATALOG_TERRAFORM.md` with full setup guide
- **Entity Definition**: Added `system-entity-definition.json` for reference

### Changed - Service Naming Standardization
- **Postgres Service Name**: Renamed from `postgres` to `chat-postgres` for consistency
  - Added `DD_SERVICE=chat-postgres` environment variable to postgres deployment
  - Updated `POSTGRES_DSN` in backend to use `chatbot` database
  - Updated Software Catalog tags to match
- **Database Configuration**: Backend now connects to `chatbot` database instead of default `postgres`

### Added - Documentation Improvements
- **Documentation Index**: Created `DOCUMENTATION_INDEX.md` as central navigation hub
- **Consolidated Docs**: Merged private location quick start into main setup guide
- **Improved Structure**: Better organization of security, synthetic, and catalog docs

### Removed - Documentation Cleanup
- Deleted temporary implementation notes and summaries:
  - `SECURITY_CHANGES_SUMMARY.md`
  - `PRIVATE_LOCATION_SUMMARY.md`
  - `IMPROVEMENTS_SUMMARY.md`
  - `SOFTWARE_CATALOG_SUMMARY.md`
  - `SOFTWARE_CATALOG_SETUP.md`
  - `SYNTHETIC_TESTS_TUNING.md`
  - `PRIVATE_LOCATION_QUICK_START.md`
  - `SERVICE_NAMING_UPDATE.md`
- Removed unused Kubernetes manifests:
  - `k8s/synthetics-private-location.yaml` (using Helm instead)
- Removed deprecated scripts:
  - `scripts/import-catalog-entities.sh` (using Terraform instead)
  - `scripts/rebuild-and-deploy.sh` (one-off helper)
- Removed backup files:
  - `terraform/dashboards.tf.bak`
- Removed obsolete entity definition:
  - `entity.datadog.yaml` (using Terraform instead)


### Fixed - Database Issues
- Fixed database initialization after PVC recreation
- Created proper `chat_messages` table schema
- Added `datadog` monitoring user with correct permissions
- Granted proper access for DBM

### Technical Details
- **Schema Version**: Using v2.2 for Software Catalog (v3.0 not yet fully supported in Terraform)
- **Service Tags**: Consistent tagging across all components
- **Team Ownership**: Standardized to `team:chatbot` across monitors, SLOs, and services
- **Application Tag**: All resources tagged with `application:chatbot-demo`

---

## Previous Changes

See git history for changes prior to Software Catalog integration.

### Highlights from Previous Sessions:
- ✅ Full security stack (ASM, IAST, Cloud SIEM, CSM)
- ✅ Private location for synthetic testing
- ✅ Markdown rendering in frontend
- ✅ IAST runtime code analysis
- ✅ Response truncation fixes
- ✅ Synthetic test tuning for local testing
- ✅ Comprehensive monitoring and alerting
- ✅ LLM Observability for OpenAI integration
- ✅ Database Monitoring with query samples
- ✅ RUM with Session Replay

---

## Commit Guidelines

When committing these changes, use the following format:

```
feat: Add Software Catalog integration with Terraform

- Create 4 service definitions (backend, frontend, postgres, openai)
- Standardize service naming to chat-postgres
- Add comprehensive documentation (SOFTWARE_CATALOG_TERRAFORM.md)
- Clean up temporary docs and unused files
- Fix database configuration for chatbot database
- Add system entity definition for UI management

BREAKING CHANGE: Postgres service renamed from 'postgres' to 'chat-postgres'
```

