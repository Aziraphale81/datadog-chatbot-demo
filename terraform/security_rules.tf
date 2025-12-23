# Cloud SIEM Detection Rules

# Detect high rate of failed API requests (potential brute force or scanning)
resource "datadog_security_monitoring_rule" "high_error_rate" {
  name    = "[${var.environment}] High Rate of API Errors"
  message = <<-EOT
    ## High Rate of API Errors Detected
    
    A high volume of HTTP errors (4xx/5xx) has been detected, which could indicate:
    - Brute force attacks
    - API scanning/enumeration
    - Application misconfiguration
    - DDoS attempt
    
    **Service**: ${var.backend_service}
    **Environment**: ${var.environment}
    
    Investigate:
    - Source IPs in APM traces
    - Error patterns in logs
    - Recent deployments or changes
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  enabled = true
  type    = "log_detection"

  query {
    name  = "high_error_rate"
    query = "service:${var.backend_service} env:${var.environment} (@http.status_code:[400 TO 599])"
    aggregation = "count"
    group_by_fields = ["@http.client_ip"]
  }

  case {
    name      = "High error rate from single IP"
    status    = "high"
    condition = "high_error_rate > 50"
  }

  case {
    name      = "Critical error rate from single IP"
    status    = "critical"
    condition = "high_error_rate > 100"
  }

  options {
    evaluation_window   = 300  # 5 minutes
    keep_alive          = 600  # 10 minutes
    max_signal_duration = 900  # 15 minutes
    detection_method    = "threshold"
  }

  tags = [
    "security:application",
    "service:${var.backend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

# Detect suspicious SQL patterns in logs (potential SQL injection attempts)
resource "datadog_security_monitoring_rule" "sql_injection_attempt" {
  name    = "[${var.environment}] Potential SQL Injection Attempt"
  message = <<-EOT
    ## Potential SQL Injection Detected
    
    SQL injection patterns detected in application logs.
    
    **Service**: ${var.backend_service}
    **Environment**: ${var.environment}
    
    ASM should have blocked this if enabled. Investigate:
    - ASM Security Signals for confirmed attacks
    - Source IP and user context
    - Affected endpoints
    - Whether attack was successful
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  enabled = true
  type    = "log_detection"

  query {
    name  = "sql_injection_patterns"
    query = "service:${var.backend_service} env:${var.environment} @http.url_details.queryString:(*SELECT* OR *UNION* OR *DROP* OR *INSERT* OR *DELETE* OR *'OR'1'='1* OR *';--* OR *1=1*)"
    aggregation = "count"
    group_by_fields = ["@http.client_ip"]
  }

  case {
    name      = "SQL injection attempt detected"
    status    = "high"
    condition = "sql_injection_patterns > 0"
  }

  options {
    evaluation_window   = 300
    keep_alive          = 1800  # 30 minutes (valid: 0, 60, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400)
    max_signal_duration = 1800
    detection_method    = "threshold"
  }

  tags = [
    "security:application",
    "attack_type:sql_injection",
    "service:${var.backend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

# Detect unusual OpenAI API usage patterns (cost anomaly or data exfiltration)
resource "datadog_security_monitoring_rule" "openai_abuse" {
  name    = "[${var.environment}] Unusual OpenAI API Usage"
  message = <<-EOT
    ## Suspicious OpenAI API Activity
    
    Abnormally high OpenAI API usage detected, which could indicate:
    - Cost abuse / API key compromise
    - Data exfiltration via prompts
    - Service abuse
    
    **Service**: ${var.backend_service}
    **Environment**: ${var.environment}
    
    Check:
    - LLM Observability for prompt patterns
    - User IDs and session context
    - Token usage and costs
    - Source IPs
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  enabled = true
  type    = "log_detection"

  query {
    name  = "high_llm_usage"
    query = "service:${var.backend_service} env:${var.environment} @llm:true"
    aggregation = "count"
    group_by_fields = ["@usr.id"]
  }

  case {
    name      = "Suspicious LLM usage per user"
    status    = "medium"
    condition = "high_llm_usage > 100"
  }

  case {
    name      = "Critical LLM abuse per user"
    status    = "high"
    condition = "high_llm_usage > 500"
  }

  options {
    evaluation_window   = 900   # 15 minutes
    keep_alive          = 1800  # 30 minutes
    max_signal_duration = 3600  # 1 hour
    detection_method    = "threshold"
  }

  tags = [
    "security:abuse",
    "category:llm",
    "service:${var.backend_service}",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

# Detect container escape attempts or suspicious process execution
resource "datadog_security_monitoring_rule" "container_escape" {
  name    = "[${var.environment}] Suspicious Container Activity"
  message = <<-EOT
    ## Suspicious Container Process Detected
    
    Potentially malicious process execution detected in container, which could indicate:
    - Container escape attempt
    - Compromised container
    - Malware execution
    - Privilege escalation
    
    **Environment**: ${var.environment}
    
    Investigate immediately:
    - CSM Threats for runtime signals
    - Process details and parent processes
    - Container image vulnerabilities
    - Network connections from container
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  enabled = true
  type    = "log_detection"

  query {
    name  = "suspicious_processes"
    query = "env:${var.environment} (process.name:(nc OR ncat OR socat OR wget OR curl OR python OR perl OR ruby OR bash OR sh) OR process.cmdline:(*reverse* OR *shell* OR */dev/tcp* OR *chmod +x*))"
    aggregation = "count"
    group_by_fields = ["container.id"]
  }

  case {
    name      = "Suspicious process in container"
    status    = "high"
    condition = "suspicious_processes > 0"
  }

  options {
    evaluation_window   = 300
    keep_alive          = 1800  # 30 minutes (valid: 0, 60, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400)
    max_signal_duration = 1800
    detection_method    = "threshold"
  }

  tags = [
    "security:runtime",
    "attack_type:container_escape",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

# Detect database authentication failures (potential credential stuffing)
resource "datadog_security_monitoring_rule" "database_auth_failure" {
  name    = "[${var.environment}] Database Authentication Failures"
  message = <<-EOT
    ## Database Authentication Failures Detected
    
    Multiple failed authentication attempts to Postgres database.
    
    **Environment**: ${var.environment}
    
    Possible causes:
    - Credential stuffing attack
    - Misconfigured application
    - Compromised credentials
    
    Review:
    - Source IPs attempting connections
    - Database audit logs
    - Application configuration
    
    ${var.alert_email != "" ? "@${var.alert_email}" : ""}
    ${var.alert_slack_channel != "" ? var.alert_slack_channel : ""}
  EOT

  enabled = true
  type    = "log_detection"

  query {
    name  = "postgres_auth_fail"
    query = "source:postgresql env:${var.environment} @error.kind:(authentication OR \"password authentication failed\")"
    aggregation = "count"
    group_by_fields = ["@network.client.ip"]
  }

  case {
    name      = "High authentication failure rate"
    status    = "medium"
    condition = "postgres_auth_fail > 10"
  }

  case {
    name      = "Critical authentication failure rate"
    status    = "high"
    condition = "postgres_auth_fail > 50"
  }

  options {
    evaluation_window   = 300
    keep_alive          = 900
    max_signal_duration = 1800
    detection_method    = "threshold"
  }

  tags = [
    "security:database",
    "attack_type:credential_stuffing",
    "env:${var.environment}",
    "managed_by:terraform"
  ]
}

