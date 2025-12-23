FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY app /app/app

# Datadog defaults; overridden in k8s manifests
ENV DD_ENV=dev \
    DD_SERVICE=chat-backend \
    DD_SITE=datadoghq.com \
    DD_LOGS_INJECTION=true \
    DD_RUNTIME_METRICS_ENABLED=true \
    DD_TRACE_ENABLED=true \
    DD_LLMOBS_ENABLED=true \
    DD_APPSEC_ENABLED=false

CMD ["ddtrace-run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]


