#!/bin/bash
set -e

echo "================================================"
echo "AI Chatbot + Datadog Demo Setup"
echo "================================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "terraform is required but not installed. Aborting." >&2; exit 1; }

# Check Kubernetes context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "docker-desktop" ]; then
    echo "Current kubectl context is '$CURRENT_CONTEXT'"
    read -p "Switch to docker-desktop context? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl config use-context docker-desktop
    else
        echo "Using current context: $CURRENT_CONTEXT"
    fi
fi

# Check if cluster is reachable
echo "Verifying Kubernetes cluster..."
kubectl cluster-info >/dev/null 2>&1 || { echo "Cannot reach Kubernetes cluster. Is Docker Desktop Kubernetes enabled?" >&2; exit 1; }

echo ""
echo "Step 1: Building Docker images..."
echo "Building backend..."
docker build -t chat-backend:latest ./backend

echo "Building frontend..."
# Get RUM credentials from secrets if they exist, otherwise prompt
if kubectl get secret datadog-keys -n chat-demo >/dev/null 2>&1; then
    DD_RUM_CLIENT_TOKEN=$(kubectl get secret datadog-keys -n chat-demo -o jsonpath='{.data.rum-client-token}' 2>/dev/null | base64 -d || echo "")
    DD_RUM_APP_ID=$(kubectl get secret datadog-keys -n chat-demo -o jsonpath='{.data.rum-app-id}' 2>/dev/null | base64 -d || echo "")
fi

docker build -t chat-frontend:latest \
  ${DD_RUM_CLIENT_TOKEN:+--build-arg NEXT_PUBLIC_DD_CLIENT_TOKEN=$DD_RUM_CLIENT_TOKEN} \
  ${DD_RUM_APP_ID:+--build-arg NEXT_PUBLIC_DD_APP_ID=$DD_RUM_APP_ID} \
  --build-arg NEXT_PUBLIC_DD_SITE=datadoghq.com \
  --build-arg NEXT_PUBLIC_DD_SERVICE=chat-frontend \
  --build-arg NEXT_PUBLIC_DD_ENV=demo \
  --build-arg BACKEND_INTERNAL_BASE=http://backend.chat-demo.svc.cluster.local:8000 \
  ./frontend

echo ""
echo "Step 2: Cleaning up any previous Datadog installations..."
# Remove old Datadog Operator if it exists
if helm list -n datadog-operator 2>/dev/null | grep -q "datadog-operator"; then
    echo "Found old Datadog Operator installation, removing..."
    helm uninstall datadog-operator -n datadog-operator 2>/dev/null || true
    kubectl delete namespace datadog-operator --ignore-not-found=true
fi

# Remove Datadog Agent if installed in chat-demo namespace
if helm list -n chat-demo 2>/dev/null | grep -q "datadog-agent"; then
    echo "Found existing Datadog Agent in chat-demo, removing..."
    helm uninstall datadog-agent -n chat-demo 2>/dev/null || true
fi

# Clean up Datadog CRDs if they exist (from old Operator install)
echo "Cleaning up Datadog CRDs..."
kubectl delete crd datadogagents.datadoghq.com --ignore-not-found=true
kubectl delete crd datadogmetrics.datadoghq.com --ignore-not-found=true
kubectl delete crd datadogmonitors.datadoghq.com --ignore-not-found=true
kubectl delete crd datadogpodautoscalers.datadoghq.com --ignore-not-found=true

echo ""
echo "Step 3: Creating namespace..."
kubectl apply -f k8s/namespace.yaml

echo ""
echo "Step 4: Configuring secrets..."
if ! kubectl get secret datadog-keys -n chat-demo >/dev/null 2>&1; then
    echo "📝 Let's set up your Datadog credentials"
    echo ""
    read -p "Enter your Datadog API Key: " DD_API_KEY
    read -p "Enter your Datadog App Key: " DD_APP_KEY
    read -p "Enter your RUM Client Token: " DD_RUM_CLIENT_TOKEN
    read -p "Enter your RUM Application ID: " DD_RUM_APP_ID
    
    echo ""
    echo "Creating Datadog secrets..."
    kubectl create secret generic datadog-keys -n chat-demo \
        --from-literal=api-key="$DD_API_KEY" \
        --from-literal=app-key="$DD_APP_KEY" \
        --from-literal=rum-client-token="$DD_RUM_CLIENT_TOKEN" \
        --from-literal=rum-app-id="$DD_RUM_APP_ID"
    
    if [ $? -eq 0 ]; then
        echo "✅ Datadog secrets created successfully"
    else
        echo "❌ Failed to create Datadog secrets. Please check your inputs."
        exit 1
    fi
else
    echo "✅ Datadog secrets already exist"
fi

echo ""
if ! kubectl get secret openai-key -n chat-demo >/dev/null 2>&1; then
    echo "📝 Let's set up your OpenAI credentials"
    echo ""
    read -p "Enter your OpenAI API Key: " OPENAI_API_KEY
    
    echo ""
    echo "Creating OpenAI secret..."
    kubectl create secret generic openai-key -n chat-demo \
        --from-literal=openai-api-key="$OPENAI_API_KEY"
    
    if [ $? -eq 0 ]; then
        echo "✅ OpenAI secret created successfully"
    else
        echo "❌ Failed to create OpenAI secret. Please check your input."
        exit 1
    fi
else
    echo "✅ OpenAI secret already exists"
fi

echo ""
echo "Step 5: Deploying Kubernetes resources..."
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

echo ""
echo "Step 6: Deploying Datadog resources via Terraform..."
cd terraform

if [ ! -f terraform.tfvars ]; then
    echo "📝 Creating terraform.tfvars from your Datadog credentials..."
    echo ""
    
    # Use the DD keys we collected earlier if available
    if [ -z "$DD_API_KEY" ]; then
        DD_API_KEY=$(kubectl get secret datadog-keys -n chat-demo -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || echo "")
        DD_APP_KEY=$(kubectl get secret datadog-keys -n chat-demo -o jsonpath='{.data.app-key}' 2>/dev/null | base64 -d || echo "")
    fi
    
    if [ -z "$DD_API_KEY" ]; then
        echo "⚠️  Could not retrieve Datadog keys. Please enter them again:"
        read -p "Datadog API Key: " DD_API_KEY
        read -p "Datadog App Key: " DD_APP_KEY
    fi
    
    # Generate terraform.tfvars
    cat > terraform.tfvars <<EOF
# Auto-generated by setup.sh
datadog_api_key = "$DD_API_KEY"
datadog_app_key = "$DD_APP_KEY"
datadog_api_url = "https://api.datadoghq.com"
datadog_site    = "datadoghq.com"

environment   = "demo"
cluster_name  = "docker-desktop"
namespace     = "chat-demo"

backend_service  = "chat-backend"
frontend_service = "chat-frontend"

# Optional: Update these with your alert destinations
alert_email         = "your-email@example.com"
alert_slack_channel = "@slack-alerts"
EOF
    
    echo "✅ terraform.tfvars created"
    echo "💡 Tip: Edit terraform.tfvars to customize alert_email and alert_slack_channel"
    echo ""
fi

terraform init
terraform plan
read -p "Apply Terraform changes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -auto-approve
else
    echo "Skipping Terraform apply. You can run it manually later with: cd terraform && terraform apply"
fi

cd ..

echo ""
echo "================================================"
echo "✅ Setup complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Wait for all pods to be Ready:"
echo "   kubectl get pods -n chat-demo"
echo ""
echo "2. Access the application:"
echo "   http://localhost:30080"
echo ""
echo "3. View your Datadog dashboard:"
terraform -chdir=terraform output -raw dashboard_url 2>/dev/null || echo "   (Run 'terraform apply' in terraform/ to get dashboard URL)"
echo ""
echo "4. Check monitors and SLOs in Datadog UI"
echo ""

