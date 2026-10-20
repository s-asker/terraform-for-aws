# ECS dummy app

Dependency-free Python HTTP app. `GET /` returns `APP_MESSAGE`, the container
runtime ID from ECS metadata, and the hostname. `GET /health` returns HTTP 200
with `{"status":"ok"}`. Other paths return HTTP 404.

```sh
docker build -t ecs-dummy ./dummy-app
docker run --rm -p 8080:8080 -e APP_MESSAGE="Hello from my container" ecs-dummy
curl http://localhost:8080/
curl http://localhost:8080/health
```

On local Docker, the runtime ID is `null`; the hostname is returned separately.
On ECS, the app reads `DockerId` from `ECS_CONTAINER_METADATA_URI_V4`.
See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint-v4-response.html.

The image runs as non-root user `10001` and listens on unprivileged port `8080`.
The ECS port mapping, service, task security group, and ALB target group use
port `8080`; the public ALB listeners remain on ports `80` and `443`.

To deploy, rebuild and push the image to the ECR repository used by
`files/container-definition.json.tftpl`, then apply Terraform to update the ECS
service and backend ports. The template uses the `latest` image tag and injects
`APP_MESSAGE` from Secrets Manager.

Use a non-secret message: the root endpoint intentionally displays its value.
