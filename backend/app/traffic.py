"""Bounded background chat traffic for the chaos control panel."""

import json
import logging
from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore, Event, Lock, Thread

logger = logging.getLogger(__name__)


class TrafficGenerator:
    # Match the rates advertised by the panel: 5, 20, and 60 starts per minute.
    INTERVALS = {"light": 12.0, "medium": 3.0, "heavy": 1.0}
    MAX_IN_FLIGHT = 64
    PROMPTS = (
        "What is Kubernetes?",
        "Explain distributed tracing",
        "How does APM work?",
        "What is observability?",
        "Tell me about microservices",
        "How do load balancers work?",
        "What is Docker?",
        "Explain CI/CD pipelines",
        "What is infrastructure as code?",
        "How does service mesh work?",
    )

    def __init__(self):
        self.running = False
        self.level = "light"
        self.total_requests = 0
        self.completed_requests = 0
        self.successful_requests = 0
        self.in_flight = 0
        self.skipped_requests = 0
        self._lock = Lock()
        self._slots = BoundedSemaphore(self.MAX_IN_FLIGHT)
        self._executor = ThreadPoolExecutor(
            max_workers=self.MAX_IN_FLIGHT, thread_name_prefix="demo-traffic"
        )
        self._stop = Event()
        self._wake = Event()
        self._thread = None

    def start(self, level="light"):
        if level not in self.INTERVALS:
            raise ValueError(f"Unknown traffic level: {level}")
        with self._lock:
            if self.running:
                if self.level != level:
                    self.level = level
                    self._wake.set()
                    logger.info("Traffic generator changed to level: %s", level)
                return
            self.running = True
            self.level = level
            # Each run owns its events so a quick stop/start cannot revive an old loop.
            self._stop = Event()
            self._wake = Event()
            self._thread = Thread(
                target=self._generate_traffic,
                args=(self._stop, self._wake),
                daemon=True,
            )
            self._thread.start()
        logger.info("Traffic generator started at level: %s", level)

    def stop(self):
        with self._lock:
            self.running = False
            self._stop.set()
            self._wake.set()
        logger.info("Traffic generator stopped; in-flight requests may finish")

    def status(self):
        with self._lock:
            completed = self.completed_requests
            return {
                "enabled": self.running,
                "level": self.level,
                "stats": {
                    "total": self.total_requests,
                    "completed": completed,
                    "inFlight": self.in_flight,
                    "failed": completed - self.successful_requests,
                    "skipped": self.skipped_requests,
                    "successRate": round(100 * self.successful_requests / completed, 1)
                    if completed else 100.0,
                },
            }

    def close(self):
        self.stop()
        if self._thread is not None:
            self._thread.join(timeout=1)
        self._executor.shutdown(wait=False)

    def _generate_traffic(self, stop, wake):
        while not stop.is_set():
            with self._lock:
                if stop.is_set():
                    return
                interval = self.INTERVALS[self.level]
                if self._slots.acquire(blocking=False):
                    self._executor.submit(self._send_request, stop)
                else:
                    self.skipped_requests += 1
            # Request duration does not delay the next scheduled start.
            wake.wait(interval)
            wake.clear()

    def _send_request(self, stop):
        success = False
        with self._lock:
            if stop.is_set():
                self._slots.release()
                return
            self.total_requests += 1
            self.in_flight += 1
        try:
            import random
            import requests

            with requests.post(
                "http://localhost:8000/chat",
                json={"prompt": random.choice(self.PROMPTS)},
                stream=True,
                timeout=(5, 60),
            ) as response:
                response.raise_for_status()
                # /chat returns HTTP 200 before the worker finishes. Read the SSE
                # terminal event so a timeout/error is not counted as success.
                for line in response.iter_lines(decode_unicode=True):
                    if not line.startswith("data:"):
                        continue
                    event = json.loads(line[5:].strip())
                    if event.get("type") == "done":
                        success = True
                        break
                    if event.get("type") == "error":
                        logger.warning("Generated chat stream failed: %s", event.get("message"))
                        break
                if not success:
                    logger.warning("Generated chat request did not complete successfully")
        except Exception as exc:
            logger.warning("Generated chat request failed: %s", exc)
        finally:
            with self._lock:
                self.completed_requests += 1
                self.successful_requests += int(success)
                self.in_flight -= 1
            self._slots.release()
