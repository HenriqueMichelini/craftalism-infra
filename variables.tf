variable "aws_region" {
  description = "AWS region where the EC2 host will run."
  type        = string
}

variable "create_vpc" {
  description = "Whether Terraform should create the VPC, internet gateway, public subnet, and route table for the host."
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project tag prefix."
  type        = string
  default     = "craftalism"
}

variable "environment" {
  description = "Environment name used for tagging."
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "Existing VPC ID for the Craftalism host. Required only when create_vpc is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.vpc_id != null
    error_message = "vpc_id must be set when create_vpc is false."
  }
}

variable "subnet_id" {
  description = "Existing subnet ID where the EC2 host will be created. Required only when create_vpc is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.subnet_id != null
    error_message = "subnet_id must be set when create_vpc is false."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC Terraform creates."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet Terraform creates."
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the single-node Craftalism host."
  type        = string
}

variable "ami_id" {
  description = "Optional explicit AMI ID. If null, the latest Ubuntu 24.04 LTS AMI is used."
  type        = string
  default     = null
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access."
  type        = string
  default     = null
}

variable "associate_eip" {
  description = "Whether to allocate and attach an Elastic IP for stable public addressing."
  type        = bool
  default     = true
}

variable "create_route53_records" {
  description = "Whether to create Route53 A records for dashboard, API, and auth hostnames."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID. Required only when create_route53_records is true."
  type        = string
  default     = null

  validation {
    condition     = !var.create_route53_records || var.route53_zone_id != null
    error_message = "route53_zone_id must be set when create_route53_records is true."
  }
}

variable "dashboard_hostname" {
  description = "Public HTTPS hostname for the Craftalism dashboard. Use any placeholder until you buy a domain."
  type        = string
}

variable "api_hostname" {
  description = "Public HTTPS hostname for the Craftalism API. Use any placeholder until you buy a domain."
  type        = string
}

variable "auth_hostname" {
  description = "Public HTTPS hostname for the Craftalism authorization server. Use any placeholder until you buy a domain."
  type        = string
}

variable "dashboard_basic_auth_username" {
  description = "Basic-auth username used by the edge proxy to protect the dashboard."
  type        = string
}

variable "dashboard_basic_auth_password_hash" {
  description = "Bcrypt password hash for dashboard basic auth."
  type        = string

  validation {
    condition     = can(regex("^\\$2[aby]\\$", var.dashboard_basic_auth_password_hash))
    error_message = "dashboard_basic_auth_password_hash must be a bcrypt hash."
  }
}

variable "http_allowed_cidrs" {
  description = "CIDR ranges allowed to reach HTTP/HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "minecraft_allowed_cidrs" {
  description = "CIDR ranges allowed to reach the public Minecraft port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_allowed_cidrs" {
  description = "Optional restricted CIDR ranges for SSH. Leave empty to keep SSH closed at the security-group layer."
  type        = list(string)
  default     = []
}

variable "dashboard_upstream_port" {
  description = "Local host port used by the dashboard container."
  type        = number
  default     = 8080
}

variable "api_upstream_port" {
  description = "Local host port used by the API container."
  type        = number
  default     = 3000
}

variable "auth_upstream_port" {
  description = "Local host port used by the auth container."
  type        = number
  default     = 9000
}

variable "edge_proxy_image" {
  description = "Container image used for the Caddy edge proxy. Pin a digest in production if desired."
  type        = string
  default     = "caddy:2.10.0-alpine"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size_gb >= 20
    error_message = "root_volume_size_gb must be at least 20 GiB for the single-node stack."
  }
}

variable "operator_username" {
  description = "Primary Linux user expected to operate Docker on the instance."
  type        = string
  default     = "ubuntu"
}

variable "budget_alert_email" {
  description = "Email address that should receive monthly AWS budget alerts. Leave null to skip budget creation."
  type        = string
  default     = null
}

variable "monthly_budget_limit_usd" {
  description = "Monthly AWS budget limit, in USD, used when budget_alert_email is set."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Additional AWS tags applied to all managed resources."
  type        = map(string)
  default     = {}
}
