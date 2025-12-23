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
    "team:platform",
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

