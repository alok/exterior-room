"""Transport tests use small protocol fakes; exact algebra tests use real Lean."""
from __future__ import annotations

import http.client
from concurrent.futures import ThreadPoolExecutor
import json
import io
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import (  # noqa: E402
    BridgeError, DEFAULT_ENGINE, DEFAULT_POLYNOMIAL_ENGINE, ExteriorHandler, ExteriorServer,
    LeanEngine, POLYNOMIAL_MAX_RESPONSE, decode_request, validate_request, validate_polynomial_request,
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

    def test_deep_json_within_size_limit_is_a_normal_validation_error(self) -> None:
        body = b"[" * 10000 + b"0" + b"]" * 10000
        self.assertLess(len(body), 65_536)
        with self.assertRaisesRegex(ValueError, "nesting is too deep"):
            decode_request(body)


class PolynomialValidationTests(unittest.TestCase):
    def test_all_operations_and_boundary_values(self) -> None:
        requests = [
            {"op": "cloud", "radius": 4},
            {"op": "cloud", "radius": 96, "upperOnly": True, "offset": 2_000_000, "limit": 16384, "normal": [-1_000_000, 1_000_000, 0]},
            {"op": "members", "radius": 96, "normal": [1, 0, 0]},
            {"op": "inspect", "point": [-96, 96, 0], "height": 24},
            {"op": "pair", "first": [0, 0, 0], "second": [-96, 96, 0]},
            {"op": "plane", "normal": [-1_000_000, 1_000_000, 0]},
            {"op": "transform", "matrix": [1_000_000, -1_000_000, 1_000_000, 1_000_000], "point": [-96, 96, 96]},
            {"op": "inspect", "point": [1024, -1024, 1024]},
            {"op": "pair", "first": [13, -84, 162], "second": [1, -8, 17]},
            {"op": "members", "radius": 96, "normal": [257617, 1052910, 150135]},
            {"op": "catalogue", "depth": 6, "matrix": [1, 4, 0, 1]},
            {"op": "catalogue", "depth": 96, "matrix": [1, 0, 0, 1], "whole": False, "dust": True, "offset": 2_000_000, "limit": 16384},
            {"op": "membersCatalogue", "depth": 4, "matrix": [3, 1, 1, 2], "normal": [-1, 0, 1]},
        ]
        for request in requests:
            with self.subTest(request=request):
                self.assertEqual(validate_polynomial_request(request), request)

    def test_rejects_unknown_fields_and_out_of_bounds_parameters(self) -> None:
        requests = [
            {"op": "cloud", "radius": radius} for radius in [3, 97, True, 4.0, None]
        ] + [
            {"op": "cloud", "radius": 4, **change} for change in [
                {"upperOnly": 1}, {"offset": -1}, {"offset": 2_000_001}, {"limit": 0}, {"limit": 16385}, {"normal": [1, 2]}, {"a": [1, 2, 3]},
            ]
        ] + [
            {"op": "members", "radius": 4},
            {"op": "inspect", "point": [1025, 0, 0]},
            {"op": "inspect", "point": [1, 0, 0], "height": 0},
            {"op": "inspect", "point": [1, 0, 0], "height": 25},
            {"op": "plane", "normal": [4_194_305, 0, 0]},
            {"op": "pair", "first": [1, 0, 0]},
            {"op": "inspect", "point": [True, 0, 0]},
            *({"op": "transform", "matrix": matrix, "point": [1, 0, 1]} for matrix in [
                [1, 0, 0, 0], [1, 0, 0, -1], [1_000_001, 0, 0, 1], [1, True, 0, 1],
                [1.0, 0, 0, 1], [1, 0, 1], None,
            ]),
            {"op": "transform", "matrix": [1, 0, 0, 1], "point": [0, 0, 0]},
            {"op": "transform", "matrix": [1, 0, 0, 1], "point": [1025, 0, 1]},
            {"op": "transform", "matrix": [1, 0, 0, 1], "point": [1, 0, 1], "fallback": True},
            *({"op": "catalogue", "depth": 6, "matrix": [1, 0, 0, 1], **change} for change in [
                {"depth": 3}, {"depth": 97}, {"depth": True}, {"whole": 1}, {"dust": "false"},
                {"offset": -1}, {"limit": 0}, {"limit": 16385}, {"radius": 6}, {"matrix": [1, 0, 0, 0]},
            ]),
            {"op": "membersCatalogue", "depth": 6, "matrix": [1, 0, 0, 1]},
            {"op": "membersCatalogue", "depth": 6, "matrix": [1, 0, 0, 1], "normal": [1, 0, -1], "offset": 0},
            {"op": "unknown"}, {"op": []}, [],
        ]
        for request in requests:
            with self.subTest(request=request), self.assertRaises(ValueError):
                validate_polynomial_request(request)


class MemorySocket:
    """Exercise the real HTTP handler without opening an OS socket."""

    def __init__(self, request: bytes) -> None:
        self.input = io.BytesIO(request)
        self.output = bytearray()

    def makefile(self, *_args: object) -> io.BytesIO:
        return self.input

    def settimeout(self, _timeout: float) -> None:
        pass

    def sendall(self, data: bytes) -> None:
        self.output.extend(data)


class QuietHandler(ExteriorHandler):
    def log_message(self, _format: str, *args: object) -> None:
        pass


class InProcessHTTPTests(unittest.TestCase):
    def setUp(self) -> None:
        self.wedge = fake_engine()
        self.polynomial = fake_engine(ECHO.replace("'counter':counter", "'route':'polynomial','counter':counter"))
        self.polynomial.max_response = POLYNOMIAL_MAX_RESPONSE
        self.addCleanup(self.wedge.close)
        self.addCleanup(self.polynomial.close)
        self.server = SimpleNamespace(web_root=Path(__file__).parents[1] / "web", server_port=8787,
                                      lan_enabled=False, engine=self.wedge, polynomial_engine=self.polynomial)

    def request(self, path: str, body: object) -> tuple[int, dict[str, object]]:
        encoded = body if isinstance(body, bytes) else json.dumps(body).encode()
        request = (f"POST {path} HTTP/1.0\r\nHost: 127.0.0.1:8787\r\nContent-Type: application/json\r\nContent-Length: {len(encoded)}\r\n\r\n").encode() + encoded
        connection = MemorySocket(request)
        QuietHandler(connection, ("127.0.0.1", 12345), self.server)
        headers, _, response = bytes(connection.output).partition(b"\r\n\r\n")
        return int(headers.split(b" ")[1]), json.loads(response)

    def test_endpoints_use_separate_persistent_engines(self) -> None:
        status, polynomial = self.request("/api/polynomial", {"id": 7, "op": "inspect", "point": [1, 2, 3]})
        self.assertEqual(status, 200)
        self.assertEqual(polynomial["route"], "polynomial")
        status, wedge = self.request("/api/evaluate", REQUEST)
        self.assertEqual(status, 200)
        self.assertNotIn("route", wedge)
        self.assertEqual(wedge["counter"], 1)
        self.assertEqual(self.request("/api/polynomial", {"id": 8, "op": "plane", "normal": [1, 0, 0]})[1]["counter"], 2)

    def test_invalid_and_deep_requests_are_structured_errors(self) -> None:
        for path, request in [("/api/polynomial", {"op": "cloud", "radius": 97}),
                              ("/api/polynomial", REQUEST), ("/api/evaluate", {"op": "cloud", "radius": 4}),
                              ("/api/evaluate", b"[" * 10000 + b"0" + b"]" * 10000)]:
            with self.subTest(path=path, request_type=type(request).__name__):
                status, response = self.request(path, request)
                self.assertEqual(status, 400)
                self.assertFalse(response["ok"])

    def test_polynomial_missing_does_not_disable_wedge(self) -> None:
        self.server.polynomial_engine = LeanEngine(["/missing/polynomial_service"])
        self.addCleanup(self.server.polynomial_engine.close)
        status, response = self.request("/api/polynomial", {"id": 8, "op": "cloud", "radius": 4})
        self.assertEqual(status, 503)
        self.assertEqual(response["id"], 8)
        self.assertEqual(self.request("/api/evaluate", REQUEST)[0], 200)

    def test_polynomial_large_response_budget_does_not_change_wedge_budget(self) -> None:
        code = """
import json,sys
for line in sys.stdin:
    r=json.loads(line)
    print(json.dumps({'ok':True,'id':r.get('id'),'payload':'x'*100000}),flush=True)
"""
        large = fake_engine(code)
        large.max_response = POLYNOMIAL_MAX_RESPONSE
        self.addCleanup(large.close)
        self.server.polynomial_engine = large
        status, response = self.request("/api/polynomial", {"id": 8, "op": "cloud", "radius": 4})
        self.assertEqual(status, 200)
        self.assertEqual(len(response["payload"]), 100000)
        bounded = fake_engine(code)
        self.addCleanup(bounded.close)
        self.server.engine = bounded
        self.assertEqual(self.request("/api/evaluate", REQUEST)[0], 502)

    @unittest.skipUnless(DEFAULT_POLYNOMIAL_ENGINE.is_file(), "Build polynomial_service for exact HTTP-handler integration.")
    def test_real_polynomial_inspection_pair_cloud_and_domain_recovery(self) -> None:
        engine = LeanEngine([str(DEFAULT_POLYNOMIAL_ENGINE)], max_response=POLYNOMIAL_MAX_RESPONSE)
        self.addCleanup(engine.close)
        self.server.polynomial_engine = engine
        status, point = self.request("/api/polynomial", {"id": 1, "op": "inspect", "point": [1, 0, 1]})
        self.assertEqual(status, 200)
        self.assertEqual(point["schema"], "polynomial-space-v1")
        self.assertEqual(point["delta"], -4)
        self.assertEqual(point["xyz"], [0, 2, 0])
        self.assertEqual(point["root"]["real"], [0, 1])
        self.assertEqual(point["projection"], [[0, 1], [4, 1], [0, 1]])
        status, pair = self.request("/api/polynomial", {"id": 2, "op": "pair", "first": [1, 0, 1], "second": [1, 1, 1]})
        self.assertEqual(status, 200)
        self.assertEqual(pair["normal"], [1, 0, -1])
        self.assertTrue(all(pair["checks"].values()))
        self.assertEqual(sorted((e["numerator"], e["denominator"]) for e in pair["endpoints"]), [(-1, 1), (1, 1)])
        status, cloud = self.request("/api/polynomial", {"id": 3, "op": "cloud", "radius": 4, "limit": 7, "normal": [0, 1, 0]})
        self.assertEqual(status, 200)
        self.assertEqual(cloud["count"], 7)
        self.assertEqual(len(cloud["abc"]), 21)
        self.assertEqual(len(cloud["onPlane"]), 7)
        status, members = self.request("/api/polynomial", {"id": 4, "op": "members", "radius": 4, "normal": [0, 1, 0]})
        self.assertEqual(status, 200)
        self.assertEqual(members["total"], cloud["total"])
        self.assertGreater(members["count"], 0)
        self.assertEqual(len(members["indices"]), members["count"])
        status, catalogue = self.request("/api/polynomial", {"id": 40, "op": "catalogue", "depth": 6, "matrix": [1, 0, 0, 1], "limit": 17})
        self.assertEqual(status, 200)
        self.assertEqual(catalogue["catalogueSchema"], "source-catalogue-v1")
        self.assertEqual((catalogue["total"], catalogue["upperCount"], catalogue["otherCount"]), (212, 187, 25))
        self.assertTrue(catalogue["complete"])
        self.assertEqual(catalogue["nextOffset"], 17)
        status, membership = self.request("/api/polynomial", {"id": 41, "op": "membersCatalogue", "depth": 6, "matrix": [1, 0, 0, 1], "normal": [1, 0, -1]})
        self.assertEqual(status, 200)
        self.assertEqual(membership["cacheKey"], catalogue["cacheKey"])
        self.assertGreater(membership["count"], 0)
        status, refused = self.request("/api/polynomial", {"id": 42, "op": "catalogue", "depth": 6, "matrix": [1, 12, 0, 1]})
        self.assertEqual(status, 400)
        self.assertIn("envelope", refused["error"])
        status, retained = self.request("/api/polynomial", {"id": 43, "op": "catalogue", "depth": 6, "matrix": [1, 0, 0, 1], "offset": 17, "limit": 17})
        self.assertEqual(status, 200)
        self.assertEqual(retained["cacheKey"], catalogue["cacheKey"])
        self.assertEqual(retained["count"], 17)
        self.assertEqual(self.request("/api/polynomial", {"id": 5, "op": "inspect", "point": [0, 0, 0]})[0], 400)
        status, empty = self.request("/api/polynomial", {"id": 6, "op": "cloud", "radius": 4, "offset": 2_000_000})
        self.assertEqual(status, 200)
        self.assertEqual(empty["total"], cloud["total"])
        self.assertEqual(empty["count"], 0)
        self.assertIsNone(empty["nextOffset"])
        status, transformed = self.request("/api/polynomial", {"id": 7, "op": "transform", "matrix": [3, 1, 1, 2], "point": [1, -1, 2]})
        self.assertEqual(status, 200)
        self.assertEqual(transformed["actionSchema"], "polynomial-mobius-v1")
        self.assertEqual(transformed["denominator"], 5)
        self.assertEqual(transformed["coefficientRows"], [4, -2, 1, -4, 7, -6, 1, -3, 9])
        self.assertEqual(transformed["imageNumerator"], [8, -23, 22])
        self.assertEqual(transformed["xyzNumerator"], [23, 30, 14])
        self.assertIsNone(transformed["image"])
        self.assertTrue(transformed["checks"]["discriminantPreserved"])
        status, invalid = self.request("/api/polynomial", {"id": 8, "op": "transform", "matrix": [1, 0, 0, 0], "point": [1, 0, 1]})
        self.assertEqual(status, 400)
        self.assertFalse(invalid["ok"])
        status, recovered = self.request("/api/polynomial", {"id": 9, "op": "transform", "matrix": [1, 1, 0, 1], "point": [1, 0, 1]})
        self.assertEqual(status, 200)
        self.assertEqual(recovered["image"], [1, -2, 2])


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

    def test_deep_protocol_json_is_rejected_and_next_request_recovers(self) -> None:
        code = """
import json,sys
for line in sys.stdin:
    r=json.loads(line)
    if r['id']==7: print('['*10000+'0'+']'*10000,flush=True)
    else: print(json.dumps({'ok':True,'id':r['id']}),flush=True)
"""
        engine = fake_engine(code)
        self.addCleanup(engine.close)
        with self.assertRaises(BridgeError) as caught:
            engine.evaluate(REQUEST)
        self.assertEqual(caught.exception.status, 502)
        self.assertTrue(engine.evaluate({**REQUEST, "id": 8})["ok"])


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
        for body in ("no", "{", "[]", "[" * 10000 + "0" + "]" * 10000, json.dumps({**REQUEST, "a": [False, 0, 0]}), json.dumps(REQUEST).replace('"id": 7', '"id": 1e400')):
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

    def test_cold_module_burst_serves_all_concurrent_requests(self) -> None:
        barrier = threading.Barrier(24)

        def load_module(index: int) -> tuple[int, bytes, dict[str, str]]:
            barrier.wait(timeout=5)
            return self.request(path=f"/?module={index}", method="GET")

        with ThreadPoolExecutor(max_workers=24) as pool:
            responses = list(pool.map(load_module, range(24)))
        for status, body, _headers in responses:
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
