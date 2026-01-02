"""
Chaos Engineering and Traffic Generation API
Provides endpoints for demo purposes to simulate load and inject failures
"""

import asyncio
import logging
import random
import time
from typing import Dict, List, Optional
from threading import Thread

logger = logging.getLogger(__name__)

# Try to import kubernetes client
try:
    from kubernetes import client, config
    # Load in-cluster config
    config.load_incluster_config()
    K8S_AVAILABLE = True
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()
    logger.info("Kubernetes client loaded successfully")
except Exception as e:
    K8S_AVAILABLE = False
    logger.warning(f"Kubernetes client not available: {e}")
    apps_v1 = None
    core_v1 = None

NAMESPACE = "chat-demo"

# Global state for chaos control
chaos_state = {
    "trafficEnabled": False,
    "trafficLevel": "light",
    "activeScenarios": [],
    "trafficStats": {
        "total": 0,
        "successRate": 100.0
    },
    "traffic_thread": None
}

class TrafficGenerator:
    """Background traffic generator"""
    
    def __init__(self):
        self.running = False
        self.total_requests = 0
        self.successful_requests = 0
        
    def start(self, level: str = "light"):
        """Start generating traffic"""
        if self.running:
            return
            
        self.running = True
        self.level = level
        
        # Determine request frequency based on level
        intervals = {
            "light": (10, 20),   # 3-6 req/min
            "medium": (3, 5),    # 12-20 req/min  
            "heavy": (1, 2)      # 30-60 req/min
        }
        self.min_interval, self.max_interval = intervals.get(level, (10, 20))
        
        thread = Thread(target=self._generate_traffic, daemon=True)
        thread.start()
        chaos_state["traffic_thread"] = thread
        logger.info(f"Traffic generator started at level: {level}")
        
    def stop(self):
        """Stop generating traffic"""
        self.running = False
        logger.info("Traffic generator stopped")
        
    def _generate_traffic(self):
        """Background loop to generate chat requests"""
        import requests
        
        prompts = [
            "What is Kubernetes?",
            "Explain distributed tracing",
            "How does APM work?",
            "What is observability?",
            "Tell me about microservices",
            "How do load balancers work?",
            "What is Docker?",
            "Explain CI/CD pipelines",
            "What is infrastructure as code?",
            "How does service mesh work?"
        ]
        
        while self.running:
            try:
                interval = random.uniform(self.min_interval, self.max_interval)
                time.sleep(interval)
                
                # Send chat request to backend (same pod, localhost)
                response = requests.post(
                    "http://localhost:8000/chat",
                    json={"prompt": random.choice(prompts)},
                    timeout=45  # Increased timeout to prevent premature failures
                )
                
                self.total_requests += 1
                if response.status_code == 200:
                    self.successful_requests += 1
                
                # Update stats
                if self.total_requests > 0:
                    chaos_state["trafficStats"]["total"] = self.total_requests
                    chaos_state["trafficStats"]["successRate"] = round(
                        (self.successful_requests / self.total_requests) * 100, 1
                    )
                    
                logger.debug(f"Traffic request sent: {response.status_code}")
                
            except requests.exceptions.Timeout:
                # Don't count timeouts during startup/restart
                logger.warning(f"Traffic request timed out (backend may be restarting)")
                self.total_requests += 1
            except requests.exceptions.ConnectionError:
                # Backend not available - likely restarting, don't count
                logger.warning(f"Traffic request failed: backend unavailable")
            except Exception as e:
                logger.error(f"Traffic generation error: {e}")
                self.total_requests += 1

# Global traffic generator instance
traffic_generator = TrafficGenerator()


def scale_deployment(name: str, replicas: int) -> tuple:
    """Scale a deployment to specific replica count"""
    if not K8S_AVAILABLE:
        return False, "Kubernetes client not available"
    
    try:
        # Patch the deployment
        apps_v1.patch_namespaced_deployment_scale(
            name=name,
            namespace=NAMESPACE,
            body={"spec": {"replicas": replicas}}
        )
        logger.info(f"Scaled {name} to {replicas} replicas")
        return True, f"Scaled {name} to {replicas} replicas"
    except Exception as e:
        logger.error(f"Failed to scale {name}: {e}")
        return False, str(e)


def set_env_var(deployment: str, env_name: str, env_value: Optional[str], restore_secret: bool = False) -> tuple:
    """Set or remove an environment variable on a deployment
    
    Args:
        deployment: Name of the deployment
        env_name: Name of the environment variable
        env_value: Value to set (None to remove, ignored if restore_secret=True)
        restore_secret: If True, restore to original secret-based configuration
    """
    if not K8S_AVAILABLE:
        return False, "Kubernetes client not available"
    
    try:
        from kubernetes.client import V1EnvVar, V1EnvVarSource, V1SecretKeySelector
        
        # Get current deployment
        dep = apps_v1.read_namespaced_deployment(deployment, NAMESPACE)
        
        # Find and update the container env
        container = dep.spec.template.spec.containers[0]
        env_list = list(container.env) if container.env else []
        
        # Remove existing env var with this name
        env_list = [e for e in env_list if e.name != env_name]
        
        # Add new value based on parameters
        if restore_secret and env_name == "OPENAI_API_KEY":
            # Restore the secret-based configuration (don't set value at all)
            env_var = V1EnvVar(
                name=env_name,
                value_from=V1EnvVarSource(
                    secret_key_ref=V1SecretKeySelector(
                        name="openai-key",
                        key="openai-api-key"
                    )
                )
            )
            env_list.append(env_var)
            action = f"Restored {env_name} from secret"
        elif env_value is not None:
            # Set plain text value (don't set value_from at all)
            env_var = V1EnvVar(name=env_name, value=env_value)
            env_list.append(env_var)
            action = f"Set {env_name}={env_value}"
        else:
            action = f"Removed {env_name}"
        
        container.env = env_list
        
        # Update deployment
        apps_v1.patch_namespaced_deployment(
            name=deployment,
            namespace=NAMESPACE,
            body=dep
        )
        
        logger.info(f"{action} on {deployment}")
        return True, action
    except Exception as e:
        logger.error(f"Failed to set env var on {deployment}: {e}")
        return False, str(e)


def set_resource_limit(deployment: str, memory_limit: str, memory_request: str = None) -> tuple:
    """Set memory limit and optionally request on a deployment"""
    if not K8S_AVAILABLE:
        return False, "Kubernetes client not available"
    
    try:
        # Get current deployment
        dep = apps_v1.read_namespaced_deployment(deployment, NAMESPACE)
        
        # Update memory limit and request
        container = dep.spec.template.spec.containers[0]
        if not container.resources:
            from kubernetes.client import V1ResourceRequirements
            container.resources = V1ResourceRequirements()
        
        if not container.resources.limits:
            container.resources.limits = {}
        if not container.resources.requests:
            container.resources.requests = {}
        
        container.resources.limits['memory'] = memory_limit
        if memory_request:
            container.resources.requests['memory'] = memory_request
        
        # Update deployment
        apps_v1.patch_namespaced_deployment(
            name=deployment,
            namespace=NAMESPACE,
            body=dep
        )
        
        msg = f"Set memory limit to {memory_limit}"
        if memory_request:
            msg += f", request to {memory_request}"
        logger.info(f"{msg} on {deployment}")
        return True, msg
    except Exception as e:
        logger.error(f"Failed to set resource limit on {deployment}: {e}")
        return False, str(e)


def restart_deployment(deployment: str) -> tuple:
    """Restart a deployment by updating its restart annotation"""
    if not K8S_AVAILABLE:
        return False, "Kubernetes client not available"
    
    try:
        # Get current deployment
        dep = apps_v1.read_namespaced_deployment(deployment, NAMESPACE)
        
        # Update restart annotation
        if not dep.spec.template.metadata.annotations:
            dep.spec.template.metadata.annotations = {}
        
        dep.spec.template.metadata.annotations['kubectl.kubernetes.io/restartedAt'] = time.strftime('%Y%m%d-%H%M%S')
        
        # Update deployment
        apps_v1.patch_namespaced_deployment(
            name=deployment,
            namespace=NAMESPACE,
            body=dep
        )
        
        logger.info(f"Restarted {deployment}")
        return True, f"Restarted {deployment}"
    except Exception as e:
        logger.error(f"Failed to restart {deployment}: {e}")
        return False, str(e)


async def trigger_scenario(scenario_id: str) -> Dict:
    """Trigger a break-fix scenario"""
    
    if not K8S_AVAILABLE:
        return {
            "success": False,
            "error": "Kubernetes client not available - chaos features disabled"
        }
    
    success = False
    output = ""
    description = ""
    
    if scenario_id == "worker-crash":
        success, output = scale_deployment("chat-worker", 0)
        description = "Worker scaled to 0"
        if success and scenario_id not in chaos_state["activeScenarios"]:
            chaos_state["activeScenarios"].append(scenario_id)
            
    elif scenario_id == "memory-pressure":
        # First, reduce memory limit to create pressure
        success, output = set_resource_limit("backend", "128Mi", "128Mi")
        description = "Backend memory limited to 128Mi"
        if success and scenario_id not in chaos_state["activeScenarios"]:
            chaos_state["activeScenarios"].append(scenario_id)
            
    elif scenario_id == "queue-backup":
        success, output = scale_deployment("chat-worker", 0)
        description = "Message processing paused"
        if success and scenario_id not in chaos_state["activeScenarios"]:
            chaos_state["activeScenarios"].append(scenario_id)
            
    elif scenario_id == "api-errors":
        success, output = set_env_var("chat-worker", "OPENAI_API_KEY", "invalid-key-for-testing")
        description = "OpenAI API key invalidated"
        if success and scenario_id not in chaos_state["activeScenarios"]:
            chaos_state["activeScenarios"].append(scenario_id)
            
    elif scenario_id == "db-slow":
        # This one is simulated - just mark as active
        success = True
        output = "Database slowdown simulated (visual indicator only)"
        description = "Database slowdown simulated"
        if scenario_id not in chaos_state["activeScenarios"]:
            chaos_state["activeScenarios"].append(scenario_id)
            
    elif scenario_id == "network-latency":
        # This one is simulated - requires tc which isn't available
        success = True
        output = "Network latency simulated (visual indicator only)"
        description = "Network latency simulated"
        if scenario_id not in chaos_state["activeScenarios"]:
            chaos_state["activeScenarios"].append(scenario_id)
            
    elif scenario_id == "heal-all":
        # Restore all scenarios
        results = []
        results.append(scale_deployment("chat-worker", 1))
        results.append(set_resource_limit("backend", "256Mi", "256Mi"))
        results.append(set_env_var("chat-worker", "OPENAI_API_KEY", None, restore_secret=True))  # Restore secret-based key
        
        success = all(r[0] for r in results)
        output = "; ".join(r[1] for r in results)
        description = "All scenarios healed"
        chaos_state["activeScenarios"] = []
        
    elif scenario_id == "restart-all":
        # Restart all services
        results = []
        for deployment in ["backend", "frontend", "chat-worker"]:
            results.append(restart_deployment(deployment))
        
        success = all(r[0] for r in results)
        output = "; ".join(r[1] for r in results)
        description = "All services restarted"
        chaos_state["activeScenarios"] = []
        
    else:
        return {"success": False, "error": f"Unknown scenario: {scenario_id}"}
    
    if success:
        logger.info(f"Scenario triggered: {scenario_id} - {description}")
        return {
            "success": True,
            "scenario": scenario_id,
            "description": description,
            "output": output
        }
    else:
        logger.error(f"Scenario failed: {scenario_id} - {output}")
        return {
            "success": False,
            "scenario": scenario_id,
            "error": output
        }


async def get_system_status() -> Dict:
    """Check health status of all services"""
    
    if not K8S_AVAILABLE:
        return {
            "backend": "unknown",
            "worker": "unknown",
            "database": "unknown",
            "rabbitmq": "unknown"
        }
    
    def check_service(deployment: str) -> str:
        try:
            dep = apps_v1.read_namespaced_deployment(deployment, NAMESPACE)
            available = dep.status.available_replicas or 0
            desired = dep.spec.replicas or 0
            
            if available > 0 and available >= desired:
                return "healthy"
            return "unhealthy"
        except Exception as e:
            logger.error(f"Failed to check {deployment}: {e}")
            return "unhealthy"
    
    return {
        "backend": check_service("backend"),
        "worker": check_service("chat-worker"),
        "database": check_service("postgres"),
        "rabbitmq": check_service("rabbitmq")
    }


def toggle_traffic(enabled: bool, level: str = "light") -> Dict:
    """Enable or disable traffic generation"""
    
    if enabled:
        traffic_generator.start(level)
        chaos_state["trafficEnabled"] = True
        chaos_state["trafficLevel"] = level
    else:
        traffic_generator.stop()
        chaos_state["trafficEnabled"] = False
    
    return {
        "enabled": chaos_state["trafficEnabled"],
        "level": chaos_state["trafficLevel"]
    }


async def get_chaos_status() -> Dict:
    """Get current chaos control panel status"""
    
    system_status = await get_system_status()
    
    return {
        **chaos_state,
        **system_status,
        "traffic_thread": None,  # Don't serialize thread object
        "k8s_available": K8S_AVAILABLE
    }
