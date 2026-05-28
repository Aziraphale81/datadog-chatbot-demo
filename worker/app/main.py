"""
Chat Worker Service - Processes chat requests from RabbitMQ queue
Instrumented with Datadog APM and Data Streams Monitoring
Uses Kombu for RabbitMQ (required for DSM support)
"""
import os
import json
import time
import logging
import sys
import threading
from typing import Dict, Any
from openai import OpenAI
from ddtrace import tracer, patch
# DSM checkpoints: Automatic via DD_DATA_STREAMS_ENABLED + Kombu
# from ddtrace.data_streams import set_checkpoint
from app.messaging import RabbitMQClient
from pythonjsonlogger import jsonlogger

# Enable Datadog APM tracing (kombu auto-instrumented for DSM)
patch(logging=True, kombu=True)

# Structured JSON logging for Datadog log correlation
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(jsonlogger.JsonFormatter(
    "%(asctime)s %(name)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S"
))
logging.root.setLevel(logging.INFO)
logging.root.handlers = [handler]
logger = logging.getLogger(__name__)

# Configuration
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_PORT = int(os.getenv('RABBITMQ_PORT', '5672'))
RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'guest')
RABBITMQ_PASS = os.getenv('RABBITMQ_PASS', 'guest')
REQUEST_QUEUE = os.getenv('REQUEST_QUEUE', 'chat_requests')
RESPONSE_QUEUE = os.getenv('RESPONSE_QUEUE', 'chat_responses')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-5-nano')

# Initialize OpenAI client (30s timeout to fail fast on bad key or API slowness)
openai_client = OpenAI(api_key=OPENAI_API_KEY, timeout=30.0)


# ---------------------------------------------------------------------------
# Circuit breaker for OpenAI calls
# ---------------------------------------------------------------------------
import threading as _threading
from enum import Enum as _Enum

class _CircuitState(_Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class _CircuitBreaker:
    def __init__(self, failure_threshold=3, reset_timeout=60.0):
        self._state = _CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time = 0.0
        self._threshold = failure_threshold
        self._reset_timeout = reset_timeout
        self._lock = _threading.Lock()

    @property
    def state(self):
        with self._lock:
            if self._state == _CircuitState.OPEN:
                if time.time() - self._last_failure_time >= self._reset_timeout:
                    self._state = _CircuitState.HALF_OPEN
                    logger.info("Circuit breaker: OPEN → HALF_OPEN (probing)")
            return self._state

    def allow_request(self):
        return self.state != _CircuitState.OPEN

    def record_success(self):
        with self._lock:
            self._failure_count = 0
            if self._state == _CircuitState.HALF_OPEN:
                self._state = _CircuitState.CLOSED
                logger.info("Circuit breaker: HALF_OPEN → CLOSED")

    def record_failure(self):
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.time()
            if self._failure_count >= self._threshold:
                if self._state != _CircuitState.OPEN:
                    logger.warning(f"Circuit breaker: → OPEN after {self._failure_count} failures")
                self._state = _CircuitState.OPEN

openai_circuit_breaker = _CircuitBreaker(failure_threshold=3, reset_timeout=60.0)


# Kombu client (global)
rabbitmq_client: RabbitMQClient = None

def init_rabbitmq():
    """Initialize RabbitMQ connection using Kombu. Retries until RabbitMQ is ready (e.g. after cluster startup)."""
    global rabbitmq_client
    max_retries = 30
    retry_delay = 10

    for attempt in range(max_retries):
        try:
            rabbitmq_client = RabbitMQClient(
                host=RABBITMQ_HOST,
                port=RABBITMQ_PORT,
                user=RABBITMQ_USER,
                password=RABBITMQ_PASS
            )
            rabbitmq_client.connect()
            logger.info(f"Connected to RabbitMQ via Kombu at {RABBITMQ_HOST}:{RABBITMQ_PORT}")
            return
        except Exception as e:
            logger.warning(f"Connection attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
            else:
                raise


def call_openai_streaming(prompt: str, conversation_history: list = None):
    """Generator that yields (chunk_text, is_done, usage_dict) tuples.
    is_done=True only on the final yield, with usage_dict populated.
    Raises exception (circuit-broken) if circuit breaker is OPEN.
    """
    if not openai_circuit_breaker.allow_request():
        raise Exception(f"OpenAI circuit breaker is OPEN — fast-failing (will retry after 60s)")

    messages = list(conversation_history or [])
    messages.append({"role": "user", "content": prompt})

    create_params = {
        "model": OPENAI_MODEL,
        "messages": messages,
        "stream": True,
    }
    if "gpt-5" not in OPENAI_MODEL.lower():
        create_params["temperature"] = 0.7
        create_params["max_completion_tokens"] = 2000

    with tracer.trace("openai.chat.completions.stream", service="openai-api") as span:
        span.set_tag("openai.model", OPENAI_MODEL)
        span.set_tag("openai.prompt_length", len(prompt))
        try:
            stream = openai_client.chat.completions.create(**create_params)
            full_text = []
            for chunk in stream:
                delta = chunk.choices[0].delta.content if chunk.choices and chunk.choices[0].delta else None
                if delta:
                    full_text.append(delta)
                    yield delta, False, None  # chunk text, not done, no usage yet
            # stream exhausted - record success
            openai_circuit_breaker.record_success()
            usage = {"prompt_tokens": 0, "completion_tokens": len(full_text), "total_tokens": len(full_text)}
            yield None, True, usage  # no new text, done=True, usage dict
        except Exception as e:
            openai_circuit_breaker.record_failure()
            span.set_tag("error", True)
            span.set_tag("error.message", str(e))
            logger.error(f"OpenAI streaming error: {e}")
            raise


def process_message(message_data: dict):
    """Process a single chat request message (DSM auto-instrumented by Kombu)"""
    request_id = message_data.get('request_id', 'unknown')

    with tracer.trace("worker.process_message", service="chat-worker", resource="process_chat_request") as span:
        span.set_tag("request.id", request_id)

        try:
            session_id = message_data.get('session_id')
            prompt = message_data.get('prompt')
            conversation_history = message_data.get('conversation_history', [])

            logger.info(f"Processing request {request_id} for session {session_id}")

            span.set_tag("session.id", session_id)
            span.set_tag("prompt.length", len(prompt))

            start_time = time.time()
            full_response = []

            for chunk_text, is_done, usage_dict in call_openai_streaming(prompt, conversation_history):
                if not is_done:
                    # Publish each chunk to the response queue
                    chunk_message = {
                        "request_id": request_id,
                        "session_id": session_id,
                        "type": "chunk",
                        "content": chunk_text,
                        "timestamp": time.time(),
                    }
                    rabbitmq_client.publish(RESPONSE_QUEUE, chunk_message)
                    full_response.append(chunk_text)
                else:
                    # Stream exhausted — publish done message
                    processing_time = time.time() - start_time
                    span.set_metric("processing.time", processing_time)
                    logger.info(f"OpenAI streaming finished in {processing_time:.2f}s")

                    done_message = {
                        "request_id": request_id,
                        "session_id": session_id,
                        "type": "done",
                        "prompt": prompt,
                        "response": "".join(full_response),
                        "usage": usage_dict,
                        "processing_time": processing_time,
                        "timestamp": time.time(),
                    }
                    rabbitmq_client.publish(RESPONSE_QUEUE, done_message)
                    logger.info(f"Done message published for request {request_id}")

            span.set_tag("status", "success")

        except Exception as e:
            logger.error(f"Error processing message: {e}", exc_info=True)
            span.set_tag("error", True)
            span.set_tag("error.type", type(e).__name__)
            span.set_tag("error.message", str(e))
            # Publish error response so backend returns quickly instead of waiting 60s timeout
            try:
                error_response = {
                    "request_id": request_id,
                    "session_id": message_data.get("session_id", ""),
                    "type": "error",
                    "prompt": message_data.get("prompt", ""),
                    "response": "Something went wrong. Check backend or OpenAI key.",
                    "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
                    "processing_time": 0,
                    "timestamp": time.time(),
                }
                rabbitmq_client.publish(RESPONSE_QUEUE, error_response)
                logger.info(f"Published error response for request {request_id}")
            except Exception as pub_err:
                logger.error(f"Failed to publish error response: {pub_err}")
            raise  # Kombu will handle rejection/requeue


def _heartbeat_loop():
    """Touch /tmp/worker_heartbeat every 30s so the liveness probe knows we're alive."""
    while True:
        try:
            open('/tmp/worker_heartbeat', 'w').close()
        except Exception:
            pass
        time.sleep(30)


def main():
    """Main worker loop using Kombu for DSM support. Reconnects and re-consumes on connection loss (e.g. RabbitMQ restart)."""
    global rabbitmq_client
    logger.info(f"Starting Chat Worker (model: {OPENAI_MODEL})")
    if not OPENAI_API_KEY or not OPENAI_API_KEY.strip():
        logger.warning("OPENAI_API_KEY is not set; OpenAI calls will fail and clients will get error responses")
    logger.info(f"Request queue: {REQUEST_QUEUE}, Response queue: {RESPONSE_QUEUE}")
    logger.info("Using Kombu for RabbitMQ (DSM enabled)")

    threading.Thread(target=_heartbeat_loop, daemon=True).start()

    while True:
        try:
            open('/tmp/worker_heartbeat', 'w').close()
            init_rabbitmq()
            logger.info("Worker ready, waiting for messages...")
            rabbitmq_client.consume(REQUEST_QUEUE, process_message)
        except KeyboardInterrupt:
            logger.info("Worker shutting down...")
            break
        except Exception as e:
            logger.error(f"Consumer error (will reconnect in 10s): {e}", exc_info=True)
            if rabbitmq_client:
                try:
                    rabbitmq_client.close()
                except Exception:
                    pass
                rabbitmq_client = None  # type: ignore[assignment]
            time.sleep(10)
    if rabbitmq_client:
        try:
            rabbitmq_client.close()
        except Exception:
            pass
    logger.info("Worker stopped")


if __name__ == "__main__":
    main()
