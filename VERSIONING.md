# Dynamic Version Tracking with Git Commit SHA

This project implements **dynamic versioning** using Git commit SHAs for deployment tracking in Datadog.

## How It Works

### Version Extraction
The `scripts/setup.sh` automatically extracts the short git commit SHA (7 characters) at the start:

```bash
VERSION=$(git rev-parse --short=7 HEAD)
# Example: abc1234
```

### Version Injection Points

The version is injected at **build time** and **deployment time**:

#### 1. Docker Builds
All three services receive the version as a build arg:
```bash
docker build --build-arg VERSION=$VERSION ./backend
docker build --build-arg VERSION=$VERSION ./worker
docker build --build-arg VERSION=$VERSION ./frontend
```

#### 2. Dockerfiles
Each Dockerfile accepts the VERSION and sets it as `DD_VERSION`:
```dockerfile
ARG VERSION=dev
ENV DD_VERSION=$VERSION
```

#### 3. Kubernetes Deployments
The setup script dynamically injects the version into:
- Pod labels: `tags.datadoghq.com/version: "<version>"`
- Environment variables: `DD_VERSION: "<version>"`

This happens via `sed` replacement during `kubectl apply`.

## Datadog Benefits

### 1. Deployment Tracking
- Automatic deployment markers in APM graphs
- Track when new versions are deployed
- Correlate errors/latency with specific commits

### 2. Source Code Integration
With `git.commit.sha` and `git.repository_url` tags, Datadog shows:
- **"View in GitHub"** links from traces
- Direct jump to exact code that generated the trace
- Commit information in error tracking

### 3. Version Comparison
- Compare metrics between versions
- Identify performance regressions
- Track error rates by version

### 4. Error Grouping
- Errors are grouped by version
- See which version introduced an issue
- Track fix deployment

## What Gets Tagged

All telemetry is tagged with the version:
- **APM Traces**: `version:<sha>`
- **Logs**: `version:<sha>` (via unified service tagging)
- **Metrics**: `version:<sha>`
- **RUM Sessions**: `version:<sha>`
- **Profiling Data**: `version:<sha>`

## Manual Deployment

If deploying manually (not using `setup.sh`), export the VERSION first:

```bash
# Extract version
export VERSION=$(git rev-parse --short=7 HEAD)

# Build with version
docker build --build-arg VERSION=$VERSION -t chat-backend:latest ./backend
docker build --build-arg VERSION=$VERSION -t chat-worker:latest ./worker
docker build --build-arg VERSION=$VERSION \
  --build-arg NEXT_PUBLIC_DD_VERSION=$VERSION \
  -t chat-frontend:latest ./frontend

# Deploy with version injection
cat k8s/backend.yaml | \
  sed "s|tags.datadoghq.com/version: \"1.0.0\"|tags.datadoghq.com/version: \"$VERSION\"|g" | \
  sed "s|value: \"1.0.0\"|value: \"$VERSION\"|g" | \
  kubectl apply -f -
```

## Verify Version Deployment

Check the version in Datadog:

1. **APM Service Page**: Shows deployed versions
2. **APM Trace**: Look for `version` tag
3. **Infrastructure → Processes**: Filter by version
4. **Deployment Tracking**: Dashboard shows version timeline

Or check in Kubernetes:
```bash
# Check pod labels
kubectl get pods -n chat-demo -l app=backend -o jsonpath='{.items[0].metadata.labels}'

# Check environment variable
kubectl exec -n chat-demo deployment/backend -- env | grep DD_VERSION
```

## Version Format

**Current**: 7-character short SHA (e.g., `abc1234`)

### Alternative Formats

You can modify `scripts/setup.sh` to use different version formats:

#### Full SHA
```bash
VERSION=$(git rev-parse HEAD)
# Example: abc1234567890abcdef1234567890abcdef12345
```

#### Semantic Version + SHA
```bash
VERSION="1.0.0+$(git rev-parse --short HEAD)"
# Example: 1.0.0+abc1234
```

#### Date-based
```bash
VERSION="$(date +%Y%m%d)-$(git rev-parse --short HEAD)"
# Example: 20260114-abc1234
```

## Troubleshooting

### Version shows as "dev"
**Cause**: Not in a git repository or git not available

**Solution**: Ensure you're in a git repository and git is installed

### Deployment not tracked in Datadog
**Cause**: Version tags not properly set

**Solution**: Verify with:
```bash
kubectl get pods -n chat-demo -l app=backend -o yaml | grep version
```

Should show both:
- `tags.datadoghq.com/version: "<sha>"`
- `DD_VERSION: "<sha>"`

### Old version still showing
**Cause**: Pods not restarted after version change

**Solution**: Force rollout:
```bash
kubectl rollout restart deployment/backend -n chat-demo
kubectl rollout restart deployment/worker -n chat-demo
kubectl rollout restart deployment/frontend -n chat-demo
```

## Best Practices

1. **Always commit before deploying**: Ensures version tracking is accurate
2. **Use meaningful commit messages**: Appears in Datadog deployment tracking
3. **Tag releases**: Git tags also appear in Datadog for major versions
4. **Don't override DD_VERSION**: Let the automated system handle it
5. **Check version after deploy**: Verify the correct version is active

## References

- [Datadog Unified Service Tagging](https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/)
- [Datadog Deployment Tracking](https://docs.datadoghq.com/tracing/deployment_tracking/)
- [Source Code Integration](https://docs.datadoghq.com/integrations/guide/source-code-integration/)

