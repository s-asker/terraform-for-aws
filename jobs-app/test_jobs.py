import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import Mock

import importlib.util
from pathlib import Path
import sys


def load_app(name):
    directory = Path(__file__).parent / name
    sys.path.insert(0, str(directory))
    try:
        # Each service owns its validation module and builds independently.
        sys.modules.pop("validation", None)
        spec = importlib.util.spec_from_file_location(f"{name}_app", directory / "app.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.pop(0)


make_handler = load_app("api").make_handler
process_message = load_app("worker").process_message


class JobsTests(unittest.TestCase):
    def test_api_worker_roundtrip_and_redelivery(self):
        sqs, s3 = Mock(), Mock()
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(sqs, "queue-url"))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            request = Request(f"http://127.0.0.1:{server.server_port}/jobs",
                              data=b'{"numbers":[10,20,30,40]}',
                              headers={"Content-Type": "application/json"})
            with urlopen(request) as response:
                self.assertEqual(response.status, 202)
                accepted = json.load(response)
            message = {"Body": sqs.send_message.call_args.kwargs["MessageBody"], "ReceiptHandle": "receipt"}
            calls = Mock()
            calls.attach_mock(s3.put_object, "upload")
            calls.attach_mock(sqs.delete_message, "delete")
            process_message(message, sqs, s3, "queue-url", "bucket", "results/")
            first_upload = s3.put_object.call_args
            self.assertEqual([c[0] for c in calls.mock_calls], ["upload", "delete"])
            result = json.loads(first_upload.kwargs["Body"])
            self.assertEqual(result, {"job_id": accepted["job_id"], "count": 4,
                                     "sum": 100, "min": 10, "max": 40, "mean": 25.0})
            process_message(message, sqs, s3, "queue-url", "bucket", "results/")
            self.assertEqual(s3.put_object.call_args, first_upload)
            request = Request(f"http://127.0.0.1:{server.server_port}/jobs", data=b'{"numbers":[true]}')
            with self.assertRaises(HTTPError) as error:
                urlopen(request)
            self.assertEqual(error.exception.code, 400)
            error.exception.close()
            self.assertEqual(sqs.send_message.call_count, 1)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_upload_failure_does_not_acknowledge(self):
        sqs, s3 = Mock(), Mock()
        s3.put_object.side_effect = RuntimeError("simulated interruption")
        message = {"Body": json.dumps({"version": 1, "job_id": "00000000-0000-0000-0000-000000000001", "numbers": [1]}), "ReceiptHandle": "receipt"}
        with self.assertRaises(RuntimeError):
            process_message(message, sqs, s3, "queue", "bucket", "results/")
        sqs.delete_message.assert_not_called()

    def test_malformed_job_does_not_upload_or_acknowledge(self):
        sqs, s3 = Mock(), Mock()
        with self.assertRaises(ValueError):
            process_message({"Body": '{"version":99}'}, sqs, s3, "queue", "bucket", "results/")
        s3.put_object.assert_not_called()
        sqs.delete_message.assert_not_called()


if __name__ == "__main__":
    unittest.main()
