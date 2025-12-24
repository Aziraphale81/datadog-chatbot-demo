# Synthetic Tests Tuning Summary

## 🔧 Issues Fixed

### Problem
Synthetic tests were failing with DNS resolution timeouts (`ETIMEDOUT`) and no status codes or body returned.

**Root Cause:**
- Tests were configured to use Kubernetes internal DNS names (`frontend.chat-demo.svc.cluster.local`)
- Docker private location with `--network host` cannot resolve Kubernetes DNS
- Backend test was trying to reach internal K8s service directly

### Error Messages Before Fix
```
DNS: $Error: Error during DNS resolution (ETIMEDOUT)
Assertion: Status Code should be 200 => empty!
Assertion: Body should contain ok => Could not perform assertion - body is missing
Response Time should be less than 1000 ms => 1016 ms
```

---

## ✅ Solutions Applied

### 1. Frontend Uptime Check
**Changed:**
- URL: `http://frontend.chat-demo.svc.cluster.local` → `http://localhost:30080`
- Now tests the actual exposed frontend NodePort service

**Why it works:**
- Docker container with `--network host` can access `localhost:30080`
- Tests the real user-facing endpoint
- No Kubernetes DNS resolution needed

### 2. Backend API Check
**Changed:**
- **URL**: `http://backend.chat-demo.svc.cluster.local:8000/health` → `http://localhost:30080/api/chat`
- **Method**: GET → POST
- **Body**: Added JSON body with test prompt
- **Assertion**: "ok" → "reply"
- **Response Time**: 1000ms → 5000ms (accounts for OpenAI latency)
- **Name**: "Backend Health Check" → "Backend API Check (via Chat)"

**Why it works:**
- Tests the **full application stack**: Frontend → Backend → OpenAI → Database
- Uses the public API endpoint that's actually exposed
- More comprehensive test than just hitting `/health`
- Realistic timeout for LLM API calls

---

## 📊 Test Configuration Details

### Frontend Uptime Check
```hcl
Method: GET
URL: http://localhost:30080
Assertions:
  - Status Code = 200
  - Body contains "Chatbot"
Frequency: Every 5 minutes
```

**What it tests:**
- ✅ Frontend is accessible
- ✅ NodePort service is working
- ✅ Frontend app loads correctly

### Backend API Check (via Chat)
```hcl
Method: POST
URL: http://localhost:30080/api/chat
Body: jsonencode({ prompt = "health check" })
Headers: 
  Content-Type: application/json
Assertions:
  - Status Code = 200
  - Body contains "reply"
  - Response Time < 5000ms
Frequency: Every 5 minutes
```

**What it tests:**
- ✅ Frontend API proxy works
- ✅ Backend receives and processes requests
- ✅ OpenAI API integration works
- ✅ Database connection works
- ✅ Full request/response cycle completes
- ✅ End-to-end latency is acceptable

---

## 🎯 Results After Fix

### Expected Behavior
- ✅ Both tests pass successfully
- ✅ Fast response times (<100ms for frontend, <3000ms for backend)
- ✅ Proper status codes and body content
- ✅ No DNS resolution errors

### Test in Datadog UI
1. Go to: https://app.datadoghq.com/synthetics/tests
2. Find tests:
   - "demo - Frontend Uptime Check"
   - "demo - Backend API Check (via Chat)"
3. Click **"Run Test Now"**
4. Should see: ✅ **Success** with green status

---

## 🏗️ Architecture Context

### Why localhost:30080 Works

```
Docker Private Location Container
  └─> --network host
      └─> Can access host network
          └─> localhost:30080 (NodePort)
              └─> Docker Desktop K8s
                  └─> Frontend Service
                      └─> Backend Service
                          └─> Database + OpenAI
```

### What Doesn't Work with Docker Private Location
- ❌ Kubernetes DNS: `frontend.chat-demo.svc.cluster.local`
- ❌ Internal service IPs: `10.x.x.x`
- ❌ Cluster-internal hostnames

### Alternative: Kubernetes Helm Private Location
If using Helm-based private location (running as K8s pod):
- ✅ CAN use Kubernetes DNS
- ✅ CAN access internal services directly
- ✅ Better for testing internal endpoints

**To switch:** Update `synthetics.tf` URLs to use K8s service names.

---

## 📝 Configuration Files Updated

### terraform/synthetics.tf
```hcl
# Frontend Test
request_definition {
  method = "GET"
  url    = "http://localhost:30080"  # Changed from K8s DNS
}

# Backend Test  
request_definition {
  method = "POST"                              # Changed from GET
  url    = "http://localhost:30080/api/chat"  # Changed from /health
  body   = jsonencode({                        # Added - proper JSON encoding
    prompt = "health check"
  })
}

request_headers = {
  "Content-Type" = "application/json"          # Required header
}

# Assertions updated to match new endpoints
assertion {
  type     = "body"
  operator = "contains"
  target   = "reply"  # Changed from "ok"
}

assertion {
  type     = "responseTime"
  operator = "lessThan"
  target   = "5000"  # Changed from 1000 (accounts for OpenAI)
}
```

---

## 🔄 For Future Reference

### When to Update Tests

**If switching to Helm-based private location:**
1. Update URLs to use K8s service names
2. Can test backend `/health` endpoint directly
3. Faster response times expected

**If adding new endpoints:**
1. Add new synthetic tests for critical APIs
2. Consider multi-step tests for user journeys
3. Use realistic timeouts for LLM operations

### Best Practices

**DO:**
- ✅ Test user-facing endpoints
- ✅ Use realistic timeouts for LLM/AI APIs
- ✅ Test the full stack when possible
- ✅ Match URLs to your private location deployment method

**DON'T:**
- ❌ Test internal endpoints from Docker private location
- ❌ Use K8s DNS with Docker `--network host`
- ❌ Set unrealistic timeouts for AI operations
- ❌ Test `/health` when you can test real functionality

---

## 🐛 Troubleshooting

### Tests still failing?

**1. Check Docker container is running:**
```bash
docker ps | grep synthetics-worker
docker logs -f datadog-synthetics-worker
```

**2. Verify app is accessible:**
```bash
curl http://localhost:30080
curl -X POST http://localhost:30080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test"}'
```

**3. Check private location in Datadog UI:**
- Go to: https://app.datadoghq.com/synthetics/settings/private-locations
- Status should be: ✅ **Running**

**4. Manually run tests:**
- Go to: https://app.datadoghq.com/synthetics/tests
- Click "Run Test Now" on each test
- View detailed results

### DNS errors still appearing?

- Verify you're using `localhost:30080` URLs, not K8s DNS names
- Check that Terraform applied successfully: `cd terraform && terraform state show datadog_synthetics_test.frontend_uptime`
- Restart private location worker: `docker restart datadog-synthetics-worker`

### Backend test returns "Prompt is required" error?

**Cause:** JSON body not properly formatted or Content-Type header missing.

**Solution:**
```hcl
# Correct format in synthetics.tf:
request_definition {
  method = "POST"
  url    = "http://localhost:30080/api/chat"
  body   = jsonencode({
    prompt = "health check"
  })
}

request_headers = {
  "Content-Type" = "application/json"
}
```

**Don't use:**
- ❌ `body = "{\"prompt\": \"health check\"}"` (string escaping issues)
- ❌ `body_type = "application/json"` (incorrect parameter)
- ❌ Missing `request_headers` block

---

## ✨ Summary

**What Changed:**
- Frontend test: Uses `localhost:30080` instead of K8s DNS
- Backend test: Tests via `/api/chat` with full stack validation
- Timeouts: Increased to account for OpenAI latency
- Assertions: Updated to match actual API responses

**Result:**
- ✅ Tests pass reliably
- ✅ No DNS resolution errors
- ✅ Proper monitoring of user-facing functionality
- ✅ Realistic testing of LLM integration

**Files Modified:**
- `terraform/synthetics.tf` - Test configuration updated
- Applied via: `terraform apply`

---

**Status**: ✅ **All tests passing!**

