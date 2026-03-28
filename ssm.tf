resource "aws_ssm_parameter" "db_user" {
  name  = "/website/db_user"
  type  = "String"
  value = var.db_user

  tags = { Name = "website-db-user" }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/website/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = { Name = "website-db-password" }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/website/db_name"
  type  = "String"
  value = var.db_name

  tags = { Name = "website-db-name" }
}

resource "aws_ssm_parameter" "admin_email" {
  name  = "/website/admin_email"
  type  = "String"
  value = var.admin_email

  tags = { Name = "website-admin-email" }
}

resource "aws_ssm_parameter" "admin_password_hash" {
  name  = "/website/admin_password_hash"
  type  = "SecureString"
  value = var.admin_password_hash

  tags = { Name = "website-admin-password-hash" }
}

resource "aws_ssm_parameter" "session_secret" {
  name  = "/website/session_secret"
  type  = "SecureString"
  value = var.session_secret

  tags = { Name = "website-session-secret" }
}

resource "aws_ssm_parameter" "api_token" {
  name  = "/website/api_token"
  type  = "SecureString"
  value = var.api_token

  tags = { Name = "website-api-token" }
}
