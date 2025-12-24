# Private Location Quick Start

## 🚀 Get Your Private Location Running in 5 Minutes

### Step 1: Get Configuration File

1. Go to: https://app.datadoghq.com/synthetics/settings/private-locations
2. Click **"+ Private Location"**
3. Fill in:
   - **Name:** `docker-desktop-local`
   - **Description:** `Local Docker Desktop for testing localhost apps`
4. Click **"Save Location and Generate Configuration File"**
5. **Download** the config file (e.g., `worker-config-local-*.json`)
6. **Copy the Private Location ID** (format: `pl:xxxxx-xxxxx-xxxxx`)

---

### Step 2: Deploy with Automated Script ⭐

The script auto-detects your system and chooses the best deployment method:
- **Apple Silicon (M1/M2/M3)**: Uses Docker (better ARM64 support)
- **Intel Macs/Linux**: Uses Kubernetes Helm (native integration)

```bash
# Run automated setup (auto-detects best method)
./scripts/setup-private-location.sh ./worker-config-local-*.json

# Or force a specific method:
./scripts/setup-private-location.sh ./worker-config-local-*.json docker
./scripts/setup-private-location.sh ./worker-config-local-*.json helm
```

The script will:
- ✅ Check prerequisites
- ✅ Deploy the private location worker
- ✅ Show you the logs
- ✅ Provide next steps

---

### Alternative: Manual Deployment

#### Option A: Docker (Recommended for Apple Silicon) ⭐
```bash
# Run container
docker run -d \
  --name datadog-synthetics-worker \
  --platform linux/amd64 \
  --network host \
  -v $(pwd)/worker-config-local-*.json:/etc/datadog/synthetics-check-runner.json:ro \
  datadog/synthetics-private-location-worker:latest

# Verify it's running
docker ps | grep synthetics-worker
docker logs -f datadog-synthetics-worker
```

#### Option B: Kubernetes with Helm
```bash
# Add Datadog Helm repo
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Install using Helm
helm install synthetics-private-location \
  datadog/synthetics-private-location \
  --namespace chat-demo \
  --set-file configFile=./worker-config-local-*.json \
  --set image.tag=latest

# Verify it's running
kubectl get pods -n chat-demo -l app.kubernetes.io/instance=synthetics-private-location
kubectl logs -n chat-demo -l app.kubernetes.io/instance=synthetics-private-location -f
```

---

### Step 3: Update Terraform

Edit `terraform/terraform.tfvars`:
```hcl
synthetics_private_location_id = "pl:xxxxx-xxxxx-xxxxx"  # Your Private Location ID
```

Apply changes:
```bash
cd terraform
terraform apply
```

---

### Step 4: Verify in Datadog

1. Check Private Location status: https://app.datadoghq.com/synthetics/settings/private-locations
   - Should show: ✅ **Running** (green)

2. Check Synthetic Tests: https://app.datadoghq.com/synthetics/tests
   - Click **"Run Test Now"** on any test
   - Should now succeed with your private location

---

## 📊 What You Get

### Before Private Location:
- ❌ Tests fail (can't reach localhost from public locations)
- ❌ Can't test internal K8s services

### After Private Location:
- ✅ Tests run successfully from inside your cluster
- ✅ Can test `localhost:30080` and internal services
- ✅ Fast response times (local network)
- ✅ Real monitoring of your local app

---

## 🔍 Troubleshooting

### Private Location shows "Disconnected"
```bash
# Docker
docker logs -f datadog-synthetics-worker
docker restart datadog-synthetics-worker

# Kubernetes (Helm)
kubectl logs -n chat-demo -l app.kubernetes.io/instance=synthetics-private-location -f
helm upgrade synthetics-private-location datadog/synthetics-private-location \
  --namespace chat-demo \
  --set-file configFile=./worker-config-*.json \
  --set image.tag=latest
```

### Tests still failing
1. Verify private location is "Running" in UI
2. Check test uses your private location (not aws:us-east-1)
3. Run `terraform apply` again to update test configuration

---

## 📚 Full Documentation

See [PRIVATE_LOCATION_SETUP.md](PRIVATE_LOCATION_SETUP.md) for:
- Detailed setup instructions
- Network access information
- Advanced configuration
- Complete troubleshooting guide

---

**That's it!** Your Private Location is now running and your synthetic tests should work. 🎉

