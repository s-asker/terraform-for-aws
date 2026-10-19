resource "aws_secretsmanager_secret" "app_secret" {
  name = "application-sm"
  tags = {
    Environment = "Production"
  }
}
