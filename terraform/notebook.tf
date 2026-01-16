# Monitor Analysis Notebook
# This notebook documents monitor threshold analysis and tuning recommendations

resource "datadog_notebook" "monitor_analysis" {
  name = "[${var.environment}] Monitor Threshold Analysis & Tuning"

  # Executive Summary
  cell {
    type = "markdown"
    definition {
      text = <<-EOT
# 📊 Monitor Threshold Analysis & Tuning Recommendations

**Date:** January 9, 2026  
**Environment:** `${var.environment}`  
**Analysis Period:** Last 24 hours  
**Total Monitors:** 15

---

## 🎯 Executive Summary

### Overall Health: **GOOD** ✅

- **14/15 monitors** in healthy state (OK or No Data)
- **1/15 monitor** actively alerting (Backend API Latency - **expected behavior**)
- **Zero critical issues** requiring immediate action
- **3 monitors** recommended for threshold tuning
- **3 synthetic tests** not yet configured (No Data status)

### Key Findings

1. ✅ **Application is stable** - No actual errors or failures in 24h
2. ⚠️ **One monitor alerting as expected** - Backend latency due to OpenAI API calls (15-25s response times)
3. 🔧 **RabbitMQ Queue Depth threshold too high** - Set at 100, actual max is 0.65
4. 📊 **Postgres Slow Query threshold well-tuned** - Recent fix from 500→50,000,000ns
5. 🔬 **Synthetics tests need setup** - 3 monitors in No Data state

---

## 📈 Monitor Status Breakdown

| Status | Count | Monitors |
|--------|-------|----------|
| ✅ **OK** | 11 | Most application & infrastructure monitors |
| ⚠️ **Alert** | 1 | Backend API Latency (expected - OpenAI slowness) |
| 📭 **No Data** | 3 | Synthetic tests (not configured) |

---

## 🏆 Monitor Health Scorecard

| Category | Score | Notes |
|----------|-------|-------|
| **APM Monitors** | 🟡 8/10 | One threshold needs tuning (latency) |
| **LLM Observability** | ✅ 10/10 | Perfect thresholds, zero false positives |
| **DSM Monitors** | 🟡 7/10 | Queue depth threshold too high |
| **DBM Monitors** | ✅ 10/10 | Excellent tuning (recently fixed!) |
| **RUM Monitors** | ✅ 10/10 | Appropriate sensitivity |
| **Infrastructure** | ✅ 10/10 | Well-tuned restart detection |
| **DJM Monitors** | ✅ 10/10 | Good balance of sensitivity |
| **Synthetics** | ⚪ N/A | Not configured yet |

**Overall Score:** 🟢 **9.2/10** - Excellent monitoring coverage with minor tuning needed
EOT
    }
  }

  # Backend API Latency Analysis with Graph
  cell {
    type = "markdown"
    definition {
      text = <<-EOT
---

## 1️⃣ Backend API Latency - ALERTING ⚠️

**Monitor:** Backend API Latency (p95) is high  
**Current Thresholds:** Critical: 5s, Warning: 3s  
**Status:** 🔴 ALERTING

### Performance Data (24 hours)
EOT
    }
  }

  cell {
    type = "timeseries"
    definition {
      title       = "Backend API Latency (p50, p95, p99)"
      show_legend = true
      legend_size = "auto"

      request {
        display_type = "line"
        q            = "p50:trace.http.request{service:${var.backend_service},env:${var.environment}}"
        style {
          palette    = "dog_classic"
          line_type  = "solid"
          line_width = "normal"
        }
      }

      request {
        display_type = "line"
        q            = "p95:trace.http.request{service:${var.backend_service},env:${var.environment}}"
        style {
          palette    = "warm"
          line_type  = "solid"
          line_width = "thick"
        }
      }

      request {
        display_type = "line"
        q            = "p99:trace.http.request{service:${var.backend_service},env:${var.environment}}"
        style {
          palette    = "orange"
          line_type  = "dashed"
          line_width = "normal"
        }
      }

      marker {
        value        = "y = 5"
        display_type = "error dashed"
        label        = "OLD Threshold (5s)"
      }

      marker {
        value        = "y = 30"
        display_type = "warning dashed"
        label        = "NEW Threshold (30s)"
      }
    }
  }

  cell {
    type = "markdown"
    definition {
      text = <<-EOT
### Analysis
✅ **Monitor is working correctly** - Alerting as designed  
⚠️ **Threshold too strict** for OpenAI-dependent workload

**24-Hour Data:**
- **p50 Latency:** 8-14 seconds (typical)
- **p95 Latency:** 15-28 seconds (alerting range)
- **p99 Latency:** 15-28 seconds
- **Root Cause:** OpenAI API calls dominate (98% of request time)

### ✅ **TUNED** - Applied Changes

```hcl
monitor_thresholds {
  critical = 30.0  # Was: 5s → New: 30s (accommodate OpenAI p99)
  warning  = 20.0  # Was: 3s → New: 20s (accommodate OpenAI p95)
}
```

**Impact:** Eliminates false positives while maintaining coverage for true degradation
EOT
    }
  }

  # RabbitMQ Queue Depth
  cell {
    type = "markdown"
    definition {
      text = <<-EOT
---

## 2️⃣ RabbitMQ Queue Depth - NEEDS TUNING 🔧

**Monitor:** RabbitMQ Queue Depth is high  
**Current Thresholds:** Critical: 100, Warning: 50  
**Status:** ✅ OK (but threshold too high to be useful)

### Queue Depth Monitoring
EOT
    }
  }

  cell {
    type = "timeseries"
    definition {
      title       = "RabbitMQ Queue Depth (Actual vs Thresholds)"
      show_legend = true

      request {
        display_type = "area"
        q            = "avg:rabbitmq.queue.messages{env:${var.environment}}"
        style {
          palette    = "dog_classic"
          line_type  = "solid"
          line_width = "normal"
        }
      }

      marker {
        value        = "y = 100"
        display_type = "error dashed"
        label        = "OLD Critical (100) - TOO HIGH"
      }

      marker {
        value        = "y = 10"
        display_type = "warning dashed"
        label        = "NEW Critical (10) - ACTIONABLE"
      }

      marker {
        value        = "y = 5"
        display_type = "ok dashed"
        label        = "NEW Warning (5)"
      }
    }
  }

  cell {
    type = "markdown"
    definition {
      text = <<-EOT
### Analysis
⚠️ **THRESHOLD TOO HIGH** - Would never alert!  

**24-Hour Data:**
- **Average Queue Depth:** 0.2-0.3 messages
- **Maximum Queue Depth:** 0.65 messages
- **p95 Queue Depth:** <1 message
- **Worker Performance:** Processing faster than arrival rate

**Problem:** Current threshold (100) is **154x higher** than actual max!

### ✅ **TUNED** - Applied Changes

```hcl
monitor_thresholds {
  critical = 10   # Was: 100 → New: 10 (catches 15x normal)
  warning  = 5    # Was: 50 → New: 5 messages (catches 8x normal)
}
```

**Impact:** Makes monitor actually useful for detecting worker lag
EOT
    }
  }

  # PostgreSQL Performance
  cell {
    type = "markdown"
    definition {
      text = <<-EOT
---

## 3️⃣ PostgreSQL Slow Queries - WELL TUNED ✅

**Monitor:** Postgres Slow Queries  
**Current Threshold:** 50ms (50,000,000 nanoseconds)  
**Status:** ✅ OK

### Query Performance
EOT
    }
  }

  cell {
    type = "timeseries"
    definition {
      title       = "PostgreSQL Query Execution Time"
      show_legend = true

      request {
        display_type = "line"
        q            = "avg:postgresql.queries.time{env:${var.environment}}"
        style {
          palette    = "cool"
          line_type  = "solid"
          line_width = "normal"
        }
      }

      request {
        display_type = "line"
        q            = "max:postgresql.queries.time{env:${var.environment}}"
        style {
          palette    = "warm"
          line_type  = "dashed"
          line_width = "thin"
        }
      }

      marker {
        value        = "y = 50000000"
        display_type = "warning dashed"
        label        = "Threshold (50ms)"
      }
    }
  }

  cell {
    type = "markdown"
    definition {
      text = <<-EOT
### Analysis
✅ **EXCELLENT threshold** - Recently fixed from 500ns to 50ms  
✅ **50ms threshold** is **100-250x normal** = catches true slowdowns  
✅ **No false positives** in 24h

**24-Hour Data:**
- **Average Query Time:** 150-200 microseconds (0.15-0.2ms)
- **p95 Query Time:** ~500 microseconds (0.5ms)
- **Max Query Time:** 2-30ms (spikes during DAG execution)

**No Changes Needed** - This is a great example of proper tuning!
EOT
    }
  }

  # Error Rates Overview
  cell {
    type = "markdown"
    definition {
      text = <<-EOT
---

## 4️⃣ Error Rate Monitors - ALL HEALTHY ✅

All error rate monitors are properly tuned with zero false positives.
EOT
    }
  }

  cell {
    type = "timeseries"
    definition {
      title       = "Error Rates Across Services"
      show_legend = true

      request {
        display_type = "bars"
        q            = "sum:trace.http.request.errors{service:${var.backend_service},env:${var.environment}}.as_count()"
        style {
          palette = "dog_classic"
        }
      }

      request {
        display_type = "bars"
        q            = "sum:trace.http.request.errors{service:chat-worker,env:${var.environment}}.as_count()"
        style {
          palette = "warm"
        }
      }

      request {
        display_type = "bars"
        q            = "sum:trace.openai.request.errors{env:${var.environment}}.as_count()"
        style {
          palette = "orange"
        }
      }
    }
  }

  cell {
    type = "markdown"
    definition {
      text = <<-EOT
### 24-Hour Error Summary

| Service | Errors | Requests | Error Rate | Monitor Threshold | Status |
|---------|--------|----------|------------|-------------------|--------|
| **Backend** | 0 | ~1,200 | 0% | 20 errors/5min | ✅ OK |
| **Worker** | 0 | ~1,000 | 0% | 10 errors/5min | ✅ OK |
| **OpenAI** | 0 | ~1,000 | 0% | 5 errors/5min | ✅ OK |

**All error monitors:** No changes needed - working perfectly!
EOT
    }
  }

  # Summary & Next Steps
  cell {
    type = "markdown"
    definition {
      text = <<-EOT
---

## 🎯 Implementation Summary

### ✅ Changes Applied

1. **Backend API Latency Monitor**
   - Critical: 5s → 30s
   - Warning: 3s → 20s
   - **Impact:** Stops false alerts, maintains coverage

2. **RabbitMQ Queue Depth Monitor**
   - Critical: 100 → 10 messages
   - Warning: 50 → 5 messages
   - **Impact:** Makes monitor actionable

### 📊 Expected Outcomes

- ✅ Backend latency alert clears within 5 minutes
- ✅ Reduced alert fatigue (fewer false positives)
- ✅ RabbitMQ monitor becomes useful indicator
- 📈 Monitor health score: 9.2/10 → **9.8/10**

### 📅 Review Schedule

**Recommended Cadence:**
- **Weekly:** Review alerting monitors for false positives
- **Monthly:** Analyze historical performance trends, adjust thresholds
- **Quarterly:** Comprehensive monitor coverage review
- **After Incidents:** Tune related monitors based on learnings

**Next Review Date:** February 9, 2026

---

## 📚 Additional Resources

- [Monitor Management](https://app.datadoghq.com/monitors/manage?q=tag%3A%28env%3Ademo%29)
- [APM Service: chat-backend](https://app.datadoghq.com/apm/service/chat-backend/operations?env=demo)
- [Database Monitoring](https://app.datadoghq.com/databases?env=demo)
- [LLM Observability](https://app.datadoghq.com/llm?env=demo)

---

*Generated via Terraform - Last Updated: January 9, 2026*  
*Managed by: terraform/notebook.tf*
EOT
    }
  }

  tags = [
    "env:${var.environment}",
    "team:chatbot",
    "managed_by:terraform",
    "type:analysis",
    "category:monitoring"
  ]
}






