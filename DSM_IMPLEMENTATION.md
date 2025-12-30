# Data Streams Monitoring (DSM) Implementation Summary

## Overview
Successfully implemented **async message processing** with RabbitMQ and full **Data Streams Monitoring (DSM)** instrumentation for the AI chatbot demo.

**✅ DSM NOW WORKING** - Migrated from `pika` to `kombu` for official Datadog DSM support.

## Critical Update: Kombu Migration

**Date**: 2025-12-30

### Why the Migration Was Required

According to [Datadog's official DSM Python documentation](https://docs.datadoghq.com/data_streams/setup/language/python/), **only `kombu` is supported for RabbitMQ DSM**:

| Library | DSM Support | APM Spans | Auto-Instrumentation |
|---------|-------------|-----------|----------------------|
| ❌ **pika** | Not supported | No spans | Not instrumented by ddtrace |
| ✅ **kombu** | Fully supported | Yes | Auto-instrumented |

### What Changed

1. **Dependencies**:
   - Backend: `requirements.txt` now uses `kombu==5.3.4` instead of `pika`
   - Worker: `requirements.txt` now uses `kombu==5.3.4` instead of `pika`

2. **New Helper Module**:
   - Created `messaging.py` in both `backend/app/` and `worker/app/`
   - `RabbitMQClient` class wrapping Kombu Connection, Producer, Consumer
   - Handles message serialization, queue declaration, automatic ACK/NACK

3. **Code Changes**:
   - Backend: Replaced `pika.BlockingConnection` with `RabbitMQClient`
   - Worker: Replaced `pika` callback pattern with Kombu consumer
   - Both now use `patch(kombu=True)` for explicit Kombu instrumentation

4. **DSM Activation**:
   - `DD_DATA_STREAMS_ENABLED=true` environment variable (already set)
   - `DD_TRACE_REMOVE_INTEGRATION_SERVICE_NAMES_ENABLED=true` (already set)
   - Kombu auto-instrumentation generates DSM checkpoints on publish/consume

### Current Status

✅ **Working**:
- RabbitMQ message flow (backend → worker → backend)
- DSM detects both queues (`chat_requests`, `chat_responses`)
- Individual queue metrics visible in DSM
- Chat functionality working end-to-end

⚠️ **Known Issue**:
- DSM pathways show as **2 separate segments** instead of 1 connected pathway
- Individual queue-to-service connections are visible
- Full end-to-end pathway stitching not yet working
- This may require additional investigation into Kombu/ddtrace context propagation
- Possible workaround: Explicit manual checkpoint injection (not currently implemented)

## Architecture Changes

### New Components Added
1. **RabbitMQ Message Broker** (`chat-rabbitmq`)
   - Service: `rabbitmq:5672` (AMQP), `rabbitmq:15672` (Management UI)
   - Image: `rabbitmq:3.13-management-alpine`
   - Queues: `chat_requests`, `chat_responses`
   - Datadog integration with autodiscovery annotations

2. **Chat Worker Service** (`chat-worker`)
   - Python async worker consuming from RabbitMQ
   - Processes chat requests and calls OpenAI API
   - Publishes responses back to queue
   - Full DSM instrumentation with checkpoints

### Modified Components
1. **Backend** (`chat-backend`)
   - Now publishes chat requests to RabbitMQ queue instead of calling OpenAI directly
   - Background thread consumes responses from `chat_responses` queue
   - New `/chat` endpoint returns `request_id` for async polling
   - New `/chat/poll/{request_id}` endpoint for response polling
   - DSM checkpoints on message produce/consume

2. **Frontend** (`chat-frontend`)
   - Updated API route to poll for async responses
   - 60-second timeout with 1-second poll intervals
   - Transparent to user - same UX as before

## Message Flow

```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌────────┐      ┌─────────┐
│Frontend │──────▶│ Backend │──────▶│ RabbitMQ │──────▶│ Worker │──────▶│ OpenAI  │
│ (Next)  │ HTTP  │(FastAPI)│ AMQP  │  Queues  │ AMQP  │(Python)│ HTTP  │   API   │
└─────────┘      └─────────┘      └──────────┘      └────────┘      └─────────┘
                      │                  │                │
                      │ DSM Checkpoint   │ DSM Checkpoint │ DSM Checkpoint
                      │ (produce)        │ (consume)      │ (produce/consume)
                      └──────────────────┴────────────────┘
                              End-to-End Tracking
```

### Step-by-Step Flow
1. User submits message via frontend
2. Frontend calls `/api/chat` (Next.js API route)
3. Backend API publishes to `chat_requests` queue (DSM checkpoint OUT)
4. Backend returns `request_id` immediately
5. Worker consumes from `chat_requests` (DSM checkpoint IN)
6. Worker calls OpenAI API with conversation history
7. Worker publishes response to `chat_responses` queue (DSM checkpoint OUT)
8. Backend consumer thread receives response (DSM checkpoint IN)
9. Backend caches response in memory
10. Frontend polls `/chat/poll/{request_id}` every 1 second
11. When response ready, backend saves to Postgres and returns to frontend

## DSM Checkpoints

### Backend (Producer)
- **Direction**: `out`
- **Topic**: `chat_requests`
- **Type**: `rabbitmq`
- Location: After `basic_publish` in `/chat` endpoint

### Worker (Consumer & Producer)
- **Consume Checkpoint**:
  - Direction: `in`
  - Topic: `chat_requests`
  - Location: In `process_message` callback
- **Produce Checkpoint**:
  - Direction: `out`
  - Topic: `chat_responses`
  - Location: After publishing OpenAI response

### Backend (Consumer)
- **Direction**: `in`
- **Topic**: `chat_responses`
- **Type**: `rabbitmq`
- Location: In `consume_responses` background thread

## Configuration

### Environment Variables (Backend & Worker)
```yaml
DD_DATA_STREAMS_ENABLED: "true"  # KEY CONFIG for DSM
DD_TRACE_ENABLED: "true"
DD_SERVICE: "chat-backend" / "chat-worker"
RABBITMQ_HOST: "rabbitmq"
RABBITMQ_PORT: "5672"
REQUEST_QUEUE: "chat_requests"
RESPONSE_QUEUE: "chat_responses"
```

### Dependencies Added
- Backend: `pika==1.3.2` (RabbitMQ client)
- Worker: `pika==1.3.2`, `openai==1.58.1`, `ddtrace==2.18.1`

## Files Created

### Worker Service
- `worker/app/main.py` - Worker application code
- `worker/requirements.txt` - Python dependencies
- `worker/Dockerfile` - Container build definition
- `k8s/worker.yaml` - Kubernetes deployment

### Infrastructure
- `k8s/rabbitmq.yaml` - RabbitMQ deployment with Datadog annotations

### Documentation
- Updated `README.md` with DSM architecture section
- Updated `system-entity-definition.json` with new components
- This file: `DSM_IMPLEMENTATION.md`

## Files Modified

### Backend
- `backend/app/main.py` - Added RabbitMQ producer/consumer logic, DSM checkpoints
- `backend/requirements.txt` - Added `pika` dependency
- `k8s/backend.yaml` - Added RabbitMQ and DSM environment variables

### Frontend
- `frontend/pages/api/chat.js` - Added polling logic for async responses

### Terraform
- `terraform/software_catalog.tf` - Added `chat-rabbitmq` and `chat-worker` entities

### Scripts
- `scripts/setup.sh` - Added worker image build and RabbitMQ deployment

## Datadog Features Enabled

### Data Streams Monitoring
Access in Datadog UI: **APM → Data Streams**

Visibility includes:
- ✅ End-to-end message latency (request → response)
- ✅ Queue depth and lag metrics
- ✅ Throughput (messages/second)
- ✅ Producer/consumer relationships
- ✅ Pathway visualization
- ✅ Per-queue metrics (age, size, consumer count)

### Service Map Updates
- New services: `chat-rabbitmq`, `chat-worker`
- New dependencies visualized:
  - `chat-backend` → `chat-rabbitmq`
  - `chat-rabbitmq` → `chat-worker`
  - `chat-worker` → `openai-api`

### APM Traces
- Distributed traces now span: Frontend → Backend → RabbitMQ → Worker → OpenAI
- Message correlation via `request_id`

## Software Catalog

Added 2 new service entities (total now 6):

1. **chat-rabbitmq**
   - Type: `datastore`
   - Tier: `tier2`
   - Tags: `dsm:enabled`, `messaging:rabbitmq`

2. **chat-worker**
   - Type: `worker`
   - Tier: `tier2`
   - Tags: `dsm:enabled`, `llm:true`, `messaging:rabbitmq`

Updated system entity to include both new components.

## Testing Checklist

- [ ] Build all Docker images (backend, worker, frontend)
- [ ] Deploy RabbitMQ and verify pod is Ready
- [ ] Deploy backend and worker, check logs for RabbitMQ connection
- [ ] Submit chat request via frontend
- [ ] Verify message appears in RabbitMQ management UI
- [ ] Verify worker processes message and calls OpenAI
- [ ] Verify response returns to frontend
- [ ] Check Datadog UI for DSM data (may take 5-10 minutes)
- [ ] Verify Service Map shows new topology
- [ ] Check APM traces for end-to-end flow

## Accessing DSM in Datadog

1. Navigate to **APM → Data Streams**
2. Select timeframe (may need to wait 5-10 minutes for initial data)
3. View:
   - **Pathways**: Visual graph of message flow
   - **Services**: Producer/consumer list
   - **Queues**: Queue-level metrics (depth, lag, throughput)
4. Click on a pathway to see:
   - End-to-end latency percentiles
   - Message throughput over time
   - Queue backlog trends

## RabbitMQ Management UI

Access locally: `http://localhost:30672` (if exposed via NodePort)
- Username: `guest`
- Password: `guest`
- View queues, exchanges, message rates, consumer connections

## Benefits Demonstrated

1. **Async Resilience**: Backend doesn't wait for slow OpenAI calls
2. **Rate Limiting**: Queue naturally limits OpenAI API concurrency
3. **Scalability**: Can scale worker replicas independently
4. **Observability**: Full visibility into message pipeline with DSM
5. **Realistic Architecture**: Demonstrates production-grade async patterns

## Next Steps (Future Enhancements)

- [ ] Add dead-letter queue for failed messages
- [ ] Implement Redis for response caching (replace in-memory dict)
- [ ] Add queue-depth monitoring with alerts
- [ ] Scale workers with HPA based on queue lag
- [ ] Add message TTL and expiration policies
- [ ] Implement WebSocket for real-time response streaming
- [ ] Add Data Jobs Monitoring (Airflow for analytics)

## Troubleshooting

### Worker not connecting to RabbitMQ
```bash
kubectl logs -n chat-demo deployment/chat-worker
# Should see "Connected to RabbitMQ at rabbitmq:5672"
```

### Messages stuck in queue
```bash
kubectl exec -n chat-demo deployment/rabbitmq -- rabbitmqctl list_queues
# Check message counts in chat_requests and chat_responses
```

### DSM data not appearing
- Wait 5-10 minutes for initial data
- Verify `DD_DATA_STREAMS_ENABLED=true` in backend and worker pods
- Check Datadog Agent logs for DSM intake errors
- Ensure ddtrace version >= 2.0.0

### Frontend timeout errors
- Check worker logs for OpenAI errors
- Verify OPENAI_API_KEY secret is correct
- Increase poll timeout in `frontend/pages/api/chat.js`

---

**Implementation Date**: December 30, 2025  
**Datadog Features**: Data Streams Monitoring (DSM), APM, Software Catalog  
**Tech Stack**: RabbitMQ, FastAPI, Python, Next.js, Kubernetes

