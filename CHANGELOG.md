# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- **Synthetic Test Intervals**: Reduced test frequency to minimize cost and APM noise
  - Frontend Uptime Check: 5 minutes → **1 hour**
  - Backend API Check: 5 minutes → **1 hour**, response timeout 10s → **40s** (for slow OpenAI responses)
  - Browser test already at 1 hour (no change)
- **Kubernetes Health Probes**: Reduced frequency for demo environment
  - Backend readiness probe: 1 minute → **5 minutes** (filtered by `DD_TRACE_IGNORE_RESOURCE_NAMES`)
  - Airflow liveness probe: 30s → **5 minutes**
  - Airflow readiness probe: 10s → **1 minute**
  - Added `DD_TRACE_IGNORE_RESOURCE_NAMES="GET /health"` to Airflow deployment
- **Airflow Startup**: Simplified to webserver-only (no scheduler auto-start)
  - Fixes `CrashLoopBackOff` issues with LocalExecutor + startup timeouts
  - DAGs can be triggered manually via Airflow UI at `localhost:30808`
  - Scheduler caused 120s timeout and continuous pod restarts
- **Airflow Metrics (StatsD)**: Configured Airflow to send metrics to Datadog Agent
  - Added `AIRFLOW__METRICS__STATSD_ON=True`
  - Configured `AIRFLOW__METRICS__STATSD_HOST` to use DD_AGENT_HOST
  - Set `AIRFLOW__METRICS__STATSD_PORT=8125` (DogStatsD default)
  - Prefix: `airflow.*` (e.g., `airflow.dagrun.duration`, `airflow.executor.open_slots`)
  - Metrics appear after DAG runs (manual triggers work fine)

### Added
- **Cleanup Script**: New `scripts/cleanup-datadog-v2.sh` for API-based Datadog resource cleanup
  - Handles orphaned resources when `terraform destroy` fails
  - Deletes monitors, SLOs, security rules (Cloud SIEM), and synthetic tests by name pattern
  - Uses Python JSON parsing for reliable API response handling
  - Shows what's being deleted (names and IDs) before deletion
  - Requires DD_API_KEY and DD_APP_KEY environment variables
- **Documentation**: New `CLEANUP_GUIDE.md` with instructions for handling failed teardowns

### Changed
- **Teardown Script**: Improved `scripts/teardown.sh` robustness
  - Better error handling when `terraform destroy` fails (TLS/network issues)
  - Offers to run API-based cleanup script (v2) as fallback
  - Handles new resources: worker, rabbitmq, airflow deployments
  - Improved prompts and recovery options
  - Cleans up `.terraform.lock.hcl` for fresh state
  - Now properly removes security monitoring rules (Cloud SIEM)
- **Dashboard**: Updated Terraform dashboard to use `datadog_dashboard_json` resource
  - Imported user's manual UI customizations from Datadog export
  - Added DSM and DJM widget groups with RabbitMQ and Airflow metrics
  - Cleaner Terraform code using JSON encoding instead of nested HCL blocks
- **BREAKING**: Migrated from `pika` to `kombu` for RabbitMQ integration
  - `pika` is not instrumented by ddtrace and provides no DSM support
  - `kombu` is officially supported by Datadog for DSM auto-instrumentation
  - Created `messaging.py` helper module for clean Kombu integration
  - Updated backend and worker to use Kombu producers/consumers
  - DSM now works automatically via `DD_DATA_STREAMS_ENABLED=true` + Kombu
- Enabled explicit Kombu patching: `patch(kombu=True)` in backend and worker
- Added `python-dotenv` and `psycopg[binary]` to worker requirements

### Fixed
- **Critical**: Fixed JSON deserialization bug in Kombu message consumer
  - Kombu with `accept=['json']` auto-deserializes message bodies to dict
  - Removed redundant `json.loads()` call that was causing `TypeError`
  - Worker now correctly processes chat requests and publishes responses
- **Partial**: Fixed DSM message serialization for context propagation
  - Changed `producer.publish()` to pass dict directly instead of `json.dumps(message)`
  - Now uses `serializer='json'` parameter instead of `content_type='application/json'`
  - This allows Kombu to properly serialize and inject metadata
  - DSM successfully detects both queues (`chat_requests`, `chat_responses`)
  - Known Issue: Pathways show as 2 separate segments instead of 1 connected end-to-end pathway (requires further investigation) - 2024-12-30

### Added - Enhanced Observability (Health Check & Service Catalog fixes)
- **Health Check Span Filtering**: Added `DD_TRACE_IGNORE_RESOURCE_NAMES="GET /health"` to backend to reduce APM noise
- **Unified Service Tagging**: Added `tags.datadoghq.com/service`, `/env`, `/version` labels to all pods:
  - backend → `chat-backend`
  - frontend → `chat-frontend`
  - postgres → `chat-postgres`
  - rabbitmq → `chat-rabbitmq`
  - Fixed inconsistent environments (sandbox → demo) across all services
- **Software Catalog Visibility**: Services now properly appear in Datadog Software Catalog with full metadata

### Added - End-to-End Journey Monitoring
- **New Monitors for Complete Coverage** (5 additional monitors):
  - `worker_error_rate`: Chat worker processing failures
  - `openai_api_errors`: OpenAI API availability and quota issues
  - `frontend_api_errors`: Next.js API route errors
  - `rabbitmq_connections`: RabbitMQ connectivity health
  - Re-used existing `rum_js_errors` monitor for browser-side errors
- **Tagged all journey monitors** with `slo_component:true` for SLO aggregation

### Added - Enhanced SLO Coverage (3 new SLOs)
- **Chat Response End-to-End Availability SLO** (99.5% target over 7d)
  - Monitor-based composite SLO aggregating 7 component monitors
  - Covers: Frontend → Backend → RabbitMQ → Worker → OpenAI → Response
  - Priority: Critical (impacts all users)
- **Postgres Query Performance SLO** (95% target over 7d)
  - Monitor-based using slow query monitor
  - Ensures database doesn't become a bottleneck
- **Chat Worker Processing Availability SLO** (95% target over 7d)
  - Monitor-based using worker error rate, RabbitMQ connections, and queue depth
  - Validates async message processing pipeline health
- **Total SLOs**: 6 (up from 3)

### Added - Data Streams Monitoring (DSM)
- **RabbitMQ Integration**: Implemented asynchronous message queue for chat processing
  - `chat_requests` queue: Backend publishes chat prompts
  - `chat_responses` queue: Worker publishes OpenAI responses
  - Backend waits for responses via internal cache (no frontend polling)
  - Enabled `DD_DATA_STREAMS_ENABLED=true` for automatic pathway tracking
  - **Worker Service**: New `chat-worker` deployment processes messages asynchronously
  - **DSM Dashboard Widgets**: Added RabbitMQ queue depth, processing rate, and consumer metrics
  - **RabbitMQ Monitor**: Alert on high queue depth (>100 messages)

### Added - Data Jobs Monitoring (DJM)
- **Apache Airflow Integration**: Lightweight job scheduler for analytics
  - **3 Analytics DAGs**:
    - `daily_chat_summary`: Message counts, sessions, no-answer rate (daily @ 1 AM)
    - `token_usage_report`: OpenAI cost estimation (daily @ 2 AM)
    - `session_cleanup`: Identify old sessions for archival (weekly @ Sunday 3 AM)
  - Enabled `DD_DATA_JOBS_ENABLED=true` for automatic job tracking
  - **Airflow UI**: Accessible at `http://localhost:30808` (admin/admin)
  - **DJM Dashboard Widgets**: Added DAG success/failure tracking, execution duration
  - **Airflow Monitor**: Alert on DAG task failures (>3 in 15 minutes)
  - Uses SequentialExecutor with SQLite for lightweight deployment

### Fixed - GPT-5-nano Empty Response Bug
- **Root Cause**: `max_completion_tokens` parameter not supported by gpt-5-nano model
  - Model returns `finish_reason=length` with 0 content when parameter is present
  - Only affected certain complex prompts (e.g., long pizza dough questions)
  - Simple prompts like "health check" worked fine
- **Solution**: Removed `max_completion_tokens` parameter for gpt-5 models
  - Worker: Only adds `max_completion_tokens` for non-gpt-5 models
  - Backend: Removed parameter from title generation for gpt-5-nano
  - Model now uses default token limits
- **Note**: `temperature` parameter also conditionally applied (gpt-5-nano only supports default value of 1)

### Changed - Conversation History Temporarily Disabled
- **Context**: Conversation history feature was filling token budget with empty replies
  - Backend was fetching last 5 messages and sending as context to OpenAI
  - Empty replies from previous errors caused cascading failures
- **Current State**: History disabled to ensure stable responses
  - All messages treated as fresh prompts (no context)
  - Sidebar still shows session history (UI-only, not sent to OpenAI)
  - Title generation works independently
- **Future**: Re-enable with smarter logic:
  - Filter out messages with empty replies
  - Reduce to 1-2 previous messages max for gpt-5-nano
  - Or use summarization for longer conversations

### Added - Enhanced Dashboard
- **DSM Group**: Purple-themed section with RabbitMQ metrics
  - Queue depth timeline
  - Publish vs consume rates
  - Active consumer count
- **DJM Group**: Orange-themed section with Airflow metrics
  - DAG success vs failure bars
  - Execution duration (p95)
  - Active DAG runs counter

### Added - Software Catalog Entities
- **RabbitMQ**: `chat-rabbitmq` service entity with DSM tags
- **Worker**: `chat-worker` service entity with DSM tags
- **Airflow**: `chat-airflow` service entity with DJM tags
- **System Entity**: Updated to include all 7 components (backend, frontend, postgres, openai, rabbitmq, worker, airflow)

### Technical Details
- **DSM**: Automatic checkpoint instrumentation via `DD_DATA_STREAMS_ENABLED`
- **DJM**: Automatic job tracking via `DD_DATA_JOBS_ENABLED`
- **Architecture**: Backend → RabbitMQ → Worker → OpenAI (async flow)
- **Cost Savings**: Eliminated polling endpoint that was generating excessive spans
- **Monitoring**: 2 new monitors, 6 new dashboard widgets

## [Previous] - 2024-12-24

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

