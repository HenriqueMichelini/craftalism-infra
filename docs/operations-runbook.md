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
terraform validate
terraform plan -out=tfplan
```

3. Review for unexpected changes, especially:
   - VPC or subnet recreation
   - security group ingress
   - instance replacement
   - budget changes
   - DNS record changes
4. Apply only after the plan is understood:

```bash
terraform apply tfplan
```

## Destroy Safety

This repo provisions the public host for the whole stack. Do not run `terraform destroy` casually.

Before any destructive action:

- confirm backups and recovery expectations
- confirm no live Craftalism data depends on the instance
- confirm DNS impact is acceptable

## Host Bootstrap Checks

After the first apply or any instance replacement, verify on the host:

```bash
systemctl status docker
docker ps
docker logs craftalism-edge
sudo cat /opt/craftalism/edge/Caddyfile
```

Expected result:

- Docker is active
- `craftalism-edge` is running
- Caddy is listening on `80` and `443`

## Cost Checks

After the first apply, verify:

- the configured budget exists in AWS Budgets if `budget_alert_email` was set
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
