"""Transport tests use small protocol fakes; exact algebra tests use real Lean."""
from __future__ import annotations

import http.client
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import (  # noqa: E402
    BridgeError, DEFAULT_ENGINE, ExteriorServer, LeanEngine, validate_request,
)

REQUEST = {"id": 7, "a": [8, 0, 0], "b": [0, 6, 0], "c": [0, 0, 5]}
ECHO = """
import json,sys
counter=0
for line in sys.stdin:
    r=json.loads(line); counter+=1
    print(json.dumps({'ok':True,'id':r.get('id'),'counter':counter}),flush=True)
"""


def fake_engine(code: str = ECHO, timeout: float = 1.0) -> LeanEngine:
    return LeanEngine([sys.executable, "-u", "-c", code], timeout)


class ValidationTests(unittest.TestCase):
    def test_valid_boundary(self) -> None:
        self.assertEqual(validate_request({**REQUEST, "a": [-12, 12, 0]}), {**REQUEST, "a": [-12, 12, 0]})

    def test_rejects_inexact_and_out_of_domain_components(self) -> None:
        for bad in ([True, 0, 0], [1.0, 0, 0], [13, 0, 0], [0, 0], "000", None):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_request({**REQUEST, "a": bad})

    def test_rejects_non_scalar_id_and_extra_fields(self) -> None:
        for bad in ({**REQUEST, "id": []}, {**REQUEST, "id": float("inf")}, {**REQUEST, "operation": "shell"}, []):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_request(bad)


class EngineTests(unittest.TestCase):
    def test_persistent_process(self) -> None:
        engine = fake_engine()
        self.addCleanup(engine.close)
        self.assertEqual(engine.evaluate(REQUEST)["counter"], 1)
        self.assertEqual(engine.evaluate(REQUEST)["counter"], 2)

    def test_concurrent_requests_keep_responses_with_their_callers(self) -> None:
        engine = fake_engine()
        self.addCleanup(engine.close)
        with ThreadPoolExecutor(max_workers=4) as pool:
            responses = list(pool.map(lambda i: engine.evaluate({**REQUEST, "id": i}), range(12)))
        self.assertEqual([result["id"] for result in responses], list(range(12)))
        self.assertEqual(sorted(result["counter"] for result in responses), list(range(1, 13)))

    def test_missing_executable(self) -> None:
        engine = LeanEngine(["/no/exterior-room-executable"])
        self.addCleanup(engine.close)
        with self.assertRaises(BridgeError) as caught:
            engine.evaluate(REQUEST)
        self.assertEqual(caught.exception.status, 503)

    def test_timeout_and_successful_restart(self) -> None:
        code = """
import json,sys,time
for line in sys.stdin:
    r=json.loads(line)
    if r['id']==7: time.sleep(30)
    print(json.dumps({'ok':True,'id':r['id']}),flush=True)
"""
        engine = fake_engine(code, .15)
        self.addCleanup(engine.close)
        before = time.monotonic()
        with self.assertRaises(BridgeError) as caught:
            engine.evaluate(REQUEST)
        self.assertEqual(caught.exception.status, 504)
        self.assertLess(time.monotonic() - before, 2)
        self.assertTrue(engine.evaluate({**REQUEST, "id": 8})["ok"])

    def test_input_timeout_covers_child_not_reading(self) -> None:
        engine = fake_engine("import time; time.sleep(30)", .15)
        self.addCleanup(engine.close)
        before = time.monotonic()
        with self.assertRaises(BridgeError) as caught:
            engine.evaluate({**REQUEST, "id": "a" * 60_000})
        self.assertEqual(caught.exception.status, 504)
        self.assertLess(time.monotonic() - before, 2)

    def test_broken_or_mismatched_protocol(self) -> None:
        for code in ("print('not json',flush=True)", "print('{}',flush=True)", "print('{\"ok\":true,\"id\":999}',flush=True)", "pass"):
            engine = fake_engine(code)
            try:
                with self.subTest(code=code), self.assertRaises(BridgeError) as caught:
                    engine.evaluate(REQUEST)
                self.assertEqual(caught.exception.status, 502)
            finally:
                engine.close()


class HTTPTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        Path(self.directory.name, "index.html").write_text("Exterior Room test")
        self.server = ExteriorServer(("127.0.0.1", 0), fake_engine(), Path(self.directory.name))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server)

    def stop_server(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(2)

    def request(self, path: str = "/api/evaluate", body: str | None = None, headers: dict[str, str] | None = None, method: str = "POST") -> tuple[int, bytes, dict[str, str]]:
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        try:
            request_headers = {"Content-Type": "application/json", **(headers or {})}
            connection.request(method, path, body if body is not None else json.dumps(REQUEST), headers=request_headers)
            response = connection.getresponse()
            return response.status, response.read(), dict(response.getheaders())
        finally:
            connection.close()

    def test_real_http_roundtrip_and_same_origin(self) -> None:
        origin = f"http://127.0.0.1:{self.server.server_port}"
        status, body, headers = self.request(headers={"Origin": origin})
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["id"], 7)
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_cross_origin_and_rebinding_hosts_rejected(self) -> None:
        for headers in ({"Origin": "https://evil.example"}, {"Host": f"evil.example:{self.server.server_port}"}, {"Origin": "null"}):
            with self.subTest(headers=headers):
                self.assertEqual(self.request(headers=headers)[0], 403)

    def test_malformed_json_and_nonfinite_number_rejected(self) -> None:
        for body in ("no", "{", "[]", json.dumps({**REQUEST, "a": [False, 0, 0]}), json.dumps(REQUEST).replace('"id": 7', '"id": 1e400')):
            with self.subTest(body=body):
                self.assertEqual(self.request(body=body)[0], 400)

    def test_request_size_type_and_route(self) -> None:
        self.assertEqual(self.request(body="a" * 65_537)[0], 413)
        self.assertEqual(self.request(headers={"Content-Type": "text/plain"})[0], 415)
        self.assertEqual(self.request(path="/api/unknown")[0], 404)

    def test_health_and_static(self) -> None:
        status, body, _ = self.request(path="/api/health", method="GET")
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(body)["engineAvailable"])
        self.assertEqual(len(json.loads(body)["engineSha256"]), 64)
        status, body, _ = self.request(path="/", method="GET")
        self.assertEqual((status, body), (200, b"Exterior Room test"))

    def test_no_algebra_fallback_when_lean_unavailable(self) -> None:
        self.server.engine.close()
        self.server.engine = LeanEngine(["/missing/exterior"])
        status, body, _ = self.request()
        self.assertEqual(status, 503)
        self.assertFalse(json.loads(body)["ok"])
        self.assertNotIn("wedge", json.loads(body))


@unittest.skipUnless(DEFAULT_ENGINE.is_file(), "Build the actual Lean executable to run integration checks.")
class RealLeanTests(unittest.TestCase):
    def test_exact_integer_wedge_volume_swap_and_degeneracy(self) -> None:
        engine = LeanEngine([str(DEFAULT_ENGINE)])
        self.addCleanup(engine.close)
        result = engine.evaluate(REQUEST)
        self.assertEqual(result["wedge"], [48, 0, 0])
        self.assertEqual(result["volume"], 240)
        self.assertTrue(all(result["checks"].values()))
        swapped = engine.evaluate({**REQUEST, "a": REQUEST["b"], "b": REQUEST["a"]})
        self.assertEqual(swapped["volume"], -240)
        collapsed = engine.evaluate({**REQUEST, "c": REQUEST["a"]})
        self.assertEqual(collapsed["volume"], 0)
        self.assertEqual(len(result["vertices"]), 8)


if __name__ == "__main__":
    unittest.main()
