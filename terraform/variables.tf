variable "datadog_api_key" {
  description = "Datadog API Key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application Key"
  type        = string
  sensitive   = true
}

variable "datadog_api_url" {
  description = "Datadog API URL (US1: https://api.datadoghq.com, US3: https://api.us3.datadoghq.com, etc.)"
  type        = string
  default     = "https://api.datadoghq.com"
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.com for US1)"
  type        = string
  default     = "datadoghq.com"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "docker-desktop"
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "chat-demo"
}

variable "backend_service" {
  description = "Backend service name"
  type        = string
  default     = "chat-backend"
}

variable "frontend_service" {
  description = "Frontend service name"
  type        = string
  default     = "chat-frontend"
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "alert_slack_channel" {
  description = "Slack channel for alert notifications (e.g., @slack-channel-name)"
  type        = string
  default     = ""
}

variable "synthetics_private_location_id" {
  description = "Datadog Synthetics Private Location ID (leave empty to use public locations)"
  type        = string
  default     = ""
}

