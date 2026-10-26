# SQS report jobs lab

Two standalone apps for separate ECS Fargate services. The API accepts numbers;
the worker writes a JSON summary to a private S3 bucket. No database is needed.
Each directory (`api/` and `worker/`) is a self-contained Docker build context
with its own app, validation, requirements, and Dockerfile. Validation is duplicated
to keep deployments independent; both implement the same version 1 message contract.
Existing Terraform and the dummy app are unchanged; provisioning and ECS wiring
are separate steps. Use a **standard SQS queue**, with a redrive policy to a DLQ
(suggested lab maxReceiveCount: 5). The worker does not create these resources.

## Environment variables

| Variable | API | Worker | Meaning |
| --- | --- | --- | --- |
| `AWS_REGION` | Required | Required | E.g. `eu-north-1` |
| `SQS_QUEUE_URL` | Required | Required | Full URL of the same source queue, not its ARN |
| `RESULTS_BUCKET` | Unused | Required | Bucket name, without `s3://` |
| `PORT` | Default `8080` | Unused | API listening port |
| `RESULTS_PREFIX` | Unused | Default `results/` | Output key prefix; slashes normalized |
| `VISIBILITY_TIMEOUT` | Unused | Default `120` | Per-receive timeout in seconds, 30–43200 |

Use ECS **task roles** for credentials; no access-key environment variables are
needed in ECS. For local Python runs, use your usual AWS profile/credential chain.
Local Docker can mount a credentials directory read-only; host SSO profiles may
also need their cached login. Never bake credentials into either image.

## Build and run

Run these commands from the repository root:

```sh
docker build -t jobs-api jobs-app/api
docker build -t jobs-worker jobs-app/worker
```

For a local Python run, install dependencies in a virtual environment:

```sh
python3 -m venv /tmp/jobs-venv
/tmp/jobs-venv/bin/pip install -r jobs-app/api/requirements.txt
/tmp/jobs-venv/bin/pip install -r jobs-app/worker/requirements.txt
export AWS_REGION=eu-north-1
export SQS_QUEUE_URL='https://sqs.eu-north-1.amazonaws.com/<account-id>/<queue-name>'
export RESULTS_BUCKET='<your-results-bucket>'
/tmp/jobs-venv/bin/python jobs-app/api/app.py
# In another terminal, export the same variables and run:
/tmp/jobs-venv/bin/python jobs-app/worker/app.py
```

Submit and inspect a report:

```sh
curl -i http://localhost:8080/health
curl -i http://localhost:8080/jobs \
  -H 'Content-Type: application/json' \
  -d '{"numbers":[10,20,30,40]}'
# Response: HTTP 202 with {"job_id":"<uuid>","status":"queued"}
aws s3 cp "s3://$RESULTS_BUCKET/results/<job-id>.json" -
```

Expected report fields: `job_id`, `count: 4`, `sum: 100`, `min: 10`,
`max: 40`, `mean: 25.0`. Until processing completes, the object will not exist.
There is no status API or public bucket access. `/health` checks the HTTP process,
not downstream AWS availability. The API has no authentication: use disposable,
non-sensitive lab data and restrict ALB ingress to your IP while practicing.

## Permissions and private networking

- API task role: `sqs:SendMessage` on the source queue.
- Worker task role: `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and
  `sqs:ChangeMessageVisibility` on the source queue; `s3:PutObject` on
  `arn:aws:s3:::<bucket>/results/*` (match a custom prefix if used).
- Task execution roles still handle ECR pulls and CloudWatch logs.
- With the current no-NAT VPC, add an SQS interface endpoint with private DNS and
  allow task HTTPS traffic to it. The existing S3 gateway endpoint must remain
  associated with the worker subnet route table. Endpoint/bucket/queue policies
  must also permit access. Customer-managed KMS keys require additional key
  permissions if you choose to use them.
- Only the API attaches to the ALB, port 8080, health check `/health`. Workers
  require no listening port or ALB. Set ECS worker `stopTimeout` to 120 seconds
  to give an in-flight short job time to finish on termination.

## Failure behavior and boundaries

The worker long-polls one message at a time. It uploads before deleting the
message. Failures leave it available for retry after visibility expires;
persistent errors go to the DLQ only if you configured the redrive policy.
Repeated delivery writes the same deterministic key and content. This is safe
for this report job, not an exactly-once execution guarantee. Versioned S3
buckets can retain multiple versions. Repeated API submissions create new job
IDs; client retry idempotency is not implemented. An ambiguous send failure can
also mean a message was accepted even when the API returns 503.

SIGTERM stops polling and allows the current job to finish, within ECS's stop
timeout. There is no visibility heartbeat: the bounded report is short, but slow
AWS retries can exceed visibility and cause concurrent attempts. Longer jobs
need periodic `ChangeMessageVisibility` and a cancellation strategy.

Exercise: submit jobs, stop a worker, and inspect results, logs, queue age, and
the DLQ. Send a malformed message directly to SQS to verify DLQ routing.
This uses billable AWS resources. After the lab, stop the services and delete
disposable queues, report objects/bucket, and the added endpoint when no longer
needed (including object versions if bucket versioning is enabled).

SDK references: [send_message](https://docs.aws.amazon.com/boto3/latest/reference/services/sqs/client/send_message.html),
[receive_message](https://docs.aws.amazon.com/boto3/latest/reference/services/sqs/client/receive_message.html),
[put_object](https://docs.aws.amazon.com/boto3/latest/reference/services/s3/client/put_object.html).
