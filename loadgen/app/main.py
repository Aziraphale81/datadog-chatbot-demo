"""
Load Generator — sends realistic chat traffic to the backend API.

Designed for Datadog observability demos: maintains persistent sessions,
generates varied prompts across topic categories, supports configurable
request rate, and optionally injects errors and slow responses.

Usage:
  python -m app.main                   # default: 1 req/s, random sessions
  LOAD_RPS=3 python -m app.main        # 3 requests per second
  LOAD_ERROR_RATE=0.1 python -m app.main  # 10% error injection
  LOAD_SESSIONS=5 python -m app.main   # maintain 5 concurrent sessions
"""

import os
import time
import uuid
import random
import logging
import httpx

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [loadgen] %(levelname)s %(message)s",
)
logger = logging.getLogger("loadgen")

# ── Configuration ─────────────────────────────────────────────────────────────
BACKEND_URL = os.getenv("BACKEND_URL", "http://backend:8000")
LOAD_RPS = float(os.getenv("LOAD_RPS", "1.0"))          # requests per second
LOAD_SESSIONS = int(os.getenv("LOAD_SESSIONS", "3"))     # concurrent session pool size
LOAD_ERROR_RATE = float(os.getenv("LOAD_ERROR_RATE", "0.0"))  # 0.0–1.0
LOAD_SLOW_RATE = float(os.getenv("LOAD_SLOW_RATE", "0.0"))    # fraction that send a very long prompt
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", "90.0"))  # seconds
# ──────────────────────────────────────────────────────────────────────────────

# Realistic prompt bank grouped by category.
# Variety ensures LLM Observability shows diverse input distributions.
PROMPTS = {
    "general": [
        "What's the best way to explain microservices to a non-technical manager?",
        "Can you summarize the key differences between REST and GraphQL?",
        "Give me a one-paragraph explanation of how DNS works.",
        "What are the tradeoffs between monoliths and microservices?",
        "Explain eventual consistency in distributed systems like I'm five.",
    ],
    "devops": [
        "What Kubernetes resource should I use to run a one-time job?",
        "How do I set resource requests and limits in a K8s Deployment?",
        "What's the difference between a Deployment and a StatefulSet?",
        "Explain the purpose of a Kubernetes liveness vs readiness probe.",
        "When should I use a DaemonSet instead of a Deployment?",
    ],
    "observability": [
        "What's the difference between metrics, logs, and traces?",
        "How does distributed tracing propagate context across services?",
        "What is the RED method for monitoring microservices?",
        "Explain what a flame graph shows in a profiler.",
        "What is the difference between p50, p95, and p99 latency?",
        "What is Data Streams Monitoring and when would I use it?",
        "How does OpenTelemetry differ from Datadog's native instrumentation?",
    ],
    "python": [
        "What's the difference between asyncio and threading in Python?",
        "When should I use a dataclass vs a Pydantic model?",
        "How does Python's GIL affect multi-threaded programs?",
        "What is the difference between __repr__ and __str__?",
        "Explain Python decorators with a concrete example.",
    ],
    "databases": [
        "What's the difference between a B-tree and a hash index?",
        "When should I use a database transaction?",
        "Explain the ACID properties of a relational database.",
        "What is connection pooling and why does it matter?",
        "What are the tradeoffs of denormalizing a database schema?",
    ],
}

ALL_PROMPTS = [p for prompts in PROMPTS.values() for p in prompts]

# Very long prompt used for slow-request injection
SLOW_PROMPT = (
    "Please write a comprehensive 800-word technical deep-dive on the following topic, "
    "including historical context, current best practices, common pitfalls, and future "
    "directions. The topic is: the evolution of observability tooling from the early days "
    "of Nagios and Graphite through modern distributed tracing and AI-assisted anomaly "
    "detection. Please be thorough and include specific examples."
)

# Malformed request used for error injection
ERROR_PAYLOADS = [
    {"prompt": ""},                         # empty prompt → 400
    {"prompt": "   "},                      # whitespace-only → 400
    {"session_id": "not-a-uuid", "prompt": "test"},  # invalid UUID (may 500)
]


def pick_prompt(inject_error: bool, inject_slow: bool) -> dict:
    """Build a request payload."""
    if inject_error:
        return random.choice(ERROR_PAYLOADS)
    if inject_slow:
        return {"prompt": SLOW_PROMPT}
    return {"prompt": random.choice(ALL_PROMPTS)}


class SessionPool:
    """Maintains a fixed pool of session IDs, rotating them to simulate real users."""

    def __init__(self, size: int, client: httpx.Client):
        self._client = client
        self._sessions: list[str] = []
        self._size = size
        self._initialize()

    def _initialize(self):
        for _ in range(self._size):
            sid = self._create_session()
            if sid:
                self._sessions.append(sid)
        if not self._sessions:
            # Fall through to ad-hoc session creation in /chat
            logger.warning("No sessions pre-created; /chat will create them ad-hoc")

    def _create_session(self) -> str | None:
        try:
            resp = self._client.post(f"{BACKEND_URL}/sessions", timeout=10)
            resp.raise_for_status()
            sid = resp.json()["id"]
            logger.info(f"Created session {sid}")
            return sid
        except Exception as e:
            logger.warning(f"Failed to create session: {e}")
            return None

    def pick(self) -> str | None:
        """Return a random session ID from the pool, or None to let /chat create one."""
        if not self._sessions:
            return None
        return random.choice(self._sessions)

    def rotate(self):
        """Replace the oldest session with a fresh one (simulates session churn)."""
        if self._sessions:
            old = self._sessions.pop(0)
            logger.info(f"Retiring session {old}")
        new = self._create_session()
        if new:
            self._sessions.append(new)


def send_request(client: httpx.Client, session_id: str | None, payload: dict) -> dict:
    """Send a single /chat request and return a result summary."""
    if session_id:
        payload = {**payload, "session_id": session_id}

    start = time.monotonic()
    try:
        resp = client.post(
            f"{BACKEND_URL}/chat",
            json=payload,
            timeout=REQUEST_TIMEOUT,
        )
        elapsed = time.monotonic() - start
        status = resp.status_code
        ok = 200 <= status < 300
        if ok:
            logger.info(
                f"OK  {status} | {elapsed:.2f}s | session={session_id} | "
                f"prompt='{payload.get('prompt', '')[:60]}'"
            )
        else:
            logger.warning(
                f"ERR {status} | {elapsed:.2f}s | session={session_id} | "
                f"body={resp.text[:120]}"
            )
        return {"ok": ok, "status": status, "elapsed": elapsed}
    except httpx.TimeoutException:
        elapsed = time.monotonic() - start
        logger.error(f"TIMEOUT after {elapsed:.2f}s | session={session_id}")
        return {"ok": False, "status": 0, "elapsed": elapsed}
    except Exception as e:
        elapsed = time.monotonic() - start
        logger.error(f"EXCEPTION {e} | {elapsed:.2f}s | session={session_id}")
        return {"ok": False, "status": 0, "elapsed": elapsed}


def wait_for_backend(client: httpx.Client, max_wait: int = 120) -> None:
    """Block until the backend /health endpoint responds, or raise after max_wait seconds."""
    deadline = time.monotonic() + max_wait
    while time.monotonic() < deadline:
        try:
            resp = client.get(f"{BACKEND_URL}/health", timeout=5)
            if resp.status_code == 200:
                logger.info("Backend is healthy — starting load generation")
                return
        except Exception:
            pass
        logger.info("Waiting for backend...")
        time.sleep(5)
    raise RuntimeError(f"Backend did not become healthy within {max_wait}s")


def main():
    logger.info(
        f"Load generator starting | RPS={LOAD_RPS} | sessions={LOAD_SESSIONS} | "
        f"error_rate={LOAD_ERROR_RATE} | slow_rate={LOAD_SLOW_RATE} | "
        f"backend={BACKEND_URL}"
    )

    interval = 1.0 / LOAD_RPS
    rotate_every = 20  # rotate one session out of the pool every N requests

    with httpx.Client() as client:
        wait_for_backend(client)
        pool = SessionPool(size=LOAD_SESSIONS, client=client)

        req_count = 0
        while True:
            loop_start = time.monotonic()

            inject_error = random.random() < LOAD_ERROR_RATE
            inject_slow = (not inject_error) and (random.random() < LOAD_SLOW_RATE)
            payload = pick_prompt(inject_error, inject_slow)
            session_id = pool.pick()

            send_request(client, session_id, payload)

            req_count += 1
            if req_count % rotate_every == 0:
                pool.rotate()

            # Sleep the remainder of the interval to maintain target RPS
            elapsed = time.monotonic() - loop_start
            sleep_for = max(0.0, interval - elapsed)
            if sleep_for > 0:
                time.sleep(sleep_for)


if __name__ == "__main__":
    main()
