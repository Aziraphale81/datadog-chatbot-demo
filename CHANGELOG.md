# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2024-12-24

### Changed - OpenAI Model Upgrade
- **GPT-5-nano**: Upgraded from `gpt-4o-mini` to `gpt-5-nano`
  - **67% cheaper input** tokens ($0.15 → $0.05 per 1M tokens)
  - **33% cheaper output** tokens ($0.60 → $0.40 per 1M tokens)
  - **3x larger context** window (128K → 400K tokens)
  - **Faster** response times
  - Updated API parameter from `max_tokens` to `max_completion_tokens` for GPT-5 compatibility

### Changed - Monitor Threshold Adjustments
- **Backend Error Rate Monitor**: Fixed incorrect query and adjusted thresholds
  - Changed from `.as_rate()` (errors/sec) to `.as_count()` (total errors in window)
  - Critical: 20 errors in 5 minutes (was 0.05 errors/sec - meaningless)
  - Warning: 10 errors in 5 minutes (was 0.02 errors/sec - meaningless)
- **Backend Latency Monitor**: Relaxed thresholds to account for OpenAI API latency
  - Critical: 5 seconds (was 2s - too tight for LLM calls)
  - Warning: 3 seconds (was 1.5s)
  - Added note about OpenAI API response times in alert message

### Added - ChatGPT-Style UI
- **Complete UI Overhaul**: Redesigned frontend with modern ChatGPT-style interface
  - **Sidebar** with session history and "New chat" button
  - **Session Management**: Multi-session support with persistent history
  - **Markdown Rendering**: Full markdown support with syntax highlighting
  - **Auto-scrolling**: Automatically scrolls to latest messages
  - **Responsive Design**: Mobile-friendly with hamburger menu
- **Backend Session API**: New endpoints for session management
  - `POST /sessions` - Create new session
  - `GET /sessions` - List all sessions
  - `GET /sessions/{id}` - Get specific session
  - `DELETE /sessions/{id}` - Delete session
  - `GET /sessions/{id}/messages` - Get session messages
  - `POST /sessions/{id}/generate-title` - AI-generated session titles
  - `PUT /sessions/{id}/title` - Update session title
- **Database Schema Updates**: Added `sessions` table with migration logic
  - Automatic migration on startup for existing deployments
  - Session ID foreign key on `chat_messages` table

### Changed - Browser Synthetic Test
- **Revamped for New UI**: Completely rebuilt browser test for ChatGPT-style interface
  - Updated all CSS selectors for new component structure
  - Added multi-turn conversation testing (2 messages + responses)
  - Includes sidebar session verification (optional step)
  - Increased timeout for send actions to handle OpenAI latency (20s)
  - All steps now use correct element selectors (textarea, .user-message, .assistant-message)

### Added - Inferred Services
- **Service Override Removal**: Enabled `DD_TRACE_REMOVE_INTEGRATION_SERVICE_NAMES_ENABLED=true`
  - Uses modern inferred services approach
  - Cleaner service maps and lists
  - Database and external services automatically inferred from span attributes
  - Follows Datadog best practices per [service overrides documentation](https://docs.datadoghq.com/tracing/guide/service_overrides/)

### Added - Browser Synthetic Test
- **User Journey Test**: Added Browser test to simulate real user interactions
  - Navigates to chat page
  - Types a message and clicks send
  - Waits for AI response
  - Validates successful interaction
  - Runs every 15 minutes on private location
  - **Dual Purpose**: Synthetic monitoring + RUM traffic generator
  - Creates continuous observability data across entire stack (RUM → APM → LLM → DBM → NPM)

### Added - Network Performance Monitoring
- **NPM Documentation**: Added Cloud Network Monitoring to README
  - Shows service-to-service network flows and latencies
  - Tracks TCP metrics (retransmits, failures, connections/s)
  - Visualizes all Datadog intake endpoints
  - Demonstrates complete observability stack

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

