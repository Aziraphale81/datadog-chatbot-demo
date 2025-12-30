# APM Monitors

# Backend API latency (p95)
resource "datadog_monitor" "backend_latency_p95" {
  name    = "[${var.environment}] Backend API Latency (p95) is high"
  type    = "metric alert"
  message = <<-EOT
    The p95 latency for ${var.backend_service} has exceeded 5 seconds.
    
    Note: This includes OpenAI API calls which can be slow.
    
    Check:
    - APM traces for slow endpoints
    - Database query performance
    - OpenAI API response times
    - LLM Observability for model performance
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "avg(last_5m):p95:trace.http.request{service:${var.backend_service},env:${var.environment}} > 5"

  monitor_thresholds {
    critical = 5.0  # 5 seconds (reasonable for OpenAI API calls)
    warning  = 3.0  # 3 seconds
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
    "team:chatbot",
    "managed_by:terraform"
  ]
}

# Backend error rate (absolute count)
resource "datadog_monitor" "backend_error_rate" {
  name    = "[${var.environment}] Backend API Error Rate is high"
  type    = "metric alert"
  message = <<-EOT
    The ${var.backend_service} has exceeded 20 errors in the last 5 minutes.
    
    Check APM Error Tracking for details.
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_5m):trace.http.request.errors{service:${var.backend_service},env:${var.environment}}.as_count() > 20"

  monitor_thresholds {
    critical = 20  # 20 errors in 5 minutes
    warning  = 10  # 10 errors in 5 minutes
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
    "team:chatbot",
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

# SLO Burn Rate - Backend Availability
# NOTE: Commented out to create manually in UI and export later
# Datadog SLO burn rate query syntax may require specific configuration
# resource "datadog_monitor" "backend_slo_burn_rate" {
#   name    = "[${var.environment}] Backend SLO Burn Rate Alert"
#   type    = "slo alert"
#   message = <<-EOT
#     Backend availability SLO is burning error budget too quickly!
#     
#     At this rate, you'll exhaust your error budget before the end of the period.
#     
#     Check:
#     - Recent deployments or changes
#     - Error rate and latency trends
#     - APM Error Tracking for root causes
#     
#     ${var.alert_email != "" ? "@${var.alert_email}" : ""}
#     ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
#   EOT
# 
#   query = "burn_rate(\"${datadog_service_level_objective.backend_availability.id}\").long_window(\"1h\").short_window(\"5m\") > 14.4"
# 
#   monitor_thresholds {
#     critical          = 14.4  # Burns through monthly budget in 2 days
#     critical_recovery = 12
#   }
# 
#   notify_no_data    = false
#   renotify_interval = 120
#   notify_audit      = false
#   include_tags      = true
#   priority          = 1
# 
#   tags = [
#     "service:${var.backend_service}",
#     "env:${var.environment}",
#     "category:slo",
#     "managed_by:terraform"
#   ]
# }

# RabbitMQ Queue Depth Monitor
resource "datadog_monitor" "rabbitmq_queue_depth" {
  name    = "[${var.environment}] RabbitMQ Queue Depth is high"
  type    = "metric alert"
  message = <<-EOT
    RabbitMQ queue depth has exceeded threshold indicating message backlog.
    
    Check:
    - Worker service health and processing rate
    - Backend message publishing rate
    - Consumer lag in DSM dashboards
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "avg(last_5m):sum:rabbitmq.queue.messages{service:chat-rabbitmq,env:${var.environment}} > 100"

  monitor_thresholds {
    critical = 100
    warning  = 50
  }

  notify_no_data    = false
  renotify_interval = 30
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 2

  tags = [
    "service:chat-rabbitmq",
    "env:${var.environment}",
    "team:chatbot",
    "category:dsm",
    "managed_by:terraform"
  ]
}

# Airflow DAG Failure Monitor
resource "datadog_monitor" "airflow_dag_failures" {
  name    = "[${var.environment}] Airflow DAG Failures detected"
  type    = "metric alert"
  message = <<-EOT
    Airflow DAG execution failures detected.
    
    Check:
    - Airflow UI at http://localhost:30808
    - Task logs for error details
    - Database connectivity
    - DJM dashboards for job health
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_15m):sum:airflow.dag.task.failed{service:chat-airflow,env:${var.environment}} > 3"

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
    "service:chat-airflow",
    "env:${var.environment}",
    "team:chatbot",
    "category:djm",
    "managed_by:terraform"
  ]
}

# === End-to-End Journey Monitors ===

# Worker Error Rate
resource "datadog_monitor" "worker_error_rate" {
  name    = "[${var.environment}] Worker Error Rate is high"
  type    = "metric alert"
  message = <<-EOT
    The chat-worker service has exceeded 10 errors in the last 5 minutes.
    
    This impacts the chat processing pipeline:
    - Messages stuck in RabbitMQ queue
    - Users experiencing timeouts
    - OpenAI API integration failures
    
    Check:
    - Worker pod logs for exceptions
    - OpenAI API key validity
    - RabbitMQ connection health
    - DSM pathway for bottlenecks
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_5m):sum:trace.http.request.errors{service:chat-worker,env:${var.environment}} > 10"

  monitor_thresholds {
    critical = 10
    warning  = 5
  }

  notify_no_data    = false
  renotify_interval = 30
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 2

  tags = [
    "service:chat-worker",
    "env:${var.environment}",
    "team:chatbot",
    "category:dsm",
    "slo_component:true",
    "managed_by:terraform"
  ]
}

# OpenAI API Error Rate (from LLM Observability)
resource "datadog_monitor" "openai_api_errors" {
  name    = "[${var.environment}] OpenAI API Error Rate is high"
  type    = "metric alert"
  message = <<-EOT
    OpenAI API calls are experiencing high error rates.
    
    This directly blocks chat responses for users.
    
    Check:
    - LLM Observability dashboard
    - OpenAI API status page
    - API key validity and quotas
    - Rate limiting issues
    - Model availability (gpt-5-nano)
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_5m):sum:trace.openai.request.error{env:${var.environment}} > 5"

  monitor_thresholds {
    critical = 5
    warning  = 2
  }

  notify_no_data    = false
  renotify_interval = 30
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 1  # Critical - blocks all chat

  tags = [
    "service:openai-api",
    "env:${var.environment}",
    "team:chatbot",
    "category:llm",
    "slo_component:true",
    "managed_by:terraform"
  ]
}

# Frontend API Route Errors
resource "datadog_monitor" "frontend_api_errors" {
  name    = "[${var.environment}] Frontend API Route Error Rate is high"
  type    = "metric alert"
  message = <<-EOT
    Frontend API routes (/api/chat, /api/sessions) are experiencing errors.
    
    This impacts the user's ability to:
    - Send chat messages
    - Load chat history
    - Create new sessions
    
    Check:
    - Frontend pod logs
    - Backend connectivity from frontend
    - Next.js API route health
    - Network policies
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "sum(last_5m):sum:trace.http.request.errors{service:chat-frontend,env:${var.environment}} > 10"

  monitor_thresholds {
    critical = 10
    warning  = 5
  }

  notify_no_data    = false
  renotify_interval = 30
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 2

  tags = [
    "service:chat-frontend",
    "env:${var.environment}",
    "team:chatbot",
    "category:api",
    "slo_component:true",
    "managed_by:terraform"
  ]
}

# RUM Error Rate (using existing RUM JS errors monitor)
# Note: Re-use existing monitor instead of creating duplicate

# RabbitMQ Connection Health
resource "datadog_monitor" "rabbitmq_connections" {
  name    = "[${var.environment}] RabbitMQ Connection Failures"
  type    = "metric alert"
  message = <<-EOT
    RabbitMQ is experiencing connection failures or drops.
    
    This breaks the async message flow:
    - Backend can't publish requests
    - Worker can't consume messages
    - Responses can't be delivered
    
    Check:
    - RabbitMQ pod health and logs
    - Network connectivity
    - RabbitMQ management UI (port 15672)
    - DSM pathway visualization
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  query = "avg(last_5m):avg:rabbitmq.connections{service:chat-rabbitmq,env:${var.environment}} < 2"

  monitor_thresholds {
    critical = 2  # Expect at least backend + worker connections
    warning  = 3
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 30
  notify_audit      = false
  timeout_h         = 1
  include_tags      = true
  priority          = 1

  tags = [
    "service:chat-rabbitmq",
    "env:${var.environment}",
    "team:chatbot",
    "category:dsm",
    "slo_component:true",
    "managed_by:terraform"
  ]
}

