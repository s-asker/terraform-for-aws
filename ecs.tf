resource "aws_ecs_cluster" "ecs_cluster" {
  name = "demo-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_capacity_provider" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}


resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "ecs-task-def"
  container_definitions    = local.ecs_task_definition
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

}


resource "aws_ecs_service" "ecs_service" {
  name            = "nginx-svc"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 1


  load_balancer {
    target_group_arn = aws_lb_target_group.ip_target_group.arn
    container_name   = "web-container"
    container_port   = 80
  }

  force_new_deployment = true

  triggers = {
    redeployment = plantimestamp()
  }
  # lifecycle {
  #   ignore_changes = [capacity_provider_strategy]
  # }


  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_allow_http.id]
    subnets          = [for subnet in aws_subnet.private_subnet : subnet.id]

  }
}

resource "aws_security_group" "ecs_allow_http" {
  name        = "ecs_allow_http"
  description = "Allow HTTP inbound traffic and all outbound raffic"
  vpc_id      = aws_vpc.vpc_main.id

  tags = {
    Name = "ecs_allow_http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_allow_http" {
  security_group_id            = aws_security_group.ecs_allow_http.id
  referenced_security_group_id = aws_security_group.lb_allow_http.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "ecs_allow_all_traffic" {
  security_group_id = aws_security_group.ecs_allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}