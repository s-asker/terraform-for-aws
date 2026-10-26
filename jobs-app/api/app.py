"""Small training API: accept bounded numeric reports and enqueue them."""
import json
import logging
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from uuid import uuid4

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from validation import validate_numbers

LOG = logging.getLogger(__name__)


def make_handler(sqs, queue_url):
    class Handler(BaseHTTPRequestHandler):
        def respond(self, status, body):
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path == "/health":
                self.respond(200, {"status": "ok"})
            else:
                self.respond(404, {"error": "not found"})

        def do_POST(self):
            if self.path != "/jobs":
                self.respond(404, {"error": "not found"})
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 1 <= length <= 65536:
                    raise ValueError("Content-Length must be between 1 and 65536")
                if self.headers.get("Transfer-Encoding"):
                    raise ValueError("chunked requests are not supported")
                payload = json.loads(self.rfile.read(length))
                if not isinstance(payload, dict):
                    raise ValueError("body must be a JSON object")
                numbers = validate_numbers(payload.get("numbers"))
            except (ValueError, OverflowError) as error:
                self.respond(400, {"error": str(error)})
                return
            job_id = str(uuid4())
            try:
                sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps({
                    "version": 1, "job_id": job_id, "numbers": numbers,
                }))
            except (BotoCoreError, ClientError):
                LOG.exception("enqueue_failed job_id=%s", job_id)
                self.respond(503, {"error": "queue unavailable"})
                return
            LOG.info("job_accepted job_id=%s", job_id)
            self.respond(202, {"job_id": job_id, "status": "queued"})
    return Handler


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    queue_url = os.environ["SQS_QUEUE_URL"]
    client = boto3.client("sqs", region_name=os.environ["AWS_REGION"])
    server = ThreadingHTTPServer(("0.0.0.0", int(os.getenv("PORT", "8080"))), make_handler(client, queue_url))
    server.serve_forever()
