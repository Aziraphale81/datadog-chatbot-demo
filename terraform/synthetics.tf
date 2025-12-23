# Synthetic Tests

# HTTP check for frontend availability
resource "datadog_synthetics_test" "frontend_uptime" {
  name    = "${var.environment} - Frontend Uptime Check"
  type    = "api"
  subtype = "http"
  status  = "live"
  message = <<-EOT
    Frontend is down or returning errors.
    
    Check:
    - NodePort service status
    - Frontend pod logs
    - Kubernetes events
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  request_definition {
    method = "GET"
    url    = "http://localhost:30080"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "body"
    operator = "contains"
    target   = "Chatbot"
  }

  options_list {
    tick_every         = 300  # 5 minutes
    follow_redirects   = true
    min_failure_duration = 300
    min_location_failed = 1

    monitor_options {
      renotify_interval = 60
    }
  }

  locations = ["aws:us-east-1"]  # Change to your preferred locations

  tags = [
    "service:${var.frontend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

# API test for backend health endpoint
resource "datadog_synthetics_test" "backend_health" {
  name    = "${var.environment} - Backend Health Check"
  type    = "api"
  subtype = "http"
  status  = "live"
  message = <<-EOT
    Backend health endpoint is failing.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  request_definition {
    method = "GET"
    url    = "http://backend.${var.namespace}.svc.cluster.local:8000/health"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "body"
    operator = "contains"
    target   = "ok"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "1000"
  }

  options_list {
    tick_every         = 300
    follow_redirects   = true
    min_failure_duration = 300
    min_location_failed = 1

    monitor_options {
      renotify_interval = 60
    }
  }

  locations = ["aws:us-east-1"]

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

