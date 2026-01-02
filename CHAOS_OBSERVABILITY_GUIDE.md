# 🎮 Chaos Control Panel - Setup & Demo Guide

## Overview

An interactive admin panel built into the chatbot UI for live demos. Provides traffic generation and break-fix scenarios with a single click.

### Access (Easter Egg)
**Triple-click the "Datadog Chatbot Demo" branding text** in the sidebar footer. The panel slides in from the right with a dark chaos-themed UI.

### Features
- **📊 Traffic Generation**: Light (3-6 req/min), Medium (12-20 req/min), Heavy (30-60 req/min)
- **💥 Break-Fix Scenarios**: 6 one-click scenarios (Worker Crash, Memory Pressure, Queue Backup, API Errors, DB Slowdown, Network Latency)
- **🔧 Quick Actions**: Heal All, Restart Services
- **📡 System Status**: Real-time health indicators for all services

---

## How to Tell a Story with Each Chaos Scenario in Datadog

This guide shows you **exactly what to look for in Datadog** when triggering each chaos scenario, so you can demonstrate observability in action.

---

## 📋 Before Starting Any Scenario

### Preparation Checklist:
1. **Open these Datadog views in separate tabs:**
   - APM Service Map: https://app.datadoghq.com/apm/map
   - Your Chatbot Dashboard: https://app.datadoghq.com/dashboard/lists
   - Monitors page: https://app.datadoghq.com/monitors/manage
   - Live Tail (logs): https://app.datadoghq.com/logs/livetail

2. **Enable Light Traffic** in Chaos Panel (3-6 req/min) to generate baseline activity

3. **Wait 2-3 minutes** to establish normal baseline metrics

---

## 1️⃣ Worker Crash

### What You're Breaking:
- Scales `chat-worker` deployment to 0 replicas
- Messages queue up in RabbitMQ
- Backend times out waiting for responses

### The Story to Tell:

**Act 1: The Failure (0-30 seconds)**
```
YOU: "Let's simulate our worker pods crashing..."
[Click "Worker Crash" button]
```

**What to show in Datadog:**
1. **APM Service Map** (watch live):
   - `chat-worker` service turns **red** or disappears
   - Connections from `rabbitmq` to `chat-worker` break

2. **Dashboard - "RabbitMQ Queue Depth"** widget:
   - `chat_requests` queue depth **increases** (messages piling up)
   - Goes from 0 → 5 → 10 → 15...

3. **Dashboard - "Backend API Latency"** widget:
   - p95 latency **spikes** from ~2s to 30s+ (timeout)

4. **Monitors page**:
   - `[demo] RabbitMQ Queue Depth is High` fires → **ALERT**
   - `[demo] Backend API Latency (p95) is high` fires → **ALERT**

5. **Logs - Live Tail** (filter: `service:chat-backend`):
   ```
   ERROR: Timeout waiting for worker response
   ```

**Act 2: Investigation (30-60 seconds)**
```
YOU: "Notice the queue building up? The backend is timing out..."
```

**What to show:**
6. **APM Traces** (filter: `service:chat-backend status:error`):
   - Click on a trace with 30+ second duration
   - Show the span where it's waiting for worker response
   - **No worker span** = worker is down

7. **Infrastructure - Kubernetes**:
   - Navigate to chat-worker deployment
   - Show **0/0 pods running**

**Act 3: The Fix (60-90 seconds)**
```
YOU: "Let's heal this and watch recovery..."
[Click "Heal All" button]
```

**What to show:**
8. **APM Service Map**:
   - `chat-worker` service turns **green**
   - Connections restored

9. **Dashboard - "RabbitMQ Queue Depth"**:
   - Queue depth **drops back to 0** as backlog is processed

10. **Monitors page**:
    - Alerts transition to **OK** (green)

**Time to Recovery:** ~30-60 seconds

---

## 2️⃣ Memory Pressure

### What You're Breaking:
- Reduces backend memory limit from 256Mi → 64Mi
- Backend OOMKills under load
- Pod restarts repeatedly

### The Story to Tell:

**Act 1: The Failure (0-60 seconds)**
```
YOU: "What happens when we starve the backend of memory?"
[Click "Memory Pressure" button]
```

**What to show in Datadog:**
1. **Dashboard - "Pod Restarts"** widget (`kubernetes.containers.restarts`):
   - `backend` restarts count **increases**
   - Goes from 0 → 1 → 2...

2. **Dashboard - "Backend Memory Usage"** widget:
   - Memory usage hits **64Mi ceiling** (100% of limit)
   - Flatlines at the top

3. **Infrastructure - Kubernetes**:
   - Navigate to backend pod
   - Show pod events: `OOMKilled` reason
   - Show restart count incrementing

4. **Logs - Live Tail** (filter: `source:kubernetes`):
   ```
   Back-off restarting failed container backend
   ```

5. **APM Service Map**:
   - `chat-backend` service **flapping** (red/yellow/green)

**Act 2: User Impact (60-120 seconds)**
```
YOU: "Users are experiencing errors due to the restarts..."
```

**What to show:**
6. **APM Traces** (filter: `service:chat-backend status:error`):
   - 502 errors from frontend
   - Connection refused errors

7. **RUM** (if enabled):
   - Error sessions spike
   - User journey breaks at "Send Message" step

**Act 3: The Fix**
```
YOU: "Let's restore normal memory limits..."
[Click "Heal All" button]
```

**What to show:**
8. **Dashboard - "Backend Memory Usage"**:
   - Memory limit increases to 256Mi
   - Usage stabilizes below limit (~120-150Mi)

9. **Dashboard - "Pod Restarts"**:
   - Restart count stops incrementing

**Time to Recovery:** ~60-90 seconds

---

## 3️⃣ API Errors (OpenAI)

### What You're Breaking:
- Replaces valid OpenAI API key with invalid one
- Worker can't call OpenAI
- Users get "no_answer" responses

### The Story to Tell:

**Act 1: The Failure (0-30 seconds)**
```
YOU: "Let's simulate our AI provider having issues..."
[Click "API Errors" button]
```

**What to show in Datadog:**
1. **LLM Observability** (https://app.datadoghq.com/llm/traces):
   - Traces show **401 Unauthorized** errors
   - `openai.request.errors` metric **spikes**

2. **Dashboard - "OpenAI API Calls"** widget:
   - Success rate **drops** from 100% → 0%
   - Error count increases

3. **Monitors page**:
   - `[demo] OpenAI API Error Rate is high` fires → **ALERT**

4. **APM Traces** (filter: `service:chat-worker status:error`):
   - Click on error trace
   - Show OpenAI span with 401 error
   - Error message: `Incorrect API key provided`

5. **Logs - Live Tail** (filter: `service:chat-worker`):
   ```json
   {
     "error": {
       "code": "invalid_api_key",
       "message": "Incorrect API key provided"
     }
   }
   ```

**Act 2: Database Evidence**
```
YOU: "Let's check what users are seeing..."
```

**What to show:**
6. **DBM - Query Samples** (filter: `chat_messages`):
   - Queries show `no_answer: true` in results
   - `reply` column is empty

**Act 3: The Fix**
```
YOU: "Restoring the valid API key..."
[Click "Heal All" button]
```

**What to show:**
7. **LLM Observability**:
   - New traces show **200 OK**
   - Token usage metrics resume

8. **Monitors page**:
   - Alert transitions to **OK**

**Time to Recovery:** ~10-20 seconds

---

## 4️⃣ Queue Backup

### What You're Breaking:
- Same as Worker Crash (scales worker to 0)
- Focus on DSM metrics

### The Story to Tell:

**Act 1: The Failure**
```
YOU: "Let's pause message processing and watch the queue..."
[Click "Queue Backup" button]
```

**What to show in Datadog:**
1. **Data Streams Monitoring** (https://app.datadoghq.com/data-streams):
   - Navigate to `chat_requests` queue
   - **Lag** metric increases
   - **Throughput** drops to 0

2. **Dashboard - "Message Processing Rate"** widget:
   - Publish rate: **continues** (messages coming in)
   - Deliver rate: **drops to 0** (not being consumed)

3. **Dashboard - "RabbitMQ Queue Depth"**:
   - Linear increase over time

**Act 2: The Fix**
```
[Click "Heal All" button]
```

**What to show:**
4. **Data Streams Monitoring**:
   - Lag **decreases** as backlog is processed
   - Throughput **spikes** (catching up)

5. **Dashboard - "Message Processing Rate"**:
   - Deliver rate **spikes above** publish rate (draining queue)

**Time to Recovery:** ~30-60 seconds (depending on queue size)

---

## 5️⃣ Database Slowdown

### What You're Breaking:
- (Simulated - visual indicator only)
- Use for discussing DBM capabilities

### The Story to Tell:

```
YOU: "This one is simulated, but let me show you what DBM would reveal..."
```

**What to show in Datadog:**
1. **DBM - Query Performance** (https://app.datadoghq.com/databases):
   - Navigate to Postgres instance
   - Show query samples and execution plans
   - Point out slowest queries

2. **DBM - Explain Plans**:
   - Click on a SELECT query
   - Show the execution plan
   - Discuss: "Here's where we'd see sequential scans vs index scans"

3. **Dashboard - "Database Query Time"** widget:
   - Show historical data
   - Discuss: "If this spiked, DBM would tell us which queries slowed down"

---

## 6️⃣ Network Latency

### What You're Breaking:
- (Simulated - visual indicator only)
- Use for discussing NPM capabilities

### The Story to Tell:

```
YOU: "For network issues, we'd rely on NPM..."
```

**What to show in Datadog:**
1. **Network Performance Monitoring** (https://app.datadoghq.com/network):
   - Show network map
   - Filter to `namespace:chat-demo`
   - Show connections between services

2. **APM Traces**:
   - Show a normal trace
   - Point out network time in spans
   - Discuss: "If latency spiked, we'd see it in these network spans"

---

## 🎯 Pro Tips for Storytelling

### 1. **Start with the User**
```
"Imagine a user trying to send a chat message. Let's see what happens when..."
```

### 2. **Layer Your Evidence**
```
"We see it in the service map, the traces confirm it, the logs tell us why, 
and the monitor fired an alert."
```

### 3. **Show the Full Loop**
```
BREAK → DETECT → INVESTIGATE → FIX → VERIFY
```

### 4. **Use Real Numbers**
```
"Queue depth went from 0 to 15 in 30 seconds"
"Latency spiked from 2 seconds to 31 seconds"
"Pod restarted 3 times in 2 minutes"
```

### 5. **Tie to Business Impact**
```
"These errors mean users aren't getting AI responses"
"This timeout creates a poor user experience"
"These restarts cause intermittent failures"
```

---

## 📊 Recommended Dashboard Layout for Demos

Create a "Chaos Demo" dashboard with:

**Row 1: User Experience**
- RUM Error Rate
- Frontend API Latency
- Synthetic Test Results

**Row 2: Application Health**
- APM Service Map
- Error Rate (all services)
- Request Rate

**Row 3: Infrastructure**
- Pod Restarts
- Memory Usage (by service)
- CPU Usage

**Row 4: Dependencies**
- RabbitMQ Queue Depth
- OpenAI API Status
- Database Query Time

**Row 5: Alerts**
- Active Monitors widget
- SLO Burn Rate

---

## 🎬 Sample Demo Script (5 minutes)

```
[0:00-1:00] Baseline
- "Here's our chatbot in normal operation"
- Show dashboard, all green
- Enable light traffic

[1:00-2:30] Worker Crash
- Trigger scenario
- Show queue building up
- Show backend timing out
- Show monitors firing
- Navigate through APM trace

[2:30-3:30] Memory Pressure
- Trigger scenario
- Show pod restarting
- Show OOMKill in events
- Show memory hitting limit

[3:30-4:30] API Errors
- Trigger scenario
- Show LLM Obs errors
- Show failed API calls
- Show no_answer in database

[4:30-5:00] Heal All & Wrap
- Click Heal All
- Show everything recovering
- "This is the power of full-stack observability"
```

---

**Remember:** The chaos panel creates **real production-like failures** that trigger **real alerts** and show up in **real observability data**. This makes your demo authentic and compelling! 🚀

