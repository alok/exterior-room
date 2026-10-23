#!/usr/bin/env python3
"""Local HTTP/JSON transport for the compiled Exterior Room Lean executable.

This module does not implement exterior algebra. Every successful evaluation
comes from the Lean child process. Run with --host 0.0.0.0 only when intentionally
making the bridge available to a headset on a trusted local network.
"""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import math
import os
from pathlib import Path
import selectors
import socket
import subprocess
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Callable, Sequence
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
MAX_REQUEST = 65_536
MAX_RESPONSE = 65_536
DEFAULT_ENGINE = ROOT / "lean/.lake/build/bin/wedge_service"
DEFAULT_POLYNOMIAL_ENGINE = ROOT / "lean/.lake/build/bin/polynomial_service"
POLYNOMIAL_MAX_RESPONSE = 2 * 1024 * 1024
POLYNOMIAL_CLOUD_TIMEOUT = 10.0
POLYNOMIAL_IDENTITY_BOUND = 1024
POLYNOMIAL_NORMAL_BOUND = 4 * POLYNOMIAL_IDENTITY_BOUND ** 2


class BridgeError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status


def reject_constant(value: str) -> None:
    raise ValueError(f"Non-finite JSON number: {value}")


def validate_request(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError("Request must be a JSON object.")
    if any(key not in {"id", "a", "b", "c"} for key in value):
        raise ValueError("Only id, a, b and c fields are accepted.")
    request_id = value.get("id")
    if not isinstance(request_id, (str, int, float, bool, type(None))):
        raise ValueError("id must be a JSON scalar.")
    if isinstance(request_id, float) and not math.isfinite(request_id):
        raise ValueError("id must be finite.")
    for name in ("a", "b", "c"):
        vector = value.get(name)
        if not isinstance(vector, list) or len(vector) != 3:
            raise ValueError(f"{name} must contain exactly three integers.")
        if any(type(component) is not int or not -12 <= component <= 12 for component in vector):
            raise ValueError(f"{name} components must be integers from -12 to 12.")
    return value


def validate_polynomial_request(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError("Request must be a JSON object.")
    request_id = value.get("id")
    if not isinstance(request_id, (str, int, float, bool, type(None))) or (
        isinstance(request_id, float) and not math.isfinite(request_id)
    ):
        raise ValueError("id must be a finite JSON scalar.")
    fields = {
        "cloud": {"radius", "upperOnly", "offset", "limit", "normal"},
        "members": {"radius", "upperOnly", "normal"},
        "inspect": {"point", "height"}, "pair": {"first", "second"}, "plane": {"normal"},
        "transform": {"point", "matrix"},
    }
    operation = value.get("op")
    if not isinstance(operation, str) or operation not in fields:
        raise ValueError("op must be cloud, members, inspect, pair, plane or transform.")
    if any(key not in fields[operation] | {"id", "op"} for key in value):
        raise ValueError(f"Unexpected field for {operation}.")

    def integer(name: str, minimum: int, maximum: int, default: int | None = None) -> None:
        item = value.get(name, default)
        if type(item) is not int or not minimum <= item <= maximum:
            raise ValueError(f"{name} must be an integer from {minimum} to {maximum}.")

    def triple(name: str, bound: int) -> None:
        item = value.get(name)
        if not isinstance(item, list) or len(item) != 3 or any(
            type(component) is not int or not -bound <= component <= bound for component in item
        ):
            raise ValueError(f"{name} must contain three integers from {-bound} to {bound}.")

    if operation in {"cloud", "members"}:
        integer("radius", 4, 96)
        if operation == "cloud":
            integer("limit", 1, 16384, 16384)
            integer("offset", 0, 2_000_000, 0)
        if type(value.get("upperOnly", False)) is not bool:
            raise ValueError("upperOnly must be a boolean.")
        if "normal" in value or operation == "members":
            triple("normal", POLYNOMIAL_NORMAL_BOUND)
    elif operation == "inspect":
        triple("point", POLYNOMIAL_IDENTITY_BOUND)
        integer("height", 1, 24, 4)
    elif operation == "pair":
        triple("first", POLYNOMIAL_IDENTITY_BOUND)
        triple("second", POLYNOMIAL_IDENTITY_BOUND)
    elif operation == "transform":
        triple("point", POLYNOMIAL_IDENTITY_BOUND)
        if not any(value["point"]):
            raise ValueError("The zero polynomial has no transform point.")
        matrix = value.get("matrix")
        if not isinstance(matrix, list) or len(matrix) != 4 or any(
            type(component) is not int or not -1_000_000 <= component <= 1_000_000 for component in matrix
        ):
            raise ValueError("matrix must contain four integers from -1000000 to 1000000.")
        if matrix[0] * matrix[3] - matrix[1] * matrix[2] <= 0:
            raise ValueError("matrix must have a positive determinant.")
    else:
        triple("normal", POLYNOMIAL_NORMAL_BOUND)
    return value


def decode_request(body: bytes, validator: Callable[[Any], dict[str, Any]] = validate_request) -> dict[str, Any]:
    try:
        return validator(json.loads(body, parse_constant=reject_constant))
    except RecursionError as error:
        raise ValueError("JSON nesting is too deep.") from error


class LeanEngine:
    """Serialize requests through a persistent executable; restart after failure."""

    def __init__(self, command: Sequence[str], timeout: float = 3.0, max_response: int = MAX_RESPONSE) -> None:
        self.command = list(command)
        self.timeout = timeout
        self.max_response = max_response
        self._lock = threading.Lock()
        self._process: subprocess.Popen[bytes] | None = None
        self._pending = bytearray()
        self._signature: tuple[int, int, int] | None = None

    @property
    def executable(self) -> Path:
        return Path(self.command[0])

    def available(self) -> bool:
        return self.executable.is_file() and os.access(self.executable, os.X_OK)

    def _stop(self) -> None:
        process, self._process = self._process, None
        self._pending.clear()
        self._signature = None
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=2)
            if process.stdin is not None:
                process.stdin.close()
            if process.stdout is not None:
                process.stdout.close()

    def close(self) -> None:
        with self._lock:
            self._stop()

    def _start(self) -> subprocess.Popen[bytes]:
        try:
            stat = self.executable.stat()
            signature = (stat.st_ino, stat.st_size, stat.st_mtime_ns)
        except OSError:
            signature = None
        if self._process is not None and self._process.poll() is None and signature == self._signature:
            return self._process
        self._stop()
        if not self.available():
            raise BridgeError(503, "Lean executable is unavailable. Build it with scripts/run.sh.")
        try:
            self._process = subprocess.Popen(
                self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, cwd=ROOT, bufsize=0,
            )
            assert self._process.stdin is not None
            os.set_blocking(self._process.stdin.fileno(), False)
            self._signature = signature
        except OSError as error:
            raise BridgeError(503, "Lean executable could not be started.") from error
        return self._process

    def evaluate(self, request: dict[str, Any], timeout: float | None = None) -> dict[str, Any]:
        request_timeout = self.timeout if timeout is None else timeout
        deadline = time.monotonic() + request_timeout
        if not self._lock.acquire(timeout=request_timeout):
            raise BridgeError(504, "Lean request queue timed out; try again.")
        try:
            process = self._start()
            assert process.stdin is not None and process.stdout is not None
            message = json.dumps(request, separators=(",", ":"), allow_nan=False).encode() + b"\n"
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdin, selectors.EVENT_WRITE)
                written = 0
                while written < len(message):
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not selector.select(remaining):
                        raise BridgeError(504, "Lean input timed out; retry will start a fresh process.")
                    try:
                        written += os.write(process.stdin.fileno(), message[written:])
                    except BlockingIOError:
                        continue
                selector.unregister(process.stdin)
                selector.register(process.stdout, selectors.EVENT_READ)
                while b"\n" not in self._pending:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not selector.select(remaining):
                        raise BridgeError(504, "Lean computation timed out; retry will start a fresh process.")
                    chunk = os.read(process.stdout.fileno(), 8192)
                    if not chunk:
                        raise BridgeError(502, "Lean process exited without a result.")
                    self._pending.extend(chunk)
                    if len(self._pending) > self.max_response:
                        raise BridgeError(502, "Lean response exceeded the transport limit.")
            line, _, rest = self._pending.partition(b"\n")
            self._pending = bytearray(rest)
            response = json.loads(line, parse_constant=reject_constant)
            if not isinstance(response, dict) or type(response.get("ok")) is not bool:
                raise BridgeError(502, "Lean returned an invalid protocol response.")
            if response.get("id") != request.get("id"):
                raise BridgeError(502, "Lean response id did not match the request.")
            return response
        except BridgeError:
            self._stop()
            raise
        except (OSError, ValueError, UnicodeError, RecursionError) as error:
            self._stop()
            raise BridgeError(502, "The Lean transport failed; retry will start a fresh process.") from error
        finally:
            self._lock.release()


class ExteriorServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    # A cold browser import graph can open more than the stdlib's five queued
    # connections before the serving thread accepts them.
    request_queue_size = 64

    def __init__(self, address: tuple[str, int], engine: LeanEngine, web_root: Path = ROOT / "web",
                 polynomial_engine: LeanEngine | None = None) -> None:
        self.engine = engine
        self.polynomial_engine = polynomial_engine or LeanEngine(
            [str(DEFAULT_POLYNOMIAL_ENGINE)], max_response=POLYNOMIAL_MAX_RESPONSE,
        )
        self.web_root = web_root
        self.lan_enabled = address[0] not in {"127.0.0.1", "localhost", "::1"}
        super().__init__(address, ExteriorHandler)

    def server_close(self) -> None:
        super().server_close()
        self.engine.close()
        self.polynomial_engine.close()


class ExteriorHandler(SimpleHTTPRequestHandler):
    server: ExteriorServer

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, directory=str(args[2].web_root), **kwargs)

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(5)

    def end_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _json(self, status: int, data: dict[str, Any]) -> None:
        body = json.dumps(data, separators=(",", ":"), allow_nan=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _trusted_request(self) -> bool:
        host = self.headers.get("Host", "")
        try:
            parsed = urlsplit("http://" + host)
            if parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment:
                raise ValueError("Invalid Host")
            hostname = parsed.hostname or ""
            valid_host = hostname in {"127.0.0.1", "localhost", "::1"}
            if self.server.lan_enabled and not valid_host:
                address = ipaddress.ip_address(hostname)
                valid_host = address.is_private and not address.is_unspecified
            if not valid_host or (parsed.port or 80) != self.server.server_port:
                raise ValueError("Untrusted Host")
            origin = self.headers.get("Origin")
            if origin is not None and origin != f"http://{host}":
                raise ValueError("Cross-origin access")
        except ValueError:
            self._json(403, {"ok": False, "error": "Only same-origin local bridge requests are allowed."})
            return False
        return True

    def do_GET(self) -> None:
        if not self._trusted_request():
            return
        path = urlsplit(self.path).path
        if path == "/api/health":
            engine = self.server.engine
            polynomial = self.server.polynomial_engine

            def digest(executable: LeanEngine) -> str | None:
                try:
                    if not executable.available():
                        return None
                    result = hashlib.sha256()
                    with executable.executable.open("rb") as stream:
                        while chunk := stream.read(1024 * 1024):
                            result.update(chunk)
                    return result.hexdigest()
                except OSError:
                    return None

            self._json(200, {
                "ok": True, "engineAvailable": engine.available(),
                "engineSha256": digest(engine), "engine": "compiled Lean executable",
                "hashScope": "executable on disk; next evaluation restarts after a binary change",
                "protocol": "exterior-room/1", "maxRequestBytes": MAX_REQUEST,
                "componentBounds": [-12, 12], "scale": 4,
                "polynomialEngineAvailable": polynomial.available(),
                "polynomialEngineSha256": digest(polynomial),
                "polynomialMaxResponseBytes": POLYNOMIAL_MAX_RESPONSE,
            })
        elif path == "/api/provenance":
            documents = {}
            for name in ("SPEC.md", "docs/lean-provenance.md", "docs/native.md", "NOTICE.md", "lean/Polynomial/PROTOCOL.md"):
                document = ROOT / name
                if document.is_file():
                    documents[name] = document.read_text()
            self._json(200, {"ok": True, "documents": documents})
        elif path.startswith("/api/"):
            self._json(404, {"ok": False, "error": "Unknown API route."})
        else:
            super().do_GET()

    def do_HEAD(self) -> None:
        if self._trusted_request():
            super().do_HEAD()

    def do_POST(self) -> None:
        if not self._trusted_request():
            return
        path = urlsplit(self.path).path
        if path not in {"/api/evaluate", "/api/polynomial"}:
            self._json(404, {"ok": False, "error": "Unknown API route."})
            return
        if self.headers.get("Transfer-Encoding"):
            self._json(400, {"ok": False, "error": "Chunked requests are not supported."})
            return
        try:
            size = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            size = -1
        if size < 0:
            self._json(411, {"ok": False, "error": "Content-Length is required."})
            return
        if size > MAX_REQUEST:
            self._json(413, {"ok": False, "error": "Request exceeds 64 KiB."})
            return
        if self.headers.get_content_type() != "application/json":
            self._json(415, {"ok": False, "error": "Use application/json."})
            return
        try:
            body = self.rfile.read(size)
            if len(body) != size:
                raise ValueError("Incomplete request body.")
            request = decode_request(body, validate_polynomial_request if path == "/api/polynomial" else validate_request)
        except (ValueError, UnicodeError) as error:
            self._json(400, {"ok": False, "error": str(error)})
            return
        except socket.timeout:
            self._json(408, {"ok": False, "error": "Request body timed out."})
            return
        try:
            if path == "/api/polynomial":
                timeout = max(POLYNOMIAL_CLOUD_TIMEOUT, self.server.polynomial_engine.timeout) if request["op"] in {"cloud", "members"} else None
                response = self.server.polynomial_engine.evaluate(request, timeout=timeout)
            else:
                response = self.server.engine.evaluate(request)
            self._json(200 if response["ok"] else 400, response)
        except BridgeError as error:
            self._json(error.status, {"ok": False, "id": request.get("id"), "error": str(error)})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1", help="Default loopback; 0.0.0.0 intentionally exposes the bridge to your LAN.")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--engine", type=Path, default=DEFAULT_ENGINE)
    parser.add_argument("--polynomial-engine", type=Path, default=DEFAULT_POLYNOMIAL_ENGINE)
    parser.add_argument("--timeout", type=float, default=3.0)
    args = parser.parse_args()
    if args.port == 8778:
        parser.error("Port 8778 is reserved for the existing FareyVision app.")
    engine = LeanEngine([str(args.engine.resolve())], args.timeout)
    polynomial = LeanEngine([str(args.polynomial_engine.resolve())], args.timeout, POLYNOMIAL_MAX_RESPONSE)
    with ExteriorServer((args.host, args.port), engine, polynomial_engine=polynomial) as server:
        print(f"Exterior Room: http://{args.host}:{server.server_port}", flush=True)
        print(f"Lean executable: {'ready' if engine.available() else 'missing — run scripts/run.sh to build'}", flush=True)
        print(f"Polynomial executable: {'ready' if polynomial.available() else 'missing — run scripts/run.sh to build'}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
