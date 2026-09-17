"""Minimal stdio MCP echo server for a local Codex Desktop smoke test.

It uses only the Python standard library, writes JSON-RPC responses to stdout,
and never makes a network request. It is intentionally not a production MCP
server.
"""

from __future__ import annotations

import json
import sys
from typing import Any


def send(message: dict[str, Any]) -> None:
    """Write one JSON-RPC message using the MCP newline-delimited transport."""
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def result(request_id: Any, value: dict[str, Any]) -> None:
    """Send a successful JSON-RPC response."""
    send({"jsonrpc": "2.0", "id": request_id, "result": value})


def error(request_id: Any, code: int, message: str) -> None:
    """Send a JSON-RPC error response."""
    send({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})


def handle(request: dict[str, Any]) -> None:
    """Handle the small MCP method subset required by the smoke test."""
    method = request.get("method")
    request_id = request.get("id")
    if request_id is None and method == "notifications/initialized":
        return
    if request_id is None:
        return
    if method == "initialize":
        result(
            request_id,
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "glm-smoke-echo", "version": "1.0.0"},
            },
        )
    elif method == "tools/list":
        result(
            request_id,
            {
                "tools": [
                    {
                        "name": "glm_smoke_echo",
                        "description": "Return a deterministic local smoke-test value.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {"message": {"type": "string"}},
                            "required": ["message"],
                        },
                    }
                ]
            },
        )
    elif method == "tools/call":
        arguments = request.get("params", {}).get("arguments", {})
        message = str(arguments.get("message", "hello"))
        result(request_id, {"content": [{"type": "text", "text": "MCP_OK:" + message}]})
    else:
        error(request_id, -32601, "Method not implemented: " + str(method))


def main() -> None:
    """Read newline-delimited JSON-RPC messages until the client closes stdin."""
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
            if isinstance(request, dict):
                handle(request)
            else:
                error(None, -32600, "Request must be an object")
        except json.JSONDecodeError as exc:
            print("invalid JSON: " + str(exc), file=sys.stderr)
            error(None, -32700, "Parse error")


if __name__ == "__main__":
    main()
