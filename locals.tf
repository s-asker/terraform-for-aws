locals {
  ecs_task_definition = templatefile(
    "files/container-definition.json.tftpl",
    {
      region         = data.aws_region.current.region
      containerImage = aws_ecr_repository.ecr.repository_url
      secretARN      = aws_secretsmanager_secret.app_secret.arn
    }
  )
}