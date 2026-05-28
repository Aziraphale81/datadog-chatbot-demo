#!/usr/bin/env bash
# Restore chat-worker to a working state after Docker Desktop / cluster restarts.
#
# Why this exists:
# - Chaos demos ("Worker crash", "Queue backup") scale chat-worker to 0 replicas.
# - That setting is stored in Kubernetes and survives Docker Desktop restarts.
# - With 0 workers, /chat publishes to RabbitMQ but nothing consumes → UI times out with
#   "Something went wrong. Check backend or OpenAI key."
#
# Usage (run anytime the UI fails after starting Docker):
#   chmod +x scripts/ensure-chat-ready.sh && ./scripts/ensure-chat-ready.sh
#
set -euo pipefail

NS="${KUBE_NAMESPACE:-chat-demo}"

if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
  echo "Namespace '$NS' not found. Run scripts/setup.sh first." >&2
  exit 1
fi

if ! kubectl get deployment chat-worker -n "$NS" >/dev/null 2>&1; then
  echo "Deployment chat-worker not found in $NS. Run scripts/setup.sh or kubectl apply -f k8s/worker.yaml" >&2
  exit 1
fi

echo "Ensuring chat-worker has 1 replica (chaos demos can leave it at 0)..."
kubectl scale deployment/chat-worker -n "$NS" --replicas=1

echo "Waiting for rollout..."
kubectl rollout status deployment/chat-worker -n "$NS" --timeout=120s

echo ""
echo "chat-worker status:"
kubectl get pods -n "$NS" -l app=chat-worker -o wide

W=$(kubectl get pods -n "$NS" -l app=chat-worker --field-selector=status.phase=Running -o name 2>/dev/null | wc -l | tr -d ' ')
if [ "${W:-0}" -lt 1 ]; then
  echo "" >&2
  echo "Worker pod is not Running yet. If image is missing, build and load it:" >&2
  echo "  docker build -t chat-worker:latest ./worker" >&2
  echo "  # Docker Desktop K8s uses the local image when imagePullPolicy: Never" >&2
  exit 1
fi

echo ""
echo "Done. Try the UI at http://localhost:30080"
