# Dashboards

# Main Application Dashboard
resource "datadog_dashboard" "chatbot_overview" {
  title       = "Chatbot Application Overview"
  description = "End-to-end observability for the AI Chatbot demo application"
  layout_type = "ordered"

  widget {
    group_definition {
      title            = "Backend Health"
      layout_type      = "ordered"
      background_color = "vivid_blue"

      widget {
        widget_layout {
          x      = 0
          y      = 0
          width  = 4
          height = 4
        }
        manage_status_definition {
          title            = "Backend Monitors"
          summary_type     = "monitors"
          display_format   = "countsAndList"
          color_preference = "background"
          hide_zero_counts = true
          query            = "tag:(service:${var.backend_service})"
          sort             = "status,asc"
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 0
          width  = 6
          height = 2
        }
        slo_list_definition {
          title = "Backend Availability SLO"
          request {
            request_type = "slo_list"
            query {
              query_string = "backend"
              limit        = 5
            }
          }
        }
      }

      widget {
        widget_layout {
          x      = 10
          y      = 0
          width  = 2
          height = 2
        }
        query_value_definition {
          title     = "Backend Error Rate"
          autoscale = true
          precision = 0
          request {
            formula {
              formula_expression = "default_zero(query1)"
            }
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:trace.http.request.errors{service:${var.backend_service},env:${var.environment}}.as_count()"
                aggregator  = "sum"
              }
            }
            conditional_formats {
              comparator = "="
              value      = 0
              palette    = "white_on_green"
            }
            conditional_formats {
              comparator = ">"
              value      = 0
              palette    = "white_on_yellow"
            }
            conditional_formats {
              comparator = ">="
              value      = 10
              palette    = "white_on_red"
            }
          }
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Backend Latency (p50, p95, p99)"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "p95:trace.http.request{service:${var.backend_service},env:${var.environment}}"
              }
            }
            display_type = "line"
          }
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query2"
                query       = "p99:trace.http.request{service:${var.backend_service},env:${var.environment}}"
              }
            }
            display_type = "line"
          }
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query3"
                query       = "p50:trace.http.request{service:${var.backend_service},env:${var.environment}}"
              }
            }
            display_type = "line"
          }
        }
      }

      widget {
        widget_layout {
          x      = 8
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Backend Request Rate"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:trace.http.request{service:${var.backend_service},env:${var.environment}}.as_rate()"
              }
            }
            display_type = "line"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title            = "LLM Observability"
      layout_type      = "ordered"
      background_color = "vivid_purple"

      widget {
        widget_layout {
          x      = 0
          y      = 0
          width  = 4
          height = 4
        }
        manage_status_definition {
          title            = "LLM Monitors"
          summary_type     = "monitors"
          display_format   = "countsAndList"
          color_preference = "background"
          hide_zero_counts = true
          query            = "tag:(category:llm)"
          sort             = "status,asc"
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 0
          width  = 6
          height = 2
        }
        slo_list_definition {
          title = "Backend Availability SLO"
          request {
            request_type = "slo_list"
            query {
              query_string = "openai"
              limit        = 5
            }
          }
        }
      }

      widget {
        widget_layout {
          x      = 10
          y      = 0
          width  = 2
          height = 2
        }
        query_value_definition {
          title     = "Total Tokens Used (24h)"
          autoscale = true
          precision = 0
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:ml_obs.span.llm.total.tokens{service:${var.backend_service},env:${var.environment}}"
                aggregator  = "sum"
              }
            }
          }
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "OpenAI Request Rate"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:trace.openai.request{service:${var.backend_service},env:${var.environment}}.as_count()"
              }
            }
            display_type = "bars"
          }
        }
      }

      widget {
        widget_layout {
          x      = 8
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "OpenAI Latency"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "avg:trace.openai.request{service:${var.backend_service},env:${var.environment}}"
              }
            }
            display_type = "line"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title            = "Database Performance"
      layout_type      = "ordered"
      background_color = "vivid_green"

      widget {
        widget_layout {
          x      = 0
          y      = 0
          width  = 4
          height = 3
        }
        manage_status_definition {
          title            = "Database Monitors"
          summary_type     = "monitors"
          display_format   = "countsAndList"
          color_preference = "background"
          hide_zero_counts = true
          query            = "tag:(category:database)"
          sort             = "status,asc"
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 0
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Database Query Execution Time"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "avg:postgresql.queries.time{kube_namespace:${var.namespace}}"
              }
            }
            display_type = "line"
          }
        }
      }

      widget {
        widget_layout {
          x      = 8
          y      = 0
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Database Connections"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:postgresql.connections{kube_namespace:${var.namespace}} by {state}"
              }
            }
            display_type = "area"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title            = "RUM - Frontend Performance"
      layout_type      = "ordered"
      background_color = "vivid_orange"

      widget {
        widget_layout {
          x      = 0
          y      = 0
          width  = 4
          height = 4
        }
        manage_status_definition {
          title            = "Frontend Monitors"
          summary_type     = "monitors"
          display_format   = "countsAndList"
          color_preference = "background"
          hide_zero_counts = true
          query            = "[demo] frontend javascript"
          sort             = "status,asc"
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 0
          width  = 6
          height = 2
        }
        slo_list_definition {
          title = "Frontend Error-Free Views SLO"
          request {
            request_type = "slo_list"
            query {
              query_string = "chat-frontend"
              limit        = 1
            }
          }
        }
      }

      widget {
        widget_layout {
          x      = 10
          y      = 0
          width  = 2
          height = 2
        }
        query_value_definition {
          title     = "RUM Session Errors"
          autoscale = true
          precision = 0
          request {
            formula {
              formula_expression = "default_zero(query1)"
            }
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:rum.measure.session.error{service:${var.frontend_service},env:${var.environment}}.as_count()"
                aggregator  = "avg"
              }
            }
            conditional_formats {
              comparator = "="
              value      = 0
              palette    = "white_on_green"
            }
            conditional_formats {
              comparator = ">"
              value      = 0
              palette    = "white_on_yellow"
            }
            conditional_formats {
              comparator = ">="
              value      = 10
              palette    = "white_on_red"
            }
          }
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Page Load Time"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "avg:rum.measure.view.loading_time{service:${var.frontend_service},env:${var.environment}}"
              }
            }
            display_type = "line"
          }
        }
      }

      widget {
        widget_layout {
          x      = 8
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "RUM Sessions"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:rum.measure.session{service:${var.frontend_service},env:${var.environment}}.as_count()"
              }
            }
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title            = "Kubernetes Resources"
      layout_type      = "ordered"
      background_color = "gray"

      widget {
        widget_layout {
          x      = 0
          y      = 0
          width  = 4
          height = 4
        }
        manage_status_definition {
          title            = "Kubernetes Monitors"
          summary_type     = "monitors"
          display_format   = "countsAndList"
          color_preference = "background"
          hide_zero_counts = true
          query            = "tag:(category:kubernetes)"
          sort             = "status,asc"
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 0
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "CPU by Pod (Requests vs Limits)"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "avg:kubernetes.cpu.requests{kube_namespace:${var.namespace}} by {pod_name}"
              }
            }
            style {
              palette = "cool"
            }
            display_type = "line"
          }
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query2"
                query       = "avg:kubernetes.cpu.limits{kube_namespace:${var.namespace}} by {pod_name}"
              }
            }
            style {
              palette = "warm"
            }
            display_type = "line"
          }
        }
      }

      widget {
        widget_layout {
          x      = 8
          y      = 0
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Memory by Pod (Requests vs Limits)"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "avg:kubernetes.memory.requests{kube_namespace:${var.namespace}} by {pod_name}"
              }
            }
            style {
              palette = "cool"
            }
            display_type = "line"
          }
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query2"
                query       = "avg:kubernetes.memory.limits{kube_namespace:${var.namespace}} by {pod_name}"
              }
            }
            style {
              palette = "warm"
            }
            display_type = "line"
          }
        }
      }

      widget {
        widget_layout {
          x      = 4
          y      = 2
          width  = 4
          height = 2
        }
        timeseries_definition {
          title       = "Pod Restarts"
          show_legend = true
          request {
            query {
              metric_query {
                data_source = "metrics"
                name        = "query1"
                query       = "sum:kubernetes.containers.restarts{kube_namespace:${var.namespace}} by {pod_name}"
              }
            }
            style {
              palette = "warm"
            }
            display_type = "bars"
          }
        }
      }
    }
  }

  # tags = ["team:platform"]  # Uncomment after verifying tag format with your Datadog org
}
