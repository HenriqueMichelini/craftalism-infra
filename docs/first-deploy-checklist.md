# First Deploy Checklist

Use this checklist before the first real `terraform plan` and first EC2 deployment.

## 1. AWS Inputs

- Confirm the target AWS account and region are correct.
- Select an explicit `ami_id` for deterministic production deployments.
- Only use `allow_automatic_ami_selection = true` for disposable environments where automatic refresh is acceptable.
- Decide whether Terraform will create the network:
  - `create_vpc = true` for a new AWS account
  - `create_vpc = false` only if you already have a VPC and subnet
- If `create_vpc = false`, confirm the selected VPC and subnet already exist.
- If `create_vpc = false` and `associate_eip = false`, confirm the selected subnet auto-assigns public IPv4 addresses.
- Confirm the subnet has outbound internet access for:
  - Ubuntu package installation
  - Docker image pulls
  - ACME/TLS certificate issuance
- Confirm the subnet is intended for a public EC2 instance.
- Confirm you have permission to manage:
  - EC2 instances
  - VPCs, subnets, internet gateways, and route tables if `create_vpc = true`
  - security groups
  - Elastic IPs
  - Budgets if cost alerts are enabled
  - Route53 records if enabled

## 2. DNS and Hostnames

- Decide the public hostnames for:
  - dashboard
  - API
  - auth issuer
- If no domain exists yet:
  - leave `create_route53_records = false`
  - use placeholder hostnames until DNS is ready
- If using Route53 from Terraform:
  - create or identify the hosted zone
  - set `create_route53_records = true`
  - set `route53_zone_id`
- If managing DNS outside Terraform:
  - leave `create_route53_records = false`
  - plan to point all three hostnames to the instance public IP or Elastic IP after apply

## 3. Security Decisions

- Restrict `ssh_allowed_cidrs` to your current public IP or VPN CIDR.
- Leave `ssh_allowed_cidrs = []` if SSH should remain closed.
- Confirm that only these internet-facing ports are intended:
  - `25565`
  - `80`
  - `443`
- Confirm RCON will not be exposed publicly.
- Generate a bcrypt hash for dashboard basic auth and store it only in local secret material.

## 4. Terraform State

- Decide whether this first deploy will use:
  - local state for a one-off test, or
  - remote S3 state with DynamoDB locking for repeatable operations
- For shared or repeated use, prefer remote state.
- Recommended bootstrap order for a brand-new AWS account:
  - first apply with local state
  - create the remote-state bucket and lock table manually
  - migrate to remote state before the next meaningful change
- If using remote state:
  - copy `backend.hcl.example` to `backend.hcl`
  - update the bucket, key, region, and DynamoDB table values
  - ensure the bucket and lock table already exist before `terraform init`

## 5. Cost Guardrails

- Set `budget_alert_email` to a mailbox you actively read.
- Set `monthly_budget_limit_usd` to a low number such as `5`.
- Remember AWS Budgets sends alerts only; it does not block charges.
- Treat this budget as total AWS cost alerting for the deployment boundary, not just EC2 compute.
- If account-level AWS budget controls already exist outside this repo, prefer leaving `budget_alert_email = null` to avoid duplicate budget ownership.
- Avoid surprise-cost services during first deploy:
  - NAT Gateway
  - load balancers
  - extra Elastic IPs
  - large EBS volumes
  - managed databases
  - EKS

## 5a. Small-Host Memory Guardrails

- Do not use `t3.micro` for the full Craftalism stack.
- Prefer `t3.small` only for low-concurrency hobby use with swap enabled.
- Prefer `t3.medium` if Minecraft, API, auth, dashboard, and Postgres will share the same host under regular use.
- Keep `swap_size_mb` enabled on small instances unless you have measured evidence it is hurting more than helping.
- Keep Docker log rotation enabled so noisy containers do not accumulate oversized local logs.

## 6. Runtime Handoff to craftalism-deployment

- Confirm the runtime stack will expose these host-local ports on the EC2 instance:
  - dashboard: `8080`
  - API: `3000`
  - auth: `9000`
- Confirm `AUTH_ISSUER_URI` will match `https://<auth_hostname>`.
- Confirm persistent RSA keys, DB password, and client secret are prepared outside this repo.
- Confirm `craftalism-deployment` will keep raw ports private at the host/network level.

## 7. Local Files

- Copy `terraform.tfvars.example` to `terraform.tfvars`.
- Fill in all required values.
- Keep `terraform.tfvars` and `backend.hcl` out of Git.

## 8. First Real Plan

For local state:

```bash
terraform init
terraform plan -out=tfplan
```

For remote state:

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
```

Review the plan and confirm it includes:

- one VPC and one public subnet when `create_vpc = true`
- one EC2 instance
- one security group
- zero public raw app-port rules
- optional Elastic IP
- optional AWS budget
- optional Route53 records only if requested

## 9. First Apply

```bash
terraform apply tfplan
```

After apply, record:

- VPC ID
- subnet ID
- instance ID
- public IP or Elastic IP
- dashboard URL
- API URL
- auth issuer URL

## 10. Post-Apply Verification

- Verify the security group only allows the expected public ports.
- Verify `http://<hostname>` redirects to HTTPS.
- Verify dashboard HTTPS prompts for basic auth.
- Verify API and auth HTTPS routes respond through the edge proxy.
- SSH only if explicitly enabled.
- Confirm the host bootstrapped Docker and started the Caddy container successfully.

## 11. Before Calling It Release-Ready

- `terraform fmt -check -recursive` passes.
- `terraform validate` passes.
- A real `terraform plan` has been reviewed.
- A real apply has succeeded in the intended AWS environment.
- Post-apply checks have passed.
- `craftalism-deployment` has been exercised behind the provisioned hostnames.
