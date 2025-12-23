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
echo "Step 2: Creating namespace..."
kubectl apply -f k8s/namespace.yaml

echo ""
echo "Step 3: Checking secrets..."
if ! kubectl get secret datadog-keys -n chat-demo >/dev/null 2>&1; then
    echo "⚠️  Datadog secrets not found!"
    echo "Please create them manually:"
    echo ""
    echo "  kubectl create secret generic datadog-keys -n chat-demo \\"
    echo "    --from-literal=api-key='<DD_API_KEY>' \\"
    echo "    --from-literal=app-key='<DD_APP_KEY>' \\"
    echo "    --from-literal=rum-client-token='<DD_RUM_CLIENT_TOKEN>' \\"
    echo "    --from-literal=rum-app-id='<DD_RUM_APP_ID>'"
    echo ""
    read -p "Press enter when secrets are created..."
fi

if ! kubectl get secret openai-key -n chat-demo >/dev/null 2>&1; then
    echo "⚠️  OpenAI secret not found!"
    echo "Please create it manually:"
    echo ""
    echo "  kubectl create secret generic openai-key -n chat-demo \\"
    echo "    --from-literal=openai-api-key='<OPENAI_API_KEY>'"
    echo ""
    read -p "Press enter when secret is created..."
fi

echo ""
echo "Step 4: Deploying Kubernetes resources..."
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

echo ""
echo "Step 5: Deploying Datadog resources via Terraform..."
cd terraform

if [ ! -f terraform.tfvars ]; then
    echo "⚠️  terraform.tfvars not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values."
    read -p "Press enter when ready..."
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

