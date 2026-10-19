output "repo_url" {
  description = "The URL of the artifact repo"
  value       = aws_ecr_repository.ecr.repository_url
}

output "secret_arn" {
  description = "ARN of the secret created for ECS"
  value       = aws_secretsmanager_secret.app_secret.arn
}