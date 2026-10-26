"""Poll one job at a time; acknowledge only after its result is in S3."""
import json
import logging
import os
import signal
import threading
from uuid import UUID

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from validation import validate_numbers

LOG = logging.getLogger(__name__)


def process_message(message, sqs, s3, queue_url, bucket, prefix):
    job = json.loads(message["Body"])
    if not isinstance(job, dict) or job.get("version") != 1:
        raise ValueError("unsupported job format")
    job_id = str(UUID(job["job_id"]))
    numbers = validate_numbers(job.get("numbers"))
    result = {
        "job_id": job_id, "count": len(numbers), "sum": sum(numbers),
        "min": min(numbers), "max": max(numbers),
        "mean": sum(numbers) / len(numbers),
    }
    key = f"{prefix}{job_id}.json"
    # Deterministic key/content makes redelivery safe for this simple job.
    # This is not exactly-once processing (versioned buckets may retain versions).
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(result, sort_keys=True).encode(), ContentType="application/json")
    sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=message["ReceiptHandle"])
    LOG.info("job_completed job_id=%s key=%s", job_id, key)


def main():
    logging.basicConfig(level=logging.INFO)
    queue_url = os.environ["SQS_QUEUE_URL"]
    bucket = os.environ["RESULTS_BUCKET"]
    prefix = os.getenv("RESULTS_PREFIX", "results/").strip("/")
    prefix = prefix + "/" if prefix else ""
    visibility = int(os.getenv("VISIBILITY_TIMEOUT", "120"))
    if not 30 <= visibility <= 43200:
        raise ValueError("VISIBILITY_TIMEOUT must be between 30 and 43200 seconds")
    region = os.environ["AWS_REGION"]
    config = Config(connect_timeout=5, read_timeout=25, retries={"mode": "standard", "total_max_attempts": 3})
    sqs = boto3.client("sqs", region_name=region, config=config)
    s3 = boto3.client("s3", region_name=region, config=config)
    stopping = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stopping.set())
    LOG.info("worker_started")
    while not stopping.is_set():
        try:
            response = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1, WaitTimeSeconds=20, VisibilityTimeout=visibility)
            for message in response.get("Messages", []):
                if stopping.is_set():
                    sqs.change_message_visibility(QueueUrl=queue_url, ReceiptHandle=message["ReceiptHandle"], VisibilityTimeout=0)
                    break
                try:
                    process_message(message, sqs, s3, queue_url, bucket, prefix)
                except (ValueError, KeyError, TypeError, OverflowError, BotoCoreError, ClientError):
                    # Leave failed messages on the queue for retry / configured DLQ.
                    LOG.exception("job_failed message_id=%s", message.get("MessageId"))
        except (BotoCoreError, ClientError):
            LOG.exception("queue_poll_failed")
            stopping.wait(5)
    LOG.info("worker_stopped")


if __name__ == "__main__":
    main()
