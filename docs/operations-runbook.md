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

## Syncing The Production Edge

Use the repo-owned sync script on the EC2 host when the live Caddy edge has
drifted from the intended dashboard, API, and auth routes. Provide the values
through the environment so credentials are not committed or passed as command
arguments:

```bash
export EDGE_DASHBOARD_HOSTNAME='dashboard.craftalism.com'
export EDGE_API_HOSTNAME='api.craftalism.com'
export EDGE_AUTH_HOSTNAME='auth.craftalism.com'
export EDGE_DASHBOARD_BASIC_AUTH_USERNAME='craftalism'
export EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH='<bcrypt-hash>'

sudo --preserve-env=EDGE_DASHBOARD_HOSTNAME,EDGE_API_HOSTNAME,EDGE_AUTH_HOSTNAME,EDGE_DASHBOARD_BASIC_AUTH_USERNAME,EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH \
  ./scripts/sync_edge_config.sh
```

The script validates the candidate configuration inside the existing Caddy
container, installs it atomically, recreates `craftalism-edge` from the
infra-owned `/opt/craftalism/edge/docker-compose.yml`, and verifies that an
unauthenticated dashboard request returns HTTP 401 with a `WWW-Authenticate`
header. It does not replace the EC2 instance or change application containers.

Recreating from the infra-owned Compose file also recovers from the optional
standalone edge in `craftalism-deployment` displacing the normal production
edge. Do not run both edge profiles on the same host.

Then verify authenticated access with the plaintext password held by the
operator:

```bash
curl -I -u 'craftalism:<password>' https://dashboard.craftalism.com/
```

Expected result: authenticated access reaches the dashboard upstream and does
not return HTTP 401.

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
