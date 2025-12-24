# Datadog Synthetic Monitoring Private Location Setup

This guide shows how to set up a Datadog Private Location to run synthetic tests against your local application.

## Why Use a Private Location?

Your app runs on `localhost:30080` (Docker Desktop Kubernetes), which isn't accessible from Datadog's public synthetic testing locations. A Private Location allows you to:

- ✅ Test internal/localhost applications
- ✅ Access Kubernetes internal services
- ✅ Run tests from your own infrastructure
- ✅ Test applications behind firewalls/VPNs

---

## Prerequisites

1. **Create Private Location in Datadog UI:**
   - Go to: https://app.datadoghq.com/synthetics/settings/private-locations
   - Click **"+ Private Location"**
   - Enter name: `docker-desktop-local`
   - Enter description: `Local Docker Desktop for testing localhost apps`
   - Click **"Save Location and Generate Configuration File"**
   - **Download the configuration file** (e.g., `private-location-config.json`)

2. **Save the Private Location ID:**
   - After creating, you'll see the ID in format: `pl:your-private-location-id-here`
   - Copy this ID - you'll need it for Terraform

---

## Option 1: Kubernetes Deployment (RECOMMENDED)

✅ **Best for:** Running alongside your app in the same cluster  
✅ **Advantages:** Access to internal K8s services, managed by kubectl, consistent with your setup

### Step 1: Deploy Private Location Worker

```bash
# Run the automated setup script
./scripts/setup-private-location.sh /path/to/private-location-config.json
```

This script will:
1. Create a ConfigMap from your config file
2. Deploy the Private Location worker as a Kubernetes deployment
3. Wait for it to become ready
4. Show you the logs

### Step 2: Verify Deployment

```bash
# Check pod status
kubectl get pods -n chat-demo -l app=synthetics-private-location

# View logs
kubectl logs -n chat-demo -l app=synthetics-private-location -f

# Check in Datadog UI
# Go to: https://app.datadoghq.com/synthetics/settings/private-locations
# Your location should show "Running" with green status
```

### Step 3: Update Terraform Configuration

Add your Private Location ID to `terraform/terraform.tfvars`:

```hcl
synthetics_private_location_id = "pl:your-private-location-id-here"
```

### Step 4: Apply Terraform Changes

```bash
cd terraform
terraform plan   # Review changes
terraform apply  # Deploy updated synthetic tests
```

Your synthetic tests will now:
- Use the private location instead of public locations
- Test `http://frontend.chat-demo.svc.cluster.local` (internal service)
- Run from inside your cluster with full network access

---

## Option 2: Docker Container (Alternative)

✅ **Best for:** Simple standalone deployment, testing outside K8s  
⚠️ **Note:** Can access `localhost:30080` but NOT internal K8s services

### Step 1: Run Private Location Container

```bash
docker run -d \
  --name datadog-synthetics-worker \
  --network host \
  -v /path/to/private-location-config.json:/etc/datadog/synthetics-check-runner.json:ro \
  gcr.io/datadoghq/synthetics-private-location-worker:latest
```

**Important:** Using `--network host` allows the container to access `localhost:30080`

### Step 2: Verify Container

```bash
# Check container status
docker ps | grep synthetics-worker

# View logs
docker logs -f datadog-synthetics-worker

# Check health
docker exec datadog-synthetics-worker wget -q -O- http://localhost:8080/liveness
```

### Step 3: Update Terraform Configuration

For Docker deployment, keep the URL as `http://localhost:30080`:

**In `terraform/terraform.tfvars`:**
```hcl
synthetics_private_location_id = "pl:your-private-location-id-here"
```

**Then modify `terraform/synthetics.tf`** to NOT use internal service URL for Docker:
```hcl
# Keep frontend test URL as localhost for Docker deployment
url = "http://localhost:30080"
```

---

## Testing Your Private Location

### 1. Check Private Location Status

Go to: https://app.datadoghq.com/synthetics/settings/private-locations

You should see:
- ✅ **Status:** Running (green)
- ✅ **Workers:** 1 active
- ✅ **Last Seen:** Just now

### 2. Manually Trigger Synthetic Tests

Go to: https://app.datadoghq.com/synthetics/tests

- Find your tests: `demo - Frontend Uptime Check` and `demo - Backend Health Check`
- Click **"Run Test Now"**
- Tests should now succeed with your private location

### 3. View Test Results

- Click on a test
- Check **"Locations"** - should show your private location
- View **"Results"** - should see successful test runs
- Check **"Response Time"** - should be very fast (local network)

---

## Network Access from Private Location

### Kubernetes Deployment
The private location pod can access:

✅ Frontend: `http://frontend.chat-demo.svc.cluster.local`  
✅ Backend: `http://backend.chat-demo.svc.cluster.local:8000`  
✅ Postgres: `http://postgres.chat-demo.svc.cluster.local:5432`  
✅ External URLs: Internet access for multi-step tests

### Docker Deployment
The private location container can access:

✅ Frontend: `http://localhost:30080` (via --network host)  
❌ Backend internal service: Not accessible  
❌ Postgres internal service: Not accessible  
✅ External URLs: Internet access

**Recommendation:** Use Kubernetes deployment for full access to internal services.

---

## Updating Synthetic Tests

### Important: URL Configuration by Deployment Method

**Docker Private Location (--network host):**
- ✅ Use `http://localhost:30080` for frontend
- ✅ Use `http://localhost:30080/api/*` for API endpoints
- ❌ Cannot use Kubernetes DNS names

**Kubernetes Helm Private Location:**
- ✅ Can use internal K8s service URLs
- ✅ Better for testing internal services directly

### Example Configurations

After deploying the Private Location, update your tests:

### Example: Frontend Test (K8s deployment)
```hcl
resource "datadog_synthetics_test" "frontend_uptime" {
  # ...
  request_definition {
    method = "GET"
    url    = "http://frontend.chat-demo.svc.cluster.local"
  }
  
  locations = ["pl:your-private-location-id"]
  # ...
}
```

### Example: Backend Health Test
```hcl
resource "datadog_synthetics_test" "backend_health" {
  # ...
  request_definition {
    method = "GET"
    url    = "http://backend.chat-demo.svc.cluster.local:8000/health"
  }
  
  locations = ["pl:your-private-location-id"]
  # ...
}
```

The Terraform configuration in this repo already handles this automatically based on whether `synthetics_private_location_id` is set.

---

## Monitoring Private Location Health

### View Logs (Kubernetes)
```bash
kubectl logs -n chat-demo -l app=synthetics-private-location -f
```

### View Logs (Docker)
```bash
docker logs -f datadog-synthetics-worker
```

### Check Resource Usage (Kubernetes)
```bash
kubectl top pod -n chat-demo -l app=synthetics-private-location
```

### Health Endpoints
- **Liveness:** `http://localhost:8080/liveness`
- **Readiness:** `http://localhost:8080/readiness`

---

## Troubleshooting

### Private Location shows "Disconnected" in UI

**Kubernetes:**
```bash
# Check pod status
kubectl get pods -n chat-demo -l app=synthetics-private-location

# Check logs for errors
kubectl logs -n chat-demo -l app=synthetics-private-location

# Verify ConfigMap exists
kubectl get configmap synthetics-private-location-config -n chat-demo

# Restart deployment
kubectl rollout restart deployment/synthetics-private-location -n chat-demo
```

**Docker:**
```bash
# Check container status
docker ps -a | grep synthetics-worker

# Restart container
docker restart datadog-synthetics-worker

# Check logs
docker logs datadog-synthetics-worker
```

### Synthetic Tests Still Failing

1. **Verify Private Location is Running:**
   - Check UI: https://app.datadoghq.com/synthetics/settings/private-locations
   - Should show green "Running" status

2. **Check Test Configuration:**
   - Go to test in UI
   - Verify **Locations** includes your private location
   - Click **"Run Test Now"** to test immediately

3. **Network Connectivity:**
   - For K8s: Test from within the pod
     ```bash
     kubectl exec -it -n chat-demo deployment/synthetics-private-location -- sh
     # Inside pod:
     wget -O- http://frontend.chat-demo.svc.cluster.local
     wget -O- http://backend.chat-demo.svc.cluster.local:8000/health
     ```
   
   - For Docker: Test from container
     ```bash
     docker exec -it datadog-synthetics-worker sh
     # Inside container:
     wget -O- http://localhost:30080
     ```

4. **Check Terraform Variables:**
   ```bash
   cd terraform
   terraform console
   # Type: var.synthetics_private_location_id
   # Should output your private location ID, not empty string
   ```

### Configuration File Issues

If the config file is invalid:

```bash
# Kubernetes: Update ConfigMap
kubectl delete configmap synthetics-private-location-config -n chat-demo
kubectl create configmap synthetics-private-location-config \
  -n chat-demo \
  --from-file=config=/path/to/new-config.json

# Restart deployment to pick up new config
kubectl rollout restart deployment/synthetics-private-location -n chat-demo

# Docker: Stop and recreate with new config
docker stop datadog-synthetics-worker
docker rm datadog-synthetics-worker
docker run -d \
  --name datadog-synthetics-worker \
  --network host \
  -v /path/to/new-config.json:/etc/datadog/synthetics-check-runner.json:ro \
  gcr.io/datadoghq/synthetics-private-location-worker:latest
```

---

## Cleanup

### Remove Kubernetes Deployment
```bash
kubectl delete -f k8s/synthetics-private-location.yaml
kubectl delete configmap synthetics-private-location-config -n chat-demo
```

### Remove Docker Container
```bash
docker stop datadog-synthetics-worker
docker rm datadog-synthetics-worker
```

### Delete Private Location in Datadog
1. Go to: https://app.datadoghq.com/synthetics/settings/private-locations
2. Click the trash icon next to your private location
3. Confirm deletion

**Note:** Update your `terraform.tfvars` to remove the private location ID and run `terraform apply` to revert synthetic tests to public locations.

---

## Cost Considerations

- **Private Location Workers:** No additional charge for the worker itself
- **Synthetic Test Runs:** Same pricing as public location tests
- **Resource Usage:** 
  - K8s: ~200m CPU, ~256Mi memory (minimal impact)
  - Docker: Similar resource usage

Private Locations don't increase synthetic test costs - you pay the same per-test rate regardless of location type.

---

## Next Steps

After setting up your Private Location:

1. ✅ Verify tests are passing in Datadog UI
2. ✅ Set up alerts for Private Location downtime
3. ✅ Create additional synthetic tests:
   - API tests for critical endpoints
   - Multi-step API tests for user flows
   - Browser tests (requires additional config)

---

## References

- [Datadog Private Locations Documentation](https://docs.datadoghq.com/synthetics/private_locations/)
- [Private Location Configuration](https://docs.datadoghq.com/synthetics/private_locations/configuration/)
- [Synthetic Monitoring Guide](https://docs.datadoghq.com/synthetics/)

