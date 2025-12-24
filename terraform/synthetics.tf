# Synthetic Tests
#
# Note: These tests use localhost:30080 URLs, which work with Docker-based
# private locations using --network host. If using Kubernetes Helm-based
# private location, you may want to use internal K8s service URLs instead:
#   - Frontend: http://frontend.chat-demo.svc.cluster.local
#   - Backend: http://backend.chat-demo.svc.cluster.local:8000

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

  locations = var.synthetics_private_location_id != "" ? [var.synthetics_private_location_id] : ["aws:us-east-1"]

  tags = [
    "service:${var.frontend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

# API test for backend via chat endpoint (tests full stack)
resource "datadog_synthetics_test" "backend_health" {
  name    = "${var.environment} - Backend API Check (via Chat)"
  type    = "api"
  subtype = "http"
  status  = "live"
  message = <<-EOT
    Backend API is failing (tested via chat endpoint).
    
    This tests the full stack: Frontend → Backend → OpenAI → Database
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  request_definition {
    method = "POST"
    url    = "http://localhost:30080/api/chat"
    body   = jsonencode({
      prompt = "health check"
    })
  }
  
  request_headers = {
    "Content-Type" = "application/json"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "body"
    operator = "contains"
    target   = "reply"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "5000"  # Increased for OpenAI latency
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

  locations = var.synthetics_private_location_id != "" ? [var.synthetics_private_location_id] : ["aws:us-east-1"]

  tags = [
    "service:${var.backend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

