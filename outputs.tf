output "instance_id" {
  description = "EC2 instance ID for the Craftalism host."
  value       = aws_instance.craftalism.id
}

output "instance_public_ip" {
  description = "Public IP assigned to the Craftalism host."
  value       = local.edge_public_ip
}

output "security_group_id" {
  description = "Security group enforcing the public ingress boundary."
  value       = aws_security_group.craftalism.id
}

output "vpc_id" {
  description = "VPC ID used by the Craftalism host."
  value       = local.selected_vpc_id
}

output "subnet_id" {
  description = "Subnet ID used by the Craftalism host."
  value       = local.selected_subnet_id
}

output "dashboard_url" {
  description = "Dashboard HTTPS URL."
  value       = "https://${var.dashboard_hostname}"
}

output "api_url" {
  description = "API HTTPS URL."
  value       = "https://${var.api_hostname}"
}

output "auth_issuer_url" {
  description = "Auth issuer HTTPS URL to use as the canonical AUTH_ISSUER_URI."
  value       = "https://${var.auth_hostname}"
}

output "budget_name" {
  description = "AWS budget name, if budget alerts were enabled."
  value       = try(aws_budgets_budget.monthly[0].name, null)
}

output "instance_alarm_topic_arn" {
  description = "SNS topic ARN used for EC2 alarm notifications, if email notifications were enabled."
  value       = try(aws_sns_topic.instance_alarms[0].arn, null)
}

output "instance_alarm_names" {
  description = "CloudWatch alarm names created for the Craftalism host."
  value = compact([
    aws_cloudwatch_metric_alarm.instance_status_check_failed.alarm_name,
    aws_cloudwatch_metric_alarm.instance_cpu_high.alarm_name,
    try(aws_cloudwatch_metric_alarm.instance_cpu_credit_low[0].alarm_name, null),
  ])
}
