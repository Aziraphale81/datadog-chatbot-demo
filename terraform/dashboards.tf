# Dashboards

# Main Application Dashboard
# Imported from Datadog UI export: ChatbotApplicationOverview--2025-12-30T13_43_02.json
# Uses datadog_dashboard_json resource to preserve exact UI configuration
resource "datadog_dashboard_json" "chatbot_overview" {
  dashboard = jsonencode({
    title       = "Chatbot Application Overview"
    description = "End-to-end observability for the AI Chatbot demo application"
    layout_type = "ordered"
    
    widgets = [
      # Backend Health Group
      {
        id = 8970513937234798
        definition = {
          title            = "Backend Health"
          background_color = "vivid_blue"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 974426769408551
              definition = {
                title             = "Backend Monitors"
                type              = "manage_status"
                display_format    = "countsAndList"
                color_preference  = "background"
                hide_zero_counts  = true
                show_status       = true
                last_triggered_format = "relative"
                query             = "tag:(service:chat-backend)"
                sort              = "status,asc"
                count             = 50
                start             = 0
                summary_type      = "monitors"
                show_priority     = false
                show_last_triggered = false
              }
              layout = { x = 0, y = 0, width = 4, height = 4 }
            },
            {
              id = 3409395282207139
              definition = {
                title = "Backend Availability SLO"
                requests = [{
                  query = {
                    limit        = 5
                    query_string = "backend"
                    sort         = []
                  }
                  request_type = "slo_list"
                }]
                type = "slo_list"
              }
              layout = { x = 4, y = 0, width = 6, height = 2 }
            },
            {
              id = 4890345352349209
              definition = {
                title = "Backend Error Rate"
                type  = "query_value"
                requests = [{
                  conditional_formats = [
                    { comparator = "=", hide_value = false, palette = "white_on_green", value = 0 },
                    { comparator = ">", hide_value = false, palette = "white_on_yellow", value = 0 },
                    { comparator = ">=", hide_value = false, palette = "white_on_red", value = 10 }
                  ]
                  formulas = [{ formula = "default_zero(query1)" }]
                  queries = [{
                    aggregator      = "sum"
                    data_source     = "metrics"
                    name            = "query1"
                    query           = "sum:trace.http.request.errors{service:chat-backend,env:demo}.as_count()"
                  }]
                  response_format = "scalar"
                }]
                autoscale = true
                precision = 0
              }
              layout = { x = 10, y = 0, width = 2, height = 2 }
            },
            {
              id = 6265233644886420
              definition = {
                title       = "Backend Latency (p50, p95, p99)"
                show_legend = true
                type        = "timeseries"
                requests = [
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query1", query = "p95:trace.http.request{service:chat-backend,env:demo}" }]
                    response_format = "timeseries"
                    display_type    = "line"
                  },
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query2", query = "p99:trace.http.request{service:chat-backend,env:demo}" }]
                    response_format = "timeseries"
                    display_type    = "line"
                  },
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query3", query = "p50:trace.http.request{service:chat-backend,env:demo}" }]
                    response_format = "timeseries"
                    display_type    = "line"
                  }
                ]
              }
              layout = { x = 4, y = 2, width = 4, height = 2 }
            },
            {
              id = 5535326042493391
              definition = {
                title       = "Backend Request Rate"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "sum:trace.http.request{service:chat-backend,env:demo}.as_rate()" }]
                  response_format = "timeseries"
                  display_type    = "line"
                }]
              }
              layout = { x = 8, y = 2, width = 4, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 0, width = 12, height = 5 }
      },

      # LLM Observability Group
      {
        id = 3789409751237079
        definition = {
          title            = "LLM Observability"
          background_color = "vivid_purple"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 2407968808474349
              definition = {
                title                 = "LLM Monitors"
                type                  = "manage_status"
                display_format        = "countsAndList"
                color_preference      = "background"
                hide_zero_counts      = true
                show_status           = true
                last_triggered_format = "relative"
                query                 = "tag:(category:llm)"
                sort                  = "status,asc"
                count                 = 50
                start                 = 0
                summary_type          = "monitors"
                show_priority         = false
                show_last_triggered   = false
              }
              layout = { x = 0, y = 0, width = 4, height = 4 }
            },
            {
              id = 6825769739538923
              definition = {
                title = "Backend Availability SLO"
                requests = [{
                  query = {
                    limit        = 5
                    query_string = "openai"
                    sort         = []
                  }
                  request_type = "slo_list"
                }]
                type = "slo_list"
              }
              layout = { x = 4, y = 0, width = 6, height = 2 }
            },
            {
              id = 858217173730901
              definition = {
                title = "Total Tokens Used (24h)"
                type  = "query_value"
                requests = [{
                  queries = [{
                    aggregator  = "sum"
                    data_source = "metrics"
                    name        = "query1"
                    query       = "sum:ml_obs.span.llm.total.tokens{service:chat-backend,env:demo}"
                  }]
                  response_format = "scalar"
                }]
                autoscale = true
                precision = 0
              }
              layout = { x = 10, y = 0, width = 2, height = 2 }
            },
            {
              id = 4045972717619761
              definition = {
                title       = "OpenAI Request Rate"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "sum:trace.openai.request{service:chat-backend,env:demo}.as_count()" }]
                  response_format = "timeseries"
                  display_type    = "bars"
                }]
              }
              layout = { x = 4, y = 2, width = 4, height = 2 }
            },
            {
              id = 3302945927821080
              definition = {
                title       = "OpenAI Latency"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "avg:trace.openai.request{service:chat-backend,env:demo}" }]
                  response_format = "timeseries"
                  display_type    = "line"
                }]
              }
              layout = { x = 8, y = 2, width = 4, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 5, width = 12, height = 5 }
      },

      # Database Performance Group
      {
        id = 4427430069777342
        definition = {
          title            = "Database Performance"
          background_color = "vivid_green"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 3294338288927105
              definition = {
                title                 = "Database Monitors"
                type                  = "manage_status"
                display_format        = "countsAndList"
                color_preference      = "background"
                hide_zero_counts      = true
                show_status           = true
                last_triggered_format = "relative"
                query                 = "tag:(category:database)"
                sort                  = "status,asc"
                count                 = 50
                start                 = 0
                summary_type          = "monitors"
                show_priority         = false
                show_last_triggered   = false
              }
              layout = { x = 0, y = 0, width = 4, height = 3 }
            },
            {
              id = 1942421481968647
              definition = {
                title       = "Database Query Execution Time"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "avg:postgresql.queries.time{kube_namespace:chat-demo}" }]
                  response_format = "timeseries"
                  display_type    = "line"
                }]
              }
              layout = { x = 4, y = 0, width = 4, height = 2 }
            },
            {
              id = 4040436036524805
              definition = {
                title       = "Database Connections"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "sum:postgresql.connections{kube_namespace:chat-demo} by {state}" }]
                  response_format = "timeseries"
                  display_type    = "area"
                }]
              }
              layout = { x = 8, y = 0, width = 4, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 10, width = 12, height = 4 }
      },

      # RUM - Frontend Performance Group
      {
        id = 389119132423119
        definition = {
          title            = "RUM - Frontend Performance"
          background_color = "vivid_orange"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 2407994725367998
              definition = {
                title                 = "Frontend Monitors"
                type                  = "manage_status"
                display_format        = "countsAndList"
                color_preference      = "background"
                hide_zero_counts      = true
                show_status           = true
                last_triggered_format = "relative"
                query                 = "[demo] frontend javascript"
                sort                  = "status,asc"
                count                 = 50
                start                 = 0
                summary_type          = "monitors"
                show_priority         = false
                show_last_triggered   = false
              }
              layout = { x = 0, y = 0, width = 4, height = 4 }
            },
            {
              id = 4684065339803791
              definition = {
                title = "Frontend Error-Free Views SLO"
                requests = [{
                  query = {
                    limit        = 1
                    query_string = "chat-frontend"
                    sort         = []
                  }
                  request_type = "slo_list"
                }]
                type = "slo_list"
              }
              layout = { x = 4, y = 0, width = 6, height = 2 }
            },
            {
              id = 7520538927661609
              definition = {
                title = "RUM Session Errors"
                type  = "query_value"
                requests = [{
                  conditional_formats = [
                    { comparator = "=", hide_value = false, palette = "white_on_green", value = 0 },
                    { comparator = ">", hide_value = false, palette = "white_on_yellow", value = 0 },
                    { comparator = ">=", hide_value = false, palette = "white_on_red", value = 10 }
                  ]
                  formulas = [{ formula = "default_zero(query1)" }]
                  queries = [{
                    aggregator  = "avg"
                    data_source = "metrics"
                    name        = "query1"
                    query       = "sum:rum.measure.session.error{service:chat-frontend,env:demo}.as_count()"
                  }]
                  response_format = "scalar"
                }]
                autoscale = true
                precision = 0
              }
              layout = { x = 10, y = 0, width = 2, height = 2 }
            },
            {
              id = 2246114516032766
              definition = {
                title       = "Page Load Time"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "avg:rum.measure.view.loading_time{service:chat-frontend,env:demo}" }]
                  response_format = "timeseries"
                  display_type    = "line"
                }]
              }
              layout = { x = 4, y = 2, width = 4, height = 2 }
            },
            {
              id = 546880989552037
              definition = {
                title       = "RUM Sessions"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "sum:rum.measure.session{service:chat-frontend,env:demo}.as_count()" }]
                  response_format = "timeseries"
                  display_type    = "bars"
                }]
              }
              layout = { x = 8, y = 2, width = 4, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 14, width = 12, height = 5 }
      },

      # Kubernetes Resources Group
      {
        id = 2724803554558038
        definition = {
          title            = "Kubernetes Resources"
          background_color = "gray"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 8918527097529155
              definition = {
                title                 = "Kubernetes Monitors"
                type                  = "manage_status"
                display_format        = "countsAndList"
                color_preference      = "background"
                hide_zero_counts      = true
                show_status           = true
                last_triggered_format = "relative"
                query                 = "tag:(category:kubernetes)"
                sort                  = "status,asc"
                count                 = 50
                start                 = 0
                summary_type          = "monitors"
                show_priority         = false
                show_last_triggered   = false
              }
              layout = { x = 0, y = 0, width = 4, height = 4 }
            },
            {
              id = 3496933298284838
              definition = {
                title       = "CPU by Pod (Requests vs Limits)"
                show_legend = true
                type        = "timeseries"
                requests = [
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query1", query = "avg:kubernetes.cpu.requests{kube_namespace:chat-demo} by {pod_name}" }]
                    response_format = "timeseries"
                    style = { palette = "cool" }
                    display_type = "line"
                  },
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query2", query = "avg:kubernetes.cpu.limits{kube_namespace:chat-demo} by {pod_name}" }]
                    response_format = "timeseries"
                    style = { palette = "warm" }
                    display_type = "line"
                  }
                ]
              }
              layout = { x = 4, y = 0, width = 4, height = 2 }
            },
            {
              id = 3996382264046949
              definition = {
                title       = "Memory by Pod (Requests vs Limits)"
                show_legend = true
                type        = "timeseries"
                requests = [
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query1", query = "avg:kubernetes.memory.requests{kube_namespace:chat-demo} by {pod_name}" }]
                    response_format = "timeseries"
                    style = { palette = "cool" }
                    display_type = "line"
                  },
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "query2", query = "avg:kubernetes.memory.limits{kube_namespace:chat-demo} by {pod_name}" }]
                    response_format = "timeseries"
                    style = { palette = "warm" }
                    display_type = "line"
                  }
                ]
              }
              layout = { x = 8, y = 0, width = 4, height = 2 }
            },
            {
              id = 8379443870741390
              definition = {
                title       = "Pod Restarts"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "query1", query = "sum:kubernetes.containers.restarts{kube_namespace:chat-demo} by {pod_name}" }]
                  response_format = "timeseries"
                  style = { palette = "warm" }
                  display_type = "bars"
                }]
              }
              layout = { x = 4, y = 2, width = 4, height = 2 }
            },
            {
              id = 8379443870741391
              definition = {
                title       = "Backend Memory Usage"
                show_legend = false
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ 
                    data_source = "metrics", 
                    name = "memory", 
                    query = "avg:container.memory.usage{kube_namespace:chat-demo,kube_deployment:backend}" 
                  }]
                  response_format = "timeseries"
                  style = { palette = "blue" }
                  display_type = "area"
                }]
              }
              layout = { x = 8, y = 2, width = 4, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 19, width = 12, height = 5 }
      },

      # Data Streams Monitoring (DSM) Group
      {
        id = 3386846048273750
        definition = {
          title            = "📊 Data Streams Monitoring (DSM)"
          background_color = "vivid_purple"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 7997854376619150
              definition = {
                title                 = "DSM Monitors"
                type                  = "manage_status"
                display_format        = "countsAndList"
                color_preference      = "background"
                hide_zero_counts      = true
                show_status           = true
                last_triggered_format = "relative"
                query                 = "rabbitmq"
                sort                  = "status,asc"
                count                 = 50
                start                 = 0
                summary_type          = "monitors"
                show_priority         = false
                show_last_triggered   = false
              }
              layout = { x = 0, y = 0, width = 4, height = 4 }
            },
            {
              id = 3735396642691863
              definition = {
                title = "Chat Worker Processing Availability SLO"
                requests = [{
                  query = {
                    limit        = 1
                    query_string = "\"Chat Worker\""
                    sort         = []
                  }
                  request_type = "slo_list"
                }]
                type = "slo_list"
              }
              layout = { x = 4, y = 0, width = 6, height = 2 }
            },
            {
              id = 255927858962061
              definition = {
                title = "Active Consumers"
                type  = "query_value"
                requests = [{
                  queries = [{
                    aggregator  = "last"
                    data_source = "metrics"
                    name        = "consumers"
                    query       = "sum:rabbitmq.queue.consumers{service:chat-rabbitmq,env:demo}"
                  }]
                  response_format = "scalar"
                }]
                autoscale  = true
                text_align = "center"
                precision  = 0
              }
              layout = { x = 10, y = 0, width = 2, height = 2 }
            },
            {
              id = 7811465647609768
              definition = {
                title       = "RabbitMQ Queue Depth"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "queue_depth", query = "sum:rabbitmq.queue.messages{service:chat-rabbitmq,env:demo} by {queue}" }]
                  response_format = "timeseries"
                  style = { palette = "purple" }
                  display_type = "line"
                }]
              }
              layout = { x = 4, y = 2, width = 4, height = 2 }
            },
            {
              id = 1921662203210171
              definition = {
                title       = "Message Processing Rate"
                show_legend = true
                type        = "timeseries"
                requests = [
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "publish_rate", query = "sum:rabbitmq.queue.messages.publish.rate{service:chat-rabbitmq,env:demo} by {queue}" }]
                    response_format = "timeseries"
                    style = { palette = "green" }
                    display_type = "line"
                  },
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "consume_rate", query = "sum:rabbitmq.queue.messages.deliver.rate{service:chat-rabbitmq,env:demo} by {queue}" }]
                    response_format = "timeseries"
                    style = { palette = "blue" }
                    display_type = "line"
                  }
                ]
              }
              layout = { x = 8, y = 2, width = 4, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 24, width = 12, height = 5 }
      },

      # Data Jobs Monitoring (DJM) Group
      {
        id = 3569409754767002
        definition = {
          title            = "⚙️ Data Jobs Monitoring (DJM)"
          background_color = "vivid_orange"
          show_title       = true
          type             = "group"
          layout_type      = "ordered"
          widgets = [
            {
              id = 4715102335907507
              definition = {
                title                 = "DJM Monitors"
                type                  = "manage_status"
                display_format        = "countsAndList"
                color_preference      = "background"
                hide_zero_counts      = true
                show_status           = true
                last_triggered_format = "relative"
                query                 = "airflow"
                sort                  = "status,asc"
                count                 = 50
                start                 = 0
                summary_type          = "monitors"
                show_priority         = false
                show_last_triggered   = false
              }
              layout = { x = 0, y = 0, width = 4, height = 4 }
            },
            {
              id = 2129325407082437
              definition = {
                title       = "Airflow DAG Success vs Failures"
                show_legend = true
                type        = "timeseries"
                requests = [
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "success", query = "sum:airflow.dag.task.success{service:chat-airflow,env:demo} by {dag_id}.as_count()" }]
                    response_format = "timeseries"
                    style = { palette = "green" }
                    display_type = "bars"
                  },
                  {
                    on_right_yaxis  = false
                    queries = [{ data_source = "metrics", name = "failures", query = "sum:airflow.dag.task.failed{service:chat-airflow,env:demo} by {dag_id}.as_count()" }]
                    response_format = "timeseries"
                    style = { palette = "red" }
                    display_type = "bars"
                  }
                ]
              }
              layout = { x = 4, y = 0, width = 4, height = 2 }
            },
            {
              id = 5026804474937258
              definition = {
                title       = "DAG Execution Duration (p95)"
                show_legend = true
                type        = "timeseries"
                requests = [{
                  on_right_yaxis  = false
                  queries = [{ data_source = "metrics", name = "duration", query = "p95:airflow.dag.duration{service:chat-airflow,env:demo} by {dag_id}" }]
                  response_format = "timeseries"
                  style = { palette = "orange" }
                  display_type = "line"
                }]
              }
              layout = { x = 8, y = 0, width = 4, height = 2 }
            },
            {
              id = 5453462095117967
              definition = {
                title = "Active DAG Runs"
                type  = "query_value"
                requests = [{
                  queries = [{
                    aggregator  = "last"
                    data_source = "metrics"
                    name        = "active_runs"
                    query       = "sum:airflow.dag_processing.last_run.seconds_ago{service:chat-airflow,env:demo}"
                  }]
                  response_format = "scalar"
                }]
                autoscale  = true
                text_align = "center"
                precision  = 0
              }
              layout = { x = 4, y = 2, width = 2, height = 2 }
            }
          ]
        }
        layout = { x = 0, y = 29, width = 12, height = 5 }
      }
    ]

    template_variables = []
    notify_list        = []
    reflow_type        = "fixed"
    tags               = []
    pause_auto_refresh = false
  })
}
