# Datadog Agent Helm Release
# Note: If you already installed the agent manually via helm, 
# either import it: terraform import helm_release.datadog_agent chat-demo/datadog-agent
# or uninstall it first: helm uninstall datadog-agent -n chat-demo

resource "helm_release" "datadog_agent" {
  name             = "datadog-agent"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  namespace        = var.namespace
  create_namespace = false  # Namespace created by K8s manifests

  values = [
    yamlencode({
      datadog = {
        apiKeyExistingSecret = "datadog-keys"
        appKeyExistingSecret = "datadog-keys"
        site                 = var.datadog_site
        clusterName          = var.cluster_name
        tags                 = ["env:${var.environment}"]
        
        apm = {
          enabled = true
        }
        
        # Application Security Management (ASM)
        appSec = {
          enabled = true
        }
        
        logs = {
          enabled            = true
          containerCollectAll = true
        }
        
        processAgent = {
          enabled           = true
          processCollection = true
        }
        
        networkMonitoring = {
          enabled = true
        }
        
        orchestratorExplorer = {
          enabled = true
        }
        
        databaseMonitoring = {
          enabled = true
        }
        
        # Cloud Security Management (CSM)
        securityAgent = {
          compliance = {
            enabled = true
          }
          runtime = {
            enabled = true
          }
        }
        
        # Container Image Vulnerabilities
        containerImageCollection = {
          enabled = true
        }
        
        kubelet = {
          tlsVerify = false
        }
      }
      
      agents = {
        useHostNetwork = true
        containers = {
          systemProbe = {
            securityContext = {
              capabilities = {
                add = [
                  "SYS_ADMIN",
                  "SYS_RESOURCE",
                  "SYS_PTRACE",
                  "NET_ADMIN",
                  "NET_BROADCAST",
                  "NET_RAW",
                  "IPC_LOCK",
                  "CHOWN"
                ]
              }
            }
          }
        }
      }
      
      targetSystem = "linux"
    })
  ]

  # Ensure secrets exist before deploying agent
  depends_on = []
}

