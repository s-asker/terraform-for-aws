data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

######################## IAM TASK ROLE ####################

resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs_task_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json # (not shown)
}

data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "ecs_task_policy"
  description = "ECS Fargate Task Role Policy"
  policy      = data.aws_iam_policy_document.ecs_task_policy.json
}


resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attach" {
  role       = aws_iam_role.ecs_task_role.id
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

######################## IAM TASK EXECUTION ROLE ####################


resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json # (not shown)
}

data "aws_iam_policy_document" "ecs_task_execution_policy" {
  statement {
    effect = "Allow"
    actions = ["logs:CreateLogStream",
      "logs:PutLogEvents",
    "logs:CreateLogGroup"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app_secret.arn]
  }
  statement {
    effect = "Allow"
    actions = ["ecr:DescribeImages",
      "ecr:DescribeRegistry",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer"]
    resources = [aws_ecr_repository.ecr.arn]
  }

  statement {
    effect = "Allow"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name        = "ecs_task_execution_policy"
  description = "ECS Fargate Task Role Policy"
  policy      = data.aws_iam_policy_document.ecs_task_execution_policy.json
}


resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.id
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}