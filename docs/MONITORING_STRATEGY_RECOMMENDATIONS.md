# Monitoring Strategy – Tactical Recommendations

Review of the current Datadog monitoring (monitors, SLOs, synthetics) and concrete improvements.

---

## What’s Working Well

- **Layered coverage**: APM (backend, worker, frontend), RUM, database, RabbitMQ, Airflow, K8s.
- **SLOs**: Backend availability + latency, frontend error-free sessions, composite E2E (chat pipeline), DB and RabbitMQ/worker proxies.
- **Runbook-style messages**: Backend error monitor documents startup/RabbitMQ ordering and fixes.
- **Synthetics**: Frontend uptime, backend-via-chat, and browser user journey for E2E.
- **Tags**: `category:`, `team:chatbot`, `slo_component:true` support filtering and SLO composition.

---

## Tactical Improvements

### 1. **Fix OpenAI monitor scope (high impact)**

- **Issue**: `openai_failures` uses `trace.openai.error{service:chat-backend}`. OpenAI calls run on **chat-worker**, so this metric is empty for chat-backend and the monitor effectively never fires.
- **Change**: Either:
  - Scope to the service that actually calls OpenAI, e.g. `trace.openai.error{service:chat-worker,env:...}`, or
  - Rely on `openai_api_errors` (which uses `trace.openai.request.errors{env:...}` and includes chat-worker) and **remove or repurpose** `openai_failures` to avoid duplication and confusion.
- **Recommendation**: Use a single source of truth for “OpenAI is failing”: keep `openai_api_errors` (already correct) and update `openai_failures` to chat-worker if you want a second, stricter (e.g. any error) check; otherwise remove it.

### 2. **Enable SLO burn-rate alerting**

- **Issue**: The SLO burn-rate monitor is commented out, so you only see SLO status after the fact, not “burning too fast” during the window.
- **Change**: Uncomment and apply the `backend_slo_burn_rate` (or equivalent) monitor in `monitors.tf`, or add a metric-based burn-rate alert (e.g. error budget consumption rate) so you get notified before the period ends.
- **Benefit**: Earlier reaction when backend availability (or other SLOs) starts degrading.

### 3. **Add a 503 / “not ready” signal**

- **Issue**: After the readiness and RabbitMQ changes, the backend can return 503 (“Message queue is connecting”) until `/ready` passes. There’s no dedicated signal for “backend is up but not ready to serve chat.”
- **Change**: Add one of:
  - **Option A**: A monitor on **5xx rate** that includes 503, e.g.  
    `sum(last_5m):trace.http.request.errors{service:chat-backend,env:demo,http.status_code:503}.as_count() > N`  
    (if your tracer tags 503 as error and you can filter by status), or  
  - **Option B**: A synthetic that hits **`/ready`** (or a dedicated readiness URL) and asserts 200, so you see “backend not ready” as a failed synthetic instead of user-facing 503s.
- **Benefit**: Distinguishes “startup/readiness” from “real” 500s and avoids treating expected 503s during rollout as generic backend failures.

### 4. **Tighten backend latency for non-LLM paths**

- **Issue**: Backend p95 threshold is 30s to accommodate OpenAI. That’s appropriate for `/chat`, but it hides regressions on fast paths (`/health`, `/sessions`, `/ready`).
- **Change**: Add a second monitor for **fast endpoints only**, e.g.  
  `avg(last_5m):p95:trace.http.request{service:chat-backend,env:demo,resource_name:get_/sessions*}.as_count() > 2`  
  (or use `resource_name` / tags that exclude `post_/chat`). Set a low threshold (e.g. 2–5s).
- **Benefit**: Catches DB or routing regressions on sessions/health without being drowned out by LLM latency.

### 5. **No-data handling on critical monitors**

- **Issue**: Most monitors use `notify_no_data = false`. For critical app components (e.g. backend, worker), “no data” can mean the service or agent is down.
- **Change**: For **backend_error_rate**, **worker_error_rate**, and optionally **rabbitmq_connections**, set:
  - `notify_no_data = true`
  - `no_data_timeframe = 10` (or 15) minutes  
  so you get alerted if the metric disappears (e.g. pod down, agent not scraping).
- **Caveat**: In demo, if the cluster is often scaled to 0, this will fire; you can keep it off in demo or use a longer `no_data_timeframe` / mute when the cluster is intentionally down.

### 6. **Synthetic backend target**

- **Issue**: Backend health synthetic uses `localhost:30080/api/chat` (frontend). That’s great for E2E but doesn’t directly assert “backend is up.”
- **Change**: If you have a way to reach the backend (e.g. private location with K8s network, or a public URL in another env), add a simple **HTTP check** to `GET /health` or `GET /ready` on the backend. If everything is behind the same NodePort/frontend, document that “backend health” is inferred via the chat synthetic and keep a single E2E check to avoid duplication.
- **Benefit**: Clearer “backend vs frontend vs full stack” attribution when a check fails.

### 7. **RabbitMQ connections monitor logic**

- **Issue**: `avg(last_5m):avg:rabbitmq.connections{...} < 2` with `critical = 2`, `warning = 3` means: alert when connections **below** 2 (critical) or below 3 (warning). That’s correct for “we expect at least 2 (backend + worker).”
- **Check**: Confirm in Datadog that the metric is actually `rabbitmq.connections` (or the correct metric name for “number of connections”) and that it’s reported when RabbitMQ is running. If the integration uses a different metric (e.g. `rabbitmq.connections.count`), update the query.
- **Optional**: Add a short note in the monitor message: “Expect at least 2 connections (backend publisher + worker consumer).”

### 8. **Runbook / playbook links in messages**

- **Issue**: Messages are already good prose; adding a link would speed up response.
- **Change**: Add a `runbook_url` (or a line in the message) pointing to a Confluence/Notion/doc that describes:
  - Startup ordering and RabbitMQ
  - How to check readiness and RabbitMQ connectivity
  - How to interpret 503 vs 500 for backend
- **Benefit**: On-call can open one link instead of re-reading the message.

### 9. **Consolidate or document “two OpenAI monitors”**

- **Current**:  
  - `openai_failures`: `trace.openai.error`, service chat-backend (wrong service).  
  - `openai_api_errors`: `trace.openai.request.errors`, env only (correct).
- **Change**:  
  - Fix or remove `openai_failures` (see #1).  
  - In the remaining monitor(s), add one line to the message: “This reflects OpenAI errors from the chat-worker (LLM calls).”
- **Benefit**: No duplicate or contradictory alerts; clear ownership.

### 10. **Priority and severity**

- **Current**: Priority 1–3 is set; messages don’t always say “CRITICAL” vs “WARNING.”
- **Change**: In the message template, add a single line at the top, e.g.  
  `Severity: {{#is_alert}}CRITICAL{{/is_alert}}{{#is_warning}}WARNING{{/is_warning}}`  
  (Datadog template syntax) so the first thing on-call sees is severity.
- **Benefit**: Faster triage when multiple alerts fire.

---

## Suggested order of implementation

| Order | Item                               | Effort | Impact |
|-------|------------------------------------|--------|--------|
| 1     | Fix OpenAI monitor scope (#1, #9)  | Low    | High   |
| 2     | Enable SLO burn-rate (#2)          | Low    | High   |
| 3     | 503 / readiness signal (#3)        | Low    | Medium |
| 4     | No-data on critical monitors (#5)  | Low    | Medium |
| 5     | Backend latency for fast paths (#4)| Medium | Medium |
| 6     | Runbook link + severity line (#8, #10) | Low | Low   |
| 7     | Synthetic backend/ready (#6)       | Low    | Low (if E2E already covers it) |
| 8     | RabbitMQ metric + message (#7)     | Low    | Low   |

---

## Summary

- **Highest impact**: Correct OpenAI monitor scope and re-enable SLO burn-rate alerting.
- **Quick wins**: 503/readiness monitor or synthetic, no-data on critical monitors, runbook link and severity in messages.
- **Structural**: One clear “OpenAI failing” story, separate fast-path latency from LLM latency, and document how backend “health” is asserted (synthetic vs `/ready`).

Applying these will reduce noise, fix one broken monitor, and make alerts more actionable without a large redesign.
