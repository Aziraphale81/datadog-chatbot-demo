FROM python:3.12-slim

# Accept VERSION as build arg (git commit SHA)
ARG VERSION=dev
ENV DD_VERSION=$VERSION

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/

# Run with ddtrace
CMD ["ddtrace-run", "python", "-m", "app.main"]










