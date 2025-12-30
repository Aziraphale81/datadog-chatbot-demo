# Service Level Objectives

# Backend API availability SLO (99.5% over 30 days)
resource "datadog_service_level_objective" "backend_availability" {
  name        = "${var.backend_service} API Availability"
  type        = "metric"
  description = "99.5% of requests should succeed (non-5xx responses)"

  query {
    numerator   = "sum:trace.http.request.hits{service:${var.backend_service},env:${var.environment},!http.status_code:5*}.as_count()"
    denominator = "sum:trace.http.request.hits{service:${var.backend_service},env:${var.environment}}.as_count()"
  }

  thresholds {
    timeframe = "30d"
    target    = 99.5
    warning   = 99.7
  }

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "team:chatbot",
    "managed_by:terraform"
  ]
}

# Backend API latency SLO (95% of requests under 2s threshold)
resource "datadog_service_level_objective" "backend_latency" {
  name        = "${var.backend_service} API Latency (p95)"
  type        = "monitor"
  description = "95% of requests should complete within 2 seconds"

  monitor_ids = [datadog_monitor.backend_latency_p95.id]

  thresholds {
    timeframe = "7d"
    target    = 95.0
    warning   = 97.0
  }

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "team:platform",
    "category:latency",
    "managed_by:terraform"
  ]
}

# Frontend RUM error rate SLO
resource "datadog_service_level_objective" "frontend_error_rate" {
  name        = "${var.frontend_service} Error-Free Sessions"
  type        = "metric"
  description = "99% of RUM sessions should be error-free"

  query {
    numerator   = "sum:rum.measure.view.error_free{service:${var.frontend_service},env:${var.environment}}.as_count()"
    denominator = "sum:rum.measure.view{service:${var.frontend_service},env:${var.environment}}.as_count()"
  }

  thresholds {
    timeframe = "7d"
    target    = 99.0
    warning   = 99.5
  }

  tags = [
    "service:${var.frontend_service}",
    "env:${var.environment}",
    "category:rum",
    "managed_by:terraform"
  ]
}

# === New SLOs for Enhanced Coverage ===

# 1. End-to-End Chat Response Availability SLO (Monitor-based composite)
resource "datadog_service_level_objective" "chat_e2e_availability" {
  name        = "Chat Response End-to-End Availability"
  type        = "monitor"
  description = "99.5% availability across all components of the chat pipeline: Frontend → Backend → RabbitMQ → Worker → OpenAI → Response"

  monitor_ids = [
    datadog_monitor.frontend_api_errors.id,
    datadog_monitor.backend_error_rate.id,
    datadog_monitor.rabbitmq_connections.id,
    datadog_monitor.rabbitmq_queue_depth.id,
    datadog_monitor.worker_error_rate.id,
    datadog_monitor.openai_api_errors.id,
    datadog_monitor.rum_js_errors.id
  ]

  thresholds {
    timeframe = "7d"
    target    = 99.5
    warning   = 99.7
  }

  tags = [
    "service:chatbot-system",
    "env:${var.environment}",
    "team:chatbot",
    "category:availability",
    "priority:critical",
    "managed_by:terraform"
  ]
}

# 2. Database Query Performance SLO (using slow query monitor as proxy)
resource "datadog_service_level_objective" "database_performance" {
  name        = "Postgres Query Performance"
  type        = "monitor"
  description = "Database queries should not trigger slow query alerts to ensure snappy chat responses"

  monitor_ids = [
    datadog_monitor.postgres_slow_queries.id
  ]

  thresholds {
    timeframe = "7d"
    target    = 95.0
    warning   = 97.0
  }

  tags = [
    "service:chat-postgres",
    "env:${var.environment}",
    "team:chatbot",
    "category:database",
    "category:performance",
    "managed_by:terraform"
  ]
}

# 3. RabbitMQ Message Processing Time SLO (using Worker service availability as proxy)
resource "datadog_service_level_objective" "rabbitmq_processing_availability" {
  name        = "Chat Worker Processing Availability"
  type        = "monitor"
  description = "Worker should successfully process messages without errors (proxy for RabbitMQ pipeline health)"

  monitor_ids = [
    datadog_monitor.worker_error_rate.id,
    datadog_monitor.rabbitmq_connections.id,
    datadog_monitor.rabbitmq_queue_depth.id
  ]

  thresholds {
    timeframe = "7d"
    target    = 95.0
    warning   = 97.0
  }

  tags = [
    "service:chat-worker",
    "env:${var.environment}",
    "team:chatbot",
    "category:dsm",
    "category:availability",
    "managed_by:terraform"
  ]
}

