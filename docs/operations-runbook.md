# Operations Runbook

This runbook covers the minimum operator flow for the `craftalism-infra` repository.

## Bootstrap Sequence For A New AWS Account

1. Start with local state and `create_vpc = true`.
2. Apply once to create the network, security boundary, instance, and optional budget.
3. Create the remote-state S3 bucket and DynamoDB lock table.
4. Migrate Terraform to remote state before the next meaningful change.

## Normal Terraform Workflow

Local state:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Remote state:

```bash
cp backend.hcl.example backend.hcl
# edit backend.hcl
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

## Updating Infrastructure

1. Update Terraform inputs or configuration.
2. Run:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan -out=tfplan
./scripts/check_instance_safety.sh tfplan
```

3. Review for unexpected changes, especially:
   - VPC or subnet recreation
   - security group ingress
   - instance replacement
   - `-/+`, `forces replacement`, or `destroy` on `aws_instance.craftalism`
   - monitoring or alarm threshold changes
   - budget changes
   - DNS record changes
4. Apply only after the saved plan is understood:

```bash
terraform apply tfplan
```

Changing `ssh_allowed_cidrs` should only affect security group ingress. It must
not update or replace `aws_instance.craftalism`.

`user_data` is first-boot bootstrap, not runtime configuration management.
Changing cloud-init input variables is not a safe way to deploy application or
host runtime changes on this stateful VPS. Use deploy scripts, SSH/SSM, Ansible,
CI/CD, Docker Compose updates, or another controlled deployment process instead
of replacing the EC2 instance.

## Destroy Safety

This repo provisions the public host for the whole stack. Do not run `terraform destroy` casually.

`aws_instance.craftalism` is protected with Terraform `prevent_destroy`, EC2 API
termination protection, and root EBS `delete_on_termination = false`. Treat any
plan that tries to delete or replace it as an incident until proven intentional.

Before any destructive action:

- confirm backups and recovery expectations
- confirm no live Craftalism data depends on the instance
- confirm DNS impact is acceptable

## Host Bootstrap Checks

After the first apply or any instance replacement, verify on the host:

```bash
systemctl status docker
swapon --show
sysctl vm.swappiness
docker ps
docker logs craftalism-edge
sudo cat /opt/craftalism/edge/Caddyfile
sudo cat /etc/docker/daemon.json
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
```

Expected result:

- Docker is active
- swap is enabled when `swap_size_mb > 0`
- `vm.swappiness` matches the configured Terraform input
- `craftalism-edge` is running
- Caddy is listening on `80` and `443`
- CloudWatch Agent is running when `enable_host_metrics = true`

## Cost Checks

After the first apply, verify:

- the configured budget exists in AWS Budgets if `budget_alert_email` was set
- the EC2 CloudWatch alarms exist
- host memory, swap, and root-disk alarms exist when `enable_host_metrics = true`
- the SNS email subscription was confirmed if `alarm_notification_email` was set
- no NAT Gateway was created
- only the intended Elastic IP exists
- the EC2 instance type is still within your planned spend envelope

## Runtime Handoff Checks

After `craftalism-deployment` starts the application stack, verify:

```bash
curl -I http://dashboard.example.com
curl -I https://dashboard.example.com
curl -I https://api.example.com
curl -I https://auth.example.com
```

Expected result:

- HTTP redirects to HTTPS
- dashboard requires basic auth
- API and auth are reachable through HTTPS

## Recovery Model

This deployment is intentionally single-node and non-HA.

Recovery options are:

- restart the instance
- replace the instance from Terraform
- restore the runtime stack using `craftalism-deployment`
- restore persistent application data from the runtime-side backup process

This repo does not implement a full backup system for application data.
