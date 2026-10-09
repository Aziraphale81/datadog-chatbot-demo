import sys
import time
import unittest
from threading import Event
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from backend.app.traffic import TrafficGenerator


class TrafficGeneratorTests(unittest.TestCase):
    def setUp(self):
        self.capacity = patch.object(TrafficGenerator, "MAX_IN_FLIGHT", 2)
        self.capacity.start()
        self.generator = TrafficGenerator()

    def tearDown(self):
        self.generator.close()
        self.generator._executor.shutdown(wait=True)
        self.capacity.stop()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.005)
        self.fail("Timed out waiting for generator state")

    def response(self, lines):
        response = MagicMock()
        response.__enter__.return_value = response
        response.iter_lines.return_value = iter(lines)
        return response

    def send_once(self, post):
        self.generator._slots.acquire()
        with patch.dict(sys.modules, {"requests": SimpleNamespace(post=post)}):
            self.generator._send_request(Event())
        return self.generator.status()["stats"]

    def test_success_requires_a_terminal_stream_event(self):
        post = MagicMock(return_value=self.response([
            ': keepalive', '', 'data: {"type":"chunk","content":"hello"}',
            'data: {"type":"done","reply":"hello"}',
        ]))
        stats = self.send_once(post)
        self.assertEqual((stats["total"], stats["completed"], stats["failed"]), (1, 1, 0))
        self.assertEqual(stats["successRate"], 100)
        self.assertEqual(stats["inFlight"], 0)
        self.assertTrue(post.call_args.kwargs["stream"])

    def test_http_200_with_sse_error_is_a_failure(self):
        stats = self.send_once(MagicMock(return_value=self.response([
            'data: {"type":"error","message":"Worker timeout"}',
        ])))
        self.assertEqual(stats["failed"], 1)
        self.assertEqual(stats["successRate"], 0)

    def test_incomplete_stream_and_transport_failures_are_counted(self):
        for post in [
            MagicMock(return_value=self.response(['data: {"type":"chunk"}'])),
            MagicMock(side_effect=TimeoutError("timeout")),
            MagicMock(side_effect=ConnectionError("connection refused")),
        ]:
            self.send_once(post)
        stats = self.generator.status()["stats"]
        self.assertEqual((stats["total"], stats["completed"], stats["failed"]), (3, 3, 3))
        self.assertEqual(stats["inFlight"], 0)

    def test_slow_responses_allow_concurrency_but_stay_bounded(self):
        release = Event()
        entered = Event()

        def slow_post(*args, **kwargs):
            if self.generator.status()["stats"]["total"] == 2:
                entered.set()
            release.wait(2)
            return self.response(['data: {"type":"done"}'])

        with patch.dict(TrafficGenerator.INTERVALS, {"heavy": 0.005}), \
             patch.dict(sys.modules, {"requests": SimpleNamespace(post=slow_post)}):
            try:
                self.generator.start("heavy")
                self.assertTrue(entered.wait(2), "Second request waited for first response")
                self.wait_for(lambda: self.generator.status()["stats"]["skipped"] > 0)
                stats = self.generator.status()["stats"]
                self.assertEqual(stats["total"], 2)
                self.assertEqual(stats["inFlight"], 2)
                self.generator.stop()
            finally:
                release.set()
                self.generator.close()
                self.generator._executor.shutdown(wait=True)
        self.assertEqual(self.generator.status()["stats"]["completed"], 2)

    def test_level_changes_wake_running_generator_without_another_loop(self):
        post = MagicMock(side_effect=lambda *args, **kwargs: self.response(['data: {"type":"done"}']))
        with patch.dict(TrafficGenerator.INTERVALS, {"light": 60, "heavy": 0.01}), \
             patch.dict(sys.modules, {"requests": SimpleNamespace(post=post)}):
            self.generator.start("light")
            self.wait_for(lambda: self.generator.status()["stats"]["completed"] == 1)
            thread = self.generator._thread
            self.generator.start("heavy")
            self.assertIs(self.generator._thread, thread)
            self.wait_for(lambda: self.generator.status()["stats"]["completed"] >= 3)
            self.assertEqual(self.generator.status()["level"], "heavy")
            self.generator.close()
            self.generator._executor.shutdown(wait=True)

    def test_stop_then_restart_does_not_revive_the_old_loop(self):
        post = MagicMock(side_effect=lambda *args, **kwargs: self.response(['data: {"type":"done"}']))
        with patch.dict(TrafficGenerator.INTERVALS, {"light": 60}), \
             patch.dict(sys.modules, {"requests": SimpleNamespace(post=post)}):
            self.generator.start()
            self.wait_for(lambda: self.generator.status()["stats"]["completed"] == 1)
            old_thread = self.generator._thread
            self.generator.stop()
            self.generator.start()
            old_thread.join(timeout=1)
            self.assertFalse(old_thread.is_alive())
            self.wait_for(lambda: self.generator.status()["stats"]["completed"] == 2)
            self.generator.stop()
            self.generator._thread.join(timeout=1)
            self.assertFalse(self.generator.status()["enabled"])
            self.assertEqual(self.generator.status()["stats"]["total"], 2)

    def test_invalid_level_does_not_start_traffic(self):
        with self.assertRaises(ValueError):
            self.generator.start("invalid")
        self.assertFalse(self.generator.status()["enabled"])


if __name__ == "__main__":
    unittest.main()
