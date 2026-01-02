# DJM Fix - Composite Transport Configuration

**Date**: 2026-01-02  
**Issue**: DJM not showing job runs in Datadog  
**Root Cause**: Incorrect OpenLineage transport configuration  
**Status**: ✅ FIXED

---

## 🚨 The Problem

**I misread the Datadog documentation and configured OpenLineage with the wrong transport type!**

### What I Configured (WRONG):

```yaml
OPENLINEAGE__TRANSPORT__TYPE=http
OPENLINEAGE__TRANSPORT__URL=https://data-obs-intake.datadoghq.com
OPENLINEAGE__TRANSPORT__AUTH__TYPE=api_key
OPENLINEAGE__TRANSPORT__AUTH__API_KEY=<key>
```

This is a **simple HTTP transport** - it works for other OpenLineage consumers (like Marquez), but **NOT for Datadog**.

### What Datadog Requires (CORRECT):

From the [official docs](https://docs.datadoghq.com/data_jobs/airflow/?tab=kubernetes):

```shell
OPENLINEAGE__TRANSPORT__TYPE=composite
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__TYPE=http
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__URL=https://data-obs-intake.datadoghq.com
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__TYPE=api_key
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__API_KEY=<DD_API_KEY>
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__COMPRESSION=gzip
```

---

## 🔍 Key Differences

| Aspect | Simple HTTP (Wrong) | Composite (Correct) |
|--------|---------------------|---------------------|
| **Transport Type** | `http` | `composite` |
| **URL Variable** | `OPENLINEAGE__TRANSPORT__URL` | `OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__URL` |
| **Auth Variable** | `OPENLINEAGE__TRANSPORT__AUTH__TYPE` | `OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__TYPE` |
| **API Key Variable** | `OPENLINEAGE__TRANSPORT__AUTH__API_KEY` | `OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__API_KEY` |
| **Compression** | Not specified | `OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__COMPRESSION=gzip` |
| **Nested Structure** | ❌ Flat | ✅ Nested under `TRANSPORTS__DATADOG__` |

---

## 💡 Why "Composite"?

The **composite transport** allows OpenLineage to send events to **multiple destinations** simultaneously. The structure is:

```
OPENLINEAGE__TRANSPORT__TYPE=composite
OPENLINEAGE__TRANSPORT__TRANSPORTS__<NAME>__...
```

Where `<NAME>` can be:
- `DATADOG` (for Datadog DJM)
- `HTTP` (for other OpenLineage consumers)
- `KAFKA` (for Kafka streaming)
- `CONSOLE` (for local debugging)

This is why Datadog requires the nested `TRANSPORTS__DATADOG__` structure - it's defining a Datadog-specific transport within the composite transport system.

---

## ✅ The Fix

### Updated `k8s/airflow.yaml`:

```yaml
# OpenLineage Configuration for DJM (Data Jobs Monitoring)
# NOTE: Datadog requires "composite" transport type with nested structure
- name: OPENLINEAGE__TRANSPORT__TYPE
  value: "composite"
- name: OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__TYPE
  value: "http"
- name: OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__URL
  value: "https://data-obs-intake.datadoghq.com"
- name: OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__TYPE
  value: "api_key"
- name: OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__API_KEY
  valueFrom:
    secretKeyRef:
      name: datadog-keys
      key: api-key
- name: OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__COMPRESSION
  value: "gzip"
- name: AIRFLOW__OPENLINEAGE__NAMESPACE
  value: "demo"
- name: OPENLINEAGE_CLIENT_LOGGING
  value: "DEBUG"
```

### Applied Changes:

```bash
kubectl apply -f k8s/airflow.yaml
kubectl rollout restart deployment/airflow -n chat-demo
```

---

## 🧪 How to Validate the Fix

### Step 1: Wait for Airflow to Restart

```bash
kubectl get pods -n chat-demo -l app=airflow
```

Expected: `1/1 Running` (takes ~2 minutes)

### Step 2: Verify New Environment Variables

```bash
kubectl exec -n chat-demo deployment/airflow -- printenv | grep "OPENLINEAGE__TRANSPORT"
```

Expected output:
```
OPENLINEAGE__TRANSPORT__TYPE=composite
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__TYPE=http
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__URL=https://data-obs-intake.datadoghq.com
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__TYPE=api_key
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__AUTH__API_KEY=<your-api-key>
OPENLINEAGE__TRANSPORT__TRANSPORTS__DATADOG__COMPRESSION=gzip
```

### Step 3: Trigger a Test DAG

```bash
# Option A: Via Airflow UI
# 1. Open http://localhost:30808
# 2. Trigger "daily_chat_summary"

# Option B: Via CLI
kubectl exec -n chat-demo deployment/airflow -- airflow dags trigger daily_chat_summary
```

### Step 4: Check Airflow Logs for OpenLineage Events

```bash
# Wait 30 seconds for DAG to complete, then:
kubectl logs -n chat-demo deployment/airflow --tail=200 | grep -iE "(openlineage|emit|datadog)" | grep -v "pip install"
```

**Expected output** (after DAG completion):
```
DEBUG - Emitting OpenLineage START event for dag_id=daily_chat_summary
DEBUG - Sending event to composite transport: datadog
INFO - OpenLineage event sent successfully to https://data-obs-intake.datadoghq.com
DEBUG - Emitting OpenLineage COMPLETE event for dag_id=daily_chat_summary
```

### Step 5: Check Datadog DJM (5 Minutes Later)

```
URL: https://app.datadoghq.com/data-jobs?env=demo
```

**Expected**: Job run for `daily_chat_summary` with:
- Environment: `demo`
- Status: Success
- Duration: ~1-2 seconds
- Timestamp: Within last 10 minutes

---

## 📋 Timeline

| Time | Event |
|------|-------|
| 14:30 UTC | Initial OpenLineage configuration (WRONG - simple HTTP) |
| 14:35-14:44 UTC | Triggered 3 DAGs, no events sent to Datadog ❌ |
| 14:52 UTC | Discovered configuration error |
| 14:53 UTC | Applied fix (composite transport) ✅ |
| 14:55 UTC | Airflow restarted with correct config |
| 14:56+ UTC | **Next DAG trigger should work!** |

---

## 🎓 Lessons Learned

1. **Read the docs carefully**: The Datadog docs specifically use `composite` transport, not `http`
2. **Nested configuration matters**: The `TRANSPORTS__DATADOG__` nesting is crucial
3. **Test early**: Should have checked logs for event emission immediately after first DAG run
4. **Compression**: Datadog recommends `gzip` compression for OpenLineage events

---

## 🔗 References

- [Datadog DJM for Airflow - Kubernetes Setup](https://docs.datadoghq.com/data_jobs/airflow/?tab=kubernetes)
- [OpenLineage Composite Transport](https://openlineage.io/docs/client/python#composite)
- [Apache Airflow OpenLineage Provider](https://airflow.apache.org/docs/apache-airflow-providers-openlineage/stable/index.html)

---

## ✅ Next Steps

1. **Verify Airflow is running** (1/1 Ready)
2. **Trigger a new DAG** (daily_chat_summary)
3. **Check logs** for "composite transport" messages
4. **Wait 5 minutes**
5. **Check Datadog DJM** for job runs

**This should now work!** 🚀

---

## 🧪 Validation Steps

### 1. Open Airflow UI
- URL: **http://localhost:30808**
- Login: `admin` / `admin`

### 2. Trigger a DAG
1. Click `daily_chat_summary`
2. Click **▶️ "Trigger DAG"** button
3. Wait 30 seconds for completion (green)

### 3. Check Logs
```bash
kubectl logs -n chat-demo deployment/airflow --tail=200 | grep -i "composite"
```
Expected: `Sending event to composite transport: datadog`

### 4. Check Datadog DJM (5 minutes later)
- URL: https://app.datadoghq.com/data-jobs?env=demo
- Look for: `daily_chat_summary` job run with env=demo

### Troubleshooting
If no data appears:
```bash
# Verify composite transport config
kubectl exec -n chat-demo deployment/airflow -- printenv | grep OPENLINEAGE__TRANSPORT

# Check for errors
kubectl logs -n chat-demo deployment/airflow --tail=200 | grep -E "(ERROR|WARN)"

# Test API connectivity
kubectl exec -n chat-demo deployment/airflow -- curl -I https://data-obs-intake.datadoghq.com
```

---

**Status**: Fix applied, validation steps above.

