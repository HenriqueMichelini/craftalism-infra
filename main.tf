locals {
  name_prefix                  = "${var.project_name}-${var.environment}"
  selected_ami_id              = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  selected_vpc_id              = var.create_vpc ? aws_vpc.craftalism[0].id : var.vpc_id
  selected_subnet_id           = var.create_vpc ? aws_subnet.public[0].id : var.subnet_id
  instance_family              = split(".", var.instance_type)[0]
  is_burstable_instance_family = startswith(local.instance_family, "t")
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "craftalism-infra"
    },
    var.tags
  )

  edge_public_ip = var.associate_eip ? aws_eip.craftalism[0].public_ip : aws_instance.craftalism.public_ip
  dns_records = toset([
    var.dashboard_hostname,
    var.api_hostname,
    var.auth_hostname,
  ])
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  count       = var.ami_id == null && var.allow_automatic_ami_selection ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnet" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.subnet_id
}

check "existing_network_inputs" {
  assert {
    condition = (
      var.create_vpc ||
      (var.vpc_id != null && var.subnet_id != null)
    )
    error_message = "vpc_id and subnet_id must both be set when create_vpc is false."
  }
}

check "ami_selection_input" {
  assert {
    condition = (
      var.ami_id != null ||
      var.allow_automatic_ami_selection
    )
    error_message = "Set ami_id for deterministic builds, or explicitly enable allow_automatic_ami_selection for non-production use."
  }
}

check "existing_subnet_vpc_match" {
  assert {
    condition = (
      var.create_vpc ||
      data.aws_subnet.existing[0].vpc_id == var.vpc_id
    )
    error_message = "subnet_id must belong to the provided vpc_id when create_vpc is false."
  }
}

check "existing_subnet_public_ip_behavior" {
  assert {
    condition = (
      var.create_vpc ||
      var.associate_eip ||
      data.aws_subnet.existing[0].map_public_ip_on_launch
    )
    error_message = "When create_vpc is false and associate_eip is false, the selected subnet must auto-assign public IPs."
  }
}

check "route53_zone_input" {
  assert {
    condition = (
      !var.create_route53_records ||
      var.route53_zone_id != null
    )
    error_message = "route53_zone_id must be set when create_route53_records is true."
  }
}

resource "aws_vpc" "craftalism" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "craftalism" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.craftalism[0].id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id                  = aws_vpc.craftalism[0].id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-a" })
}

resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.craftalism[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.craftalism[0].id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public" })
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "craftalism" {
  name        = "${local.name_prefix}-sg"
  description = "Craftalism single-node ingress boundary"
  vpc_id      = local.selected_vpc_id

  ingress {
    description = "Minecraft"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = var.minecraft_allowed_cidrs
  }

  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_allowed_cidrs
  }

  ingress {
    description = "HTTPS edge"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.http_allowed_cidrs
  }

  dynamic "ingress" {
    for_each = var.ssh_allowed_cidrs
    content {
      description = "Restricted SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg" })
}

resource "aws_instance" "craftalism" {
  ami                         = local.selected_ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.selected_subnet_id
  vpc_security_group_ids      = [aws_security_group.craftalism.id]
  associate_public_ip_address = !var.associate_eip
  key_name                    = var.key_name
  monitoring                  = var.enable_detailed_monitoring
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    dashboard_hostname                 = var.dashboard_hostname
    api_hostname                       = var.api_hostname
    auth_hostname                      = var.auth_hostname
    dashboard_basic_auth_username      = var.dashboard_basic_auth_username
    dashboard_basic_auth_password_hash = var.dashboard_basic_auth_password_hash
    dashboard_upstream_port            = var.dashboard_upstream_port
    api_upstream_port                  = var.api_upstream_port
    auth_upstream_port                 = var.auth_upstream_port
    edge_proxy_image                   = var.edge_proxy_image
    operator_username                  = var.operator_username
    swap_size_mb                       = var.swap_size_mb
    vm_swappiness                      = var.vm_swappiness
    docker_log_max_size                = var.docker_log_max_size
    docker_log_max_file                = var.docker_log_max_file
  })

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2" })
}

resource "aws_eip" "craftalism" {
  count    = var.associate_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.craftalism.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-eip" })
}

resource "aws_budgets_budget" "monthly" {
  count = var.budget_alert_email == null ? 0 : 1

  name         = "${local.name_prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

resource "aws_sns_topic" "instance_alarms" {
  count = var.alarm_notification_email == null ? 0 : 1

  name = "${local.name_prefix}-instance-alarms"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-instance-alarms" })
}

resource "aws_sns_topic_subscription" "instance_alarms_email" {
  count = var.alarm_notification_email == null ? 0 : 1

  topic_arn = aws_sns_topic.instance_alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

resource "aws_cloudwatch_metric_alarm" "instance_status_check_failed" {
  alarm_name          = "${local.name_prefix}-instance-status-check-failed"
  alarm_description   = "EC2 instance status checks failed for the Craftalism host."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = var.alarm_notification_email == null ? [] : [aws_sns_topic.instance_alarms[0].arn]
  ok_actions          = var.alarm_notification_email == null ? [] : [aws_sns_topic.instance_alarms[0].arn]

  dimensions = {
    InstanceId = aws_instance.craftalism.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-instance-status-check-failed" })
}

resource "aws_cloudwatch_metric_alarm" "instance_cpu_high" {
  alarm_name          = "${local.name_prefix}-instance-cpu-high"
  alarm_description   = "Sustained EC2 CPU utilization is high enough that the single-node Craftalism host may need runtime tuning or a larger instance."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_utilization_alarm_threshold_percent
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_notification_email == null ? [] : [aws_sns_topic.instance_alarms[0].arn]
  ok_actions          = var.alarm_notification_email == null ? [] : [aws_sns_topic.instance_alarms[0].arn]

  dimensions = {
    InstanceId = aws_instance.craftalism.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-instance-cpu-high" })
}

resource "aws_cloudwatch_metric_alarm" "instance_cpu_credit_low" {
  count = local.is_burstable_instance_family ? 1 : 0

  alarm_name          = "${local.name_prefix}-instance-cpu-credit-low"
  alarm_description   = "EC2 burst credits are low for the Craftalism host. Repeated alarms suggest the stack has outgrown its burstable baseline."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Minimum"
  threshold           = var.cpu_credit_balance_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_notification_email == null ? [] : [aws_sns_topic.instance_alarms[0].arn]
  ok_actions          = var.alarm_notification_email == null ? [] : [aws_sns_topic.instance_alarms[0].arn]

  dimensions = {
    InstanceId = aws_instance.craftalism.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-instance-cpu-credit-low" })
}

resource "aws_route53_record" "edge" {
  for_each = var.create_route53_records ? local.dns_records : toset([])

  zone_id = var.route53_zone_id
  name    = each.value
  type    = "A"
  ttl     = 300
  records = [local.edge_public_ip]
}
