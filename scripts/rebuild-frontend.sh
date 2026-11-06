#!/usr/bin/env bash
# Rebuild and redeploy only the frontend (for example after a feature flag change),
# without re-running Terraform or touching the other services.
#
# Usage: ./scripts/rebuild-frontend.sh
# Optional: DD_FLAGS_ENV=<feature flags environment> (defaults to the RUM env "demo")
set -euo pipefail
cd "$(dirname "$0")/.."

NS=chat-demo
VERSION=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "1.0.0")
DD_ENV=demo
DD_FLAGS_ENV=${DD_FLAGS_ENV:-$DD_ENV}

DD_RUM_CLIENT_TOKEN=$(kubectl get secret datadog-keys -n "$NS" -o jsonpath='{.data.rum-client-token}' | base64 -d)
DD_RUM_APP_ID=$(kubectl get secret datadog-keys -n "$NS" -o jsonpath='{.data.rum-app-id}' | base64 -d)
# Optional: RUM remote configuration ID (Browser SDK >= 7.13)
DD_RUM_REMOTE_CONFIG_ID=$(kubectl get secret datadog-keys -n "$NS" -o jsonpath='{.data.rum-remote-config-id}' 2>/dev/null | base64 -d || true)
if [ -z "$DD_RUM_CLIENT_TOKEN" ] || [ -z "$DD_RUM_APP_ID" ]; then
  echo "Missing rum-client-token or rum-app-id in $NS/datadog-keys" >&2
  exit 1
fi

SOURCEMAP_SECRET_OPT=()
DD_API_KEY=$(kubectl get secret datadog-keys -n "$NS" -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || true)
if [ -n "$DD_API_KEY" ]; then
  export DD_API_KEY
  SOURCEMAP_SECRET_OPT=(--secret id=DD_API_KEY,env=DD_API_KEY)
fi

echo "Building chat-frontend:latest (version $VERSION, flags env $DD_FLAGS_ENV)"
DOCKER_BUILDKIT=1 docker build -t chat-frontend:latest \
  --build-arg "NEXT_PUBLIC_DD_CLIENT_TOKEN=$DD_RUM_CLIENT_TOKEN" \
  --build-arg "NEXT_PUBLIC_DD_APP_ID=$DD_RUM_APP_ID" \
  --build-arg "NEXT_PUBLIC_DD_RUM_REMOTE_CONFIG_ID=$DD_RUM_REMOTE_CONFIG_ID" \
  --build-arg NEXT_PUBLIC_DD_SITE=datadoghq.com \
  --build-arg NEXT_PUBLIC_DD_SERVICE=chat-frontend \
  --build-arg "NEXT_PUBLIC_DD_ENV=$DD_ENV" \
  --build-arg "NEXT_PUBLIC_DD_FLAGS_ENV=$DD_FLAGS_ENV" \
  --build-arg "NEXT_PUBLIC_DD_VERSION=$VERSION" \
  --build-arg BACKEND_INTERNAL_BASE=http://backend.chat-demo.svc.cluster.local:8000 \
  "${SOURCEMAP_SECRET_OPT[@]}" \
  ./frontend

sed -e "s|tags.datadoghq.com/version: \"1.0.0\"|tags.datadoghq.com/version: \"$VERSION\"|g" \
    -e "s|value: \"1.0.0\"|value: \"$VERSION\"|g" k8s/frontend.yaml | kubectl apply -f -
kubectl rollout restart deployment/frontend -n "$NS"
kubectl rollout status deployment/frontend -n "$NS" --timeout=180s
echo "Frontend redeployed: http://localhost:30080"
