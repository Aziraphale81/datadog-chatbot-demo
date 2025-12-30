# Software Catalog Entities
#
# Note: Requires Datadog Provider v3.16.0 or later for service definition support

# System Entity - Overall Application
# System entities are not yet fully supported via Terraform provider
# Create manually in UI or use the API: https://docs.datadoghq.com/api/latest/service-definition/
# 
# resource "datadog_service_definition_yaml" "chatbot_system" {
#   service_definition = yamlencode({
#     schema-version = "v3.0"
#     dd-service     = "chatbot-demo-system"
#     team           = "team:chatbot"
#     application    = "chatbot-demo"
#     description    = "Full-stack AI chatbot application demonstrating Datadog's complete observability and security platform"
#     tier           = "tier3"
#     lifecycle      = "sandbox"
#     tags = [
#       "env:${var.environment}",
#       "managed_by:terraform",
#       "platform:kubernetes"
#     ]
#     links = [
#       {
#         name = "Dashboard"
#         type = "other"
#         url  = "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.chatbot_overview.id}"
#       },
#       {
#         name = "README Documentation"
#         type = "doc"
#         url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/blob/main/README.md"
#       }
#     ]
#     contacts = [
#       {
#         type    = "email"
#         contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
#       }
#     ]
#   })
# }

# Service Entity - Backend API
resource "datadog_service_definition_yaml" "backend" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = var.backend_service
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "FastAPI backend service handling chat requests, OpenAI integration, and database persistence. Instrumented with full Datadog observability (APM, logs, profiling, DBM) and security (ASM, IAST)."
    tier           = "tier2"
    lifecycle      = "sandbox"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "Service APM"
        type = "other"
        url  = "https://app.${var.datadog_site}/apm/service/${var.backend_service}/operations"
      },
      {
        name = "LLM Observability"
        type = "other"
        url  = "https://app.${var.datadog_site}/llm/applications"
      },
      {
        name = "Backend Code"
        type = "repo"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/tree/main/backend"
      },
      {
        name = "Deployment YAML"
        type = "runbook"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/blob/main/k8s/backend.yaml"
      }
    ]
    tags = [
      "env:${var.environment}",
      "service:${var.backend_service}",
      "managed_by:terraform",
      "component:api",
      "framework:fastapi",
      "platform:kubernetes",
      "language:python"
    ]
    integrations = var.alert_slack_channel != "" ? {
      slack = {
        project = var.alert_slack_channel
      }
    } : null
  })
}

# Service Entity - Frontend
resource "datadog_service_definition_yaml" "frontend" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = var.frontend_service
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "Next.js frontend application providing the chat interface. Features RUM with Session Replay, markdown rendering, and real-time monitoring. Proxies API requests to the backend service."
    tier           = "tier2"
    lifecycle      = "sandbox"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "RUM Application"
        type = "other"
        url  = "https://app.${var.datadog_site}/rum/sessions"
      },
      {
        name = "Session Replay"
        type = "other"
        url  = "https://app.${var.datadog_site}/rum/session-replay"
      },
      {
        name = "Frontend Code"
        type = "repo"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/tree/main/frontend"
      },
      {
        name = "Deployment YAML"
        type = "runbook"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/blob/main/k8s/frontend.yaml"
      }
    ]
    tags = [
      "env:${var.environment}",
      "service:${var.frontend_service}",
      "managed_by:terraform",
      "component:ui",
      "framework:nextjs",
      "platform:kubernetes",
      "language:javascript",
      "language:typescript"
    ]
    integrations = var.alert_slack_channel != "" ? {
      slack = {
        project = var.alert_slack_channel
      }
    } : null
  })
}

# Datastore Entity - Postgres Database
resource "datadog_service_definition_yaml" "postgres" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = "chat-postgres"
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "Postgres database storing chat messages, user interactions, and conversation history. Monitored with Database Monitoring (DBM) for query performance and execution plans."
    tier           = "tier2"
    lifecycle      = "sandbox"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "Database Monitoring"
        type = "other"
        url  = "https://app.${var.datadog_site}/databases"
      },
      {
        name = "Query Samples"
        type = "other"
        url  = "https://app.${var.datadog_site}/databases/queries"
      },
      {
        name = "Deployment YAML"
        type = "runbook"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/blob/main/k8s/postgres.yaml"
      }
    ]
    tags = [
      "env:${var.environment}",
      "service:chat-postgres",
      "managed_by:terraform",
      "component:database",
      "platform:kubernetes",
      "dbm:enabled",
      "database:postgres"
    ]
  })
}

# External Dependency - OpenAI API
resource "datadog_service_definition_yaml" "openai" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = "openai-api"
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "External AI service providing language model capabilities (gpt-4o-mini)"
    tier           = "tier1"
    lifecycle      = "production"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "OpenAI Status"
        type = "url"
        url  = "https://status.openai.com"
      },
      {
        name = "OpenAI Documentation"
        type = "doc"
        url  = "https://platform.openai.com/docs"
      },
      {
        name = "LLM Observability"
        type = "other"
        url  = "https://app.${var.datadog_site}/llm/applications"
      }
    ]
    tags = [
      "env:${var.environment}",
      "external:true",
      "provider:openai",
      "llm:true"
    ]
  })
}

# Service Entity - RabbitMQ Message Broker
resource "datadog_service_definition_yaml" "rabbitmq" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = "chat-rabbitmq"
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "RabbitMQ message broker for async chat processing with Data Streams Monitoring (Erlang)"
    tier           = "tier2"
    lifecycle      = "sandbox"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "RabbitMQ Documentation"
        type = "doc"
        url  = "https://www.rabbitmq.com/documentation.html"
      },
      {
        name = "Data Streams Monitoring"
        type = "other"
        url  = "https://app.${var.datadog_site}/data-streams"
      }
    ]
    tags = [
      "env:${var.environment}",
      "managed_by:terraform",
      "platform:kubernetes",
      "messaging:rabbitmq",
      "dsm:enabled",
      "language:erlang"
    ]
  })
}

# Service Entity - Chat Worker
resource "datadog_service_definition_yaml" "worker" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = "chat-worker"
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "Python async worker that processes chat requests from RabbitMQ queue and calls OpenAI API"
    tier           = "tier2"
    lifecycle      = "sandbox"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "Source Code"
        type = "repo"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/tree/main/worker"
      },
      {
        name = "Data Streams Monitoring"
        type = "other"
        url  = "https://app.${var.datadog_site}/data-streams"
      }
    ]
    tags = [
      "env:${var.environment}",
      "managed_by:terraform",
      "platform:kubernetes",
      "messaging:rabbitmq",
      "dsm:enabled",
      "llm:true",
      "language:python"
    ]
  })
}

# Service Entity - Apache Airflow
resource "datadog_service_definition_yaml" "airflow" {
  service_definition = yamlencode({
    schema-version = "v2.2"
    dd-service     = "chat-airflow"
    team           = "team:chatbot"
    application    = "chatbot-demo"
    description    = "Apache Airflow orchestrating analytics jobs: daily summaries, token usage reports, and session cleanup"
    tier           = "tier3"
    lifecycle      = "sandbox"
    contacts = [
      {
        type    = "email"
        contact = var.alert_email != "" ? var.alert_email : "team-chatbot@example.com"
      }
    ]
    links = [
      {
        name = "Airflow UI"
        type = "url"
        url  = "http://localhost:30808"
      },
      {
        name = "Data Jobs Monitoring"
        type = "other"
        url  = "https://app.${var.datadog_site}/data-jobs"
      },
      {
        name = "DAG Code"
        type = "repo"
        url  = "https://github.com/Aziraphale81/datadog-chatbot-demo/blob/main/k8s/airflow.yaml"
      }
    ]
    tags = [
      "env:${var.environment}",
      "managed_by:terraform",
      "platform:kubernetes",
      "job_scheduler:airflow",
      "djm:enabled"
    ]
  })
}
