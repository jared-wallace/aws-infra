variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "jared-wallace.com"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for EC2 instances"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "jw-tf-infra"
}

variable "github_repo" {
  description = "HTTPS URL of the website-go repository"
  type        = string
  default     = "https://github.com/jared-wallace/website-go.git"
}

# --- App secrets (provide via secrets.tfvars or TF_VAR_ env vars) ---

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "website"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "website_prod"
}

variable "admin_email" {
  description = "Admin panel login email"
  type        = string
}

variable "admin_password_hash" {
  description = "Bcrypt hash of the admin password"
  type        = string
  sensitive   = true
}

variable "session_secret" {
  description = "32+ character session cookie secret"
  type        = string
  sensitive   = true
}

variable "api_token" {
  description = "Bearer token for the JSON API"
  type        = string
  sensitive   = true
}
