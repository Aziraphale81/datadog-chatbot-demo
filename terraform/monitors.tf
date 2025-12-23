# APM Monitors

# Backend API latency (p95)
resource "datadog_monitor" "backend_latency_p95" {
  name    = "[${var.environment}] Backend API Latency (p95) is high"
  type    = "metric alert"
  message = <<-EOT
    The p95 latency for ${var.backend_service} has exceeded the threshold.
    
    Check:
    - APM traces for slow endpoints
    - Database query performance
    - OpenAI API response times
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "avg(last_5m):p95:trace.http.request{service:${var.backend_service},env:${var.environment}} > 2"

  monitor_thresholds {
    critical = 2.0
    warning  = 1.5
  }

  notify_no_data    = false
  renotify_interval = 60
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 2

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "team:platform",
    "managed_by:terraform"
  ]
}

# Backend error rate
resource "datadog_monitor" "backend_error_rate" {
  name    = "[${var.environment}] Backend API Error Rate is high"
  type    = "metric alert"
  message = <<-EOT
    The error rate for ${var.backend_service} has exceeded 5%.
    
    Check APM Error Tracking for details.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_5m):trace.http.request.errors{service:${var.backend_service},env:${var.environment}}.as_rate() > 0.05"

  monitor_thresholds {
    critical = 0.05
    warning  = 0.02
  }

  notify_no_data    = false
  renotify_interval = 60
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 1

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "team:platform",
    "managed_by:terraform"
  ]
}

# LLM Observability - OpenAI failures
resource "datadog_monitor" "openai_failures" {
  name    = "[${var.environment}] OpenAI API Failures"
  type    = "metric alert"
  message = <<-EOT
    OpenAI API calls are failing.
    
    Check:
    - LLM Observability dashboard
    - OpenAI API status
    - API key validity
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_10m):trace.openai.error{env:${var.environment},service:${var.backend_service}} > 1"

  monitor_thresholds {
    critical = 1
  }

  notify_no_data    = false
  renotify_interval = 60
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 2

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "category:llm",
    "managed_by:terraform"
  ]
}

# RUM - Frontend JS errors
resource "datadog_monitor" "rum_js_errors" {
  name    = "[${var.environment}] Frontend JavaScript Errors"
  type    = "metric alert"
  message = <<-EOT
    JavaScript errors detected in the frontend.
    
    Check RUM Error Tracking for details.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_5m):rum.measure.session.error{service:${var.frontend_service},env:${var.environment}}.as_count() > 5"

  monitor_thresholds {
    critical = 5
    warning  = 2
  }

  notify_no_data    = false
  renotify_interval = 60
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 3

  tags = [
    "service:${var.frontend_service}",
    "env:${var.environment}",
    "category:rum",
    "managed_by:terraform"
  ]
}

# Database - Slow queries
resource "datadog_monitor" "postgres_slow_queries" {
  name    = "[${var.environment}] Postgres Slow Queries"
  type    = "metric alert"
  message = <<-EOT
    Postgres query execution time is elevated.
    
    Check DBM for query samples and execution plans.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "avg(last_10m):postgresql.queries.time{kube_cluster_name:${var.cluster_name},kube_namespace:${var.namespace}} > 500"

  monitor_thresholds {
    critical = 500
    warning  = 200
  }

  notify_no_data    = false
  renotify_interval = 60
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 3

  tags = [
    "env:${var.environment}",
    "category:database",
    "managed_by:terraform"
  ]
}

# Kubernetes - Pod restarts
resource "datadog_monitor" "pod_restarts" {
  name    = "[${var.environment}] Kubernetes Pod Restart Rate"
  type    = "metric alert"
  message = <<-EOT
    Pods in ${var.namespace} are restarting frequently.
    
    Check Kubernetes Events and pod logs.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "change(sum(last_5m),last_5m):kubernetes.containers.restarts{kube_namespace:${var.namespace}} > 3"

  monitor_thresholds {
    critical = 3
    warning  = 1
  }

  notify_no_data    = false
  renotify_interval = 60
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 2

  tags = [
    "env:${var.environment}",
    "category:kubernetes",
    "managed_by:terraform"
  ]
}

