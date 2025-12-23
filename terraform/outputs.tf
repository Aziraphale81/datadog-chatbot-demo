output "monitor_ids" {
  description = "IDs of created monitors"
  value = {
    backend_latency       = datadog_monitor.backend_latency_p95.id
    backend_error_rate    = datadog_monitor.backend_error_rate.id
    openai_failures       = datadog_monitor.openai_failures.id
    rum_js_errors         = datadog_monitor.rum_js_errors.id
    postgres_slow_queries = datadog_monitor.postgres_slow_queries.id
    pod_restarts          = datadog_monitor.pod_restarts.id
  }
}

output "slo_ids" {
  description = "IDs of created SLOs"
  value = {
    backend_availability  = datadog_service_level_objective.backend_availability.id
    backend_latency       = datadog_service_level_objective.backend_latency.id
    frontend_error_rate   = datadog_service_level_objective.frontend_error_rate.id
  }
}

output "dashboard_url" {
  description = "URL to the main dashboard"
  value       = "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.chatbot_overview.id}"
}

output "synthetic_test_ids" {
  description = "IDs of synthetic tests"
  value = {
    frontend_uptime  = datadog_synthetics_test.frontend_uptime.id
    backend_health   = datadog_synthetics_test.backend_health.id
  }
}

