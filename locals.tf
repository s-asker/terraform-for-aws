locals {
  ecs_task_definition = templatefile(
    "files/container-definition.json.tftpl",
    {
      region             = data.aws_region.current.region
    }
  )
}