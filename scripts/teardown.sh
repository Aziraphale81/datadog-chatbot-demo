#!/bin/bash
set -e

echo "================================================"
echo "AI Chatbot + Datadog Demo Teardown"
echo "================================================"
echo ""

read -p "This will delete all Kubernetes resources and Terraform-managed Datadog resources. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Step 1: Destroying Terraform resources..."
cd terraform
if [ -f terraform.tfstate ]; then
    terraform destroy -auto-approve || {
        echo "⚠️  Terraform destroy encountered errors (possibly resources already deleted manually)"
        read -p "Remove Terraform state files to reset? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f terraform.tfstate terraform.tfstate.backup
            echo "✅ Terraform state cleaned up"
        fi
    }
else
    echo "No Terraform state found, skipping..."
fi
cd ..

echo ""
echo "Step 2: Deleting Kubernetes resources..."
kubectl delete -f k8s/frontend.yaml --ignore-not-found=true
kubectl delete -f k8s/backend.yaml --ignore-not-found=true
kubectl delete -f k8s/postgres.yaml --ignore-not-found=true

echo ""
echo "Step 3: Uninstalling Datadog Agent..."
helm uninstall datadog-agent -n chat-demo --ignore-not-found

echo ""
echo "Step 4: Deleting namespace (this will clean up secrets and PVCs)..."
kubectl delete namespace chat-demo --ignore-not-found=true

echo ""
echo "Step 5: Cleaning up Datadog CRDs..."
kubectl delete crd datadogagents.datadoghq.com --ignore-not-found=true
kubectl delete crd datadogmetrics.datadoghq.com --ignore-not-found=true
kubectl delete crd datadogmonitors.datadoghq.com --ignore-not-found=true
kubectl delete crd datadogpodautoscalers.datadoghq.com --ignore-not-found=true
echo "✅ Datadog CRDs cleaned up"

echo ""
echo "Step 6: Cleaning up Docker images..."
read -p "Delete local Docker images? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi chat-backend:latest chat-frontend:latest 2>/dev/null || echo "Images already removed"
fi

echo ""
echo "================================================"
echo "✅ Teardown complete!"
echo "================================================"
echo ""
echo "💡 Tip: To start fresh, run './scripts/setup.sh'"

