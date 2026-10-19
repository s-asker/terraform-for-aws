# ECS dummy app

Dependency-free Python HTTP app. `GET /` returns `APP_MESSAGE`, the container
runtime ID from ECS metadata, and the hostname. `GET /health` returns HTTP 200
with `{"status":"ok"}`. Other paths return HTTP 404.

```sh
docker build -t ecs-dummy ./dummy-app
docker run --rm -p 8080:80 -e APP_MESSAGE="Hello from my container" ecs-dummy
curl http://localhost:8080/
curl http://localhost:8080/health
```

On local Docker, the runtime ID is `null`; the hostname is returned separately.
On ECS, the app reads `DockerId` from `ECS_CONTAINER_METADATA_URI_V4`.
See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint-v4-response.html.

To deploy, push the image to your registry, replace `nginx:latest` in
`files/container-definition.json.tftpl` with its image URI, and add this property
to that container definition:

```json
"environment": [{"name": "APP_MESSAGE", "value": "Hello from ECS"}]
```

Keep the existing container name and port 80 mapping. Set the ALB target group's
health check path to `/health`. The health endpoint checks that the HTTP process
is responding; it does not depend on metadata availability.

Use a non-secret message: the root endpoint intentionally displays its value.
