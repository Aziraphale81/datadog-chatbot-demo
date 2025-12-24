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
    "team:chatbot",
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
    target   = "10000"  # 10s to handle OpenAI latency + full stack
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
    "team:chatbot",
    "managed_by:terraform"
  ]
}

# Browser test for ChatGPT-style interface (also generates RUM data)
resource "datadog_synthetics_test" "chat_user_journey" {
  name    = "${var.environment} - ChatGPT User Journey (Browser)"
  type    = "browser"
  status  = "live"
  message = <<-EOT
    🤖 ChatGPT-style interface is down!
    
    This test simulates a complete user journey:
    1. Loading the chat interface
    2. Sending a message
    3. Receiving an AI response
    4. Sending a follow-up message
    5. Verifying session appears in sidebar
    
    Automatically generates RUM data for monitoring.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  request_definition {
    method = "GET"
    url    = "http://localhost:30080"
  }

  # Step 1: Navigate to the chat interface
  browser_step {
    name = "Navigate to Chat"
    type = "goToUrl"
    
    params {
      value = "http://localhost:30080"
    }
    
    timeout = 30
  }

  # Step 2: Wait for the welcome screen to load
  browser_step {
    name = "Wait for page load"
    type = "assertElementPresent"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "css"
            value = "textarea[placeholder*='Message']"
          }]
        }
      })
    }
    
    timeout = 15
  }

  # Step 3: Type first message
  browser_step {
    name = "Type first message"
    type = "typeText"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "css"
            value = "textarea"
          }]
        }
      })
      value = "What is Datadog?"
    }
    
    timeout = 10
  }

  # Step 4: Click send button (includes waiting for OpenAI response)
  browser_step {
    name = "Send first message"
    type = "click"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "css"
            value = "button[type='submit']"
          }]
        }
      })
    }
    
    timeout = 20  # OpenAI can take 10s+, need buffer for page processing
  }

  # Step 5: Wait for AI response (includes user message verification)
  browser_step {
    name = "Wait for AI response"
    type = "assertElementPresent"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "css"
            value = ".assistant-message"
          }]
        }
      })
    }
    
    timeout = 45  # Generous timeout for OpenAI API
    allow_failure = false
  }

  # Step 6: Type follow-up message
  browser_step {
    name = "Type follow-up message"
    type = "typeText"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "css"
            value = "textarea"
          }]
        }
      })
      value = "Tell me about monitoring"
    }
    
    timeout = 10
  }

  # Step 7: Send follow-up
  browser_step {
    name = "Send follow-up"
    type = "click"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "css"
            value = "button[type='submit']"
          }]
        }
      })
    }
    
    timeout = 20  # Generous timeout as page may wait for response
  }

  # Step 8: Wait for second response to appear
  browser_step {
    name = "Wait for second response"
    type = "assertElementPresent"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = true
          values = [{
            type  = "xpath"
            value = "(//div[contains(@class, 'assistant-message')])[2]"  # Second assistant message
          }]
        }
      })
    }
    
    timeout = 45  # Generous timeout for second OpenAI response
    allow_failure = true  # Don't fail if follow-up is slow
  }

  # Step 9: Verify session appears in sidebar with message count
  browser_step {
    name = "Verify session in sidebar"
    type = "assertElementPresent"
    
    params {
      element = jsonencode({
        userLocator = {
          failTestOnCannotLocate = false  # Don't fail if sidebar hasn't updated yet
          values = [{
            type  = "css"
            value = "div[class*='sessionItem']"  # Matches CSS module class with hash
          }]
        }
      })
    }
    
    timeout = 10
    allow_failure = true  # Session appears async, so don't fail test
  }

  options_list {
    tick_every         = 900  # 15 minutes (generates RUM data regularly)
    follow_redirects   = true
    min_failure_duration = 600
    min_location_failed = 1
    accept_self_signed = true  # For local testing
    
    monitor_options {
      renotify_interval = 120
    }

    retry {
      count    = 2
      interval = 300
    }
  }

  # Only run on private location (needs localhost access)
  locations = var.synthetics_private_location_id != "" ? [var.synthetics_private_location_id] : []

  device_ids = ["laptop_large"]  # Standard desktop viewport

  tags = [
    "service:${var.frontend_service}",
    "type:browser",
    "env:${var.environment}",
    "team:chatbot",
    "managed_by:terraform",
    "rum_generator:true",
    "test_type:user_journey"
  ]
}

