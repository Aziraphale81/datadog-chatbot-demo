#!/bin/bash
set -e

echo "🔐 Datadog Private Location Setup"
echo "=================================="
echo ""

NAMESPACE="${NAMESPACE:-chat-demo}"
RELEASE_NAME="${RELEASE_NAME:-synthetics-private-location}"
CONFIG_FILE="${1}"
DEPLOYMENT_METHOD="${2:-auto}"  # auto, docker, or helm

if [ -z "$CONFIG_FILE" ]; then
    echo "Usage: $0 <path-to-private-location-config.json> [deployment-method]"
    echo ""
    echo "Deployment methods:"
    echo "  auto   - Auto-detect best method (default)"
    echo "  docker - Use Docker container (recommended for local dev)"
    echo "  helm   - Use Kubernetes Helm chart"
    echo ""
    echo "To get your private location config:"
    echo "  1. Go to: https://app.datadoghq.com/synthetics/settings/private-locations"
    echo "  2. Click '+ Private Location'"
    echo "  3. Enter name: 'docker-desktop-local'"
    echo "  4. Enter description: 'Local Docker Desktop for testing localhost apps'"
    echo "  5. Download the configuration file (worker-config-*.json)"
    echo "  6. Run: $0 /path/to/worker-config-*.json"
    echo ""
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "📁 Config file: $CONFIG_FILE"
echo ""

# Auto-detect architecture and choose deployment method
if [ "$DEPLOYMENT_METHOD" = "auto" ]; then
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        echo "🔍 Detected Apple Silicon (ARM64)"
        echo "   Recommendation: Docker (better ARM64 support)"
        DEPLOYMENT_METHOD="docker"
    else
        echo "🔍 Detected x86_64 architecture"
        echo "   Recommendation: Helm (native Kubernetes integration)"
        DEPLOYMENT_METHOD="helm"
    fi
    echo ""
fi

if [ "$DEPLOYMENT_METHOD" = "docker" ]; then
    echo "🐳 Deploying via Docker"
    echo "======================="
    echo ""
    
    # Check if Docker is running
    if ! docker ps > /dev/null 2>&1; then
        echo "❌ Error: Docker is not running"
        echo "   Start Docker Desktop and try again"
        exit 1
    fi
    
    echo "✅ Docker is running"
    echo ""
    
    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^datadog-synthetics-worker$"; then
        echo "⚠️  Container 'datadog-synthetics-worker' already exists"
        read -p "   Do you want to remove and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🗑️  Removing existing container..."
            docker stop datadog-synthetics-worker 2>/dev/null || true
            docker rm datadog-synthetics-worker 2>/dev/null || true
        else
            echo "❌ Aborted. To manually remove:"
            echo "   docker stop datadog-synthetics-worker && docker rm datadog-synthetics-worker"
            exit 1
        fi
    fi
    
    # Get absolute path to config file
    CONFIG_FILE_ABS=$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")
    
    echo "🚀 Starting Private Location worker container..."
    docker run -d \
        --name datadog-synthetics-worker \
        --platform linux/amd64 \
        --network host \
        -v "$CONFIG_FILE_ABS:/etc/datadog/synthetics-check-runner.json:ro" \
        datadog/synthetics-private-location-worker:latest
    
    echo "✅ Container started"
    echo ""
    
    # Wait a moment for container to start
    echo "⏳ Waiting for container to initialize..."
    sleep 5
    
    # Check container status
    echo "📊 Container Status:"
    docker ps --filter name=datadog-synthetics-worker --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Show logs
    echo "📜 Recent logs:"
    docker logs datadog-synthetics-worker --tail=20 2>&1 || echo "⚠️  Unable to fetch logs yet"
    echo ""
    
    echo "🎉 Docker Setup Complete!"
    echo ""
    echo "Useful commands:"
    echo "  View logs:      docker logs -f datadog-synthetics-worker"
    echo "  Check status:   docker ps | grep synthetics-worker"
    echo "  Stop:           docker stop datadog-synthetics-worker"
    echo "  Remove:         docker rm datadog-synthetics-worker"
    echo ""
    
elif [ "$DEPLOYMENT_METHOD" = "helm" ]; then
    echo "☸️  Deploying via Kubernetes Helm"
    echo "================================="
    echo ""
    echo "🎯 Namespace: $NAMESPACE"
    echo "📦 Release name: $RELEASE_NAME"
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
        echo "❌ Error: Namespace '$NAMESPACE' does not exist"
        echo "   Run: kubectl create namespace $NAMESPACE"
        exit 1
    fi
    
    echo "✅ Namespace exists"
    echo ""
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        echo "❌ Error: helm is not installed"
        echo "   Install helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    echo "✅ Helm is installed"
    echo ""

    # Add Datadog Helm repo if not already added
    echo "📚 Adding Datadog Helm repository..."
    if helm repo list 2>/dev/null | grep -q "^datadog"; then
        echo "   Datadog repo already exists, updating..."
        helm repo update datadog
    else
        helm repo add datadog https://helm.datadoghq.com
        helm repo update
    fi
    
    echo "✅ Helm repo ready"
    echo ""
    
    # Check if release already exists
    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "^$RELEASE_NAME"; then
        echo "⚠️  Release '$RELEASE_NAME' already exists in namespace '$NAMESPACE'"
        read -p "   Do you want to upgrade it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🔄 Upgrading existing release..."
            helm upgrade "$RELEASE_NAME" datadog/synthetics-private-location \
                --namespace "$NAMESPACE" \
                --set-file configFile="$CONFIG_FILE" \
                --set image.tag=latest
        else
            echo "❌ Aborted. To force reinstall, run:"
            echo "   helm uninstall $RELEASE_NAME -n $NAMESPACE"
            echo "   Then run this script again."
            exit 1
        fi
    else
        # Install the chart with latest tag for better ARM64 support
        echo "🚀 Installing Private Location Helm chart..."
        helm install "$RELEASE_NAME" datadog/synthetics-private-location \
            --namespace "$NAMESPACE" \
            --set-file configFile="$CONFIG_FILE" \
            --set image.tag=latest
    fi
    
    echo "✅ Helm chart deployed"
    echo ""
    
    # Wait for pod to be ready
    echo "⏳ Waiting for Private Location pod to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/instance="$RELEASE_NAME" \
        -n "$NAMESPACE" \
        --timeout=120s || echo "⚠️  Timeout waiting for pod, check status manually"
    
    echo ""
    
    # Show pod status
    echo "📊 Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
    echo ""
    
    # Show logs if pod exists
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "📜 Recent logs from $POD_NAME:"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" --tail=20 || echo "⚠️  Unable to fetch logs yet"
        echo ""
    fi
    
    echo "🎉 Helm Setup Complete!"
    echo ""
    echo "Useful commands:"
    echo "  View logs:      kubectl logs -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME -f"
    echo "  Check status:   helm status $RELEASE_NAME -n $NAMESPACE"
    echo "  Uninstall:      helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo ""
    
else
    echo "❌ Error: Unknown deployment method: $DEPLOYMENT_METHOD"
    echo "   Valid options: auto, docker, helm"
    exit 1
fi

echo "📍 Next Steps:"
echo "=============="
echo ""
echo "1. Verify in Datadog UI:"
echo "   https://app.datadoghq.com/synthetics/settings/private-locations"
echo "   (Should show 'Running' status with green indicator)"
echo ""
echo "2. Copy your Private Location ID from the UI"
echo "   Format: pl:xxxxx-xxxxx-xxxxx"
echo ""
echo "3. Add to terraform/terraform.tfvars:"
echo "   synthetics_private_location_id = \"pl:your-id-here\""
echo ""
echo "4. Apply Terraform changes:"
echo "   cd terraform && terraform apply"
echo ""
echo "5. Test your synthetic tests:"
echo "   https://app.datadoghq.com/synthetics/tests"
echo "   Click 'Run Test Now' - should now pass! ✅"
echo ""

