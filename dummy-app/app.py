import json
import os
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import urlopen


def container_identity():
    metadata_uri = os.getenv("ECS_CONTAINER_METADATA_URI_V4")
    if metadata_uri:
        try:
            with urlopen(metadata_uri, timeout=2) as response:
                return json.load(response)["DockerId"], "ecs_metadata"
        except (OSError, ValueError, KeyError) as error:
            print(f"Could not read ECS metadata: {error}", file=sys.stderr, flush=True)
    # A hostname is useful locally, but is not guaranteed to be a runtime ID.
    return None, "unavailable"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/health":
            self.respond(200, {"status": "ok"})
        elif path == "/":
            runtime_id, source = container_identity()
            self.respond(200, {
                "APP_MESSAGE": os.getenv("APP_MESSAGE", "Hello from ECS!"),
                "container_runtime_id": runtime_id,
                "runtime_id_source": source,
                "hostname": socket.gethostname(),
            })
        else:
            self.respond(404, {"error": "not found"})

    def respond(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "80"))
    print(f"Listening on port {port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
