# Craftalism Infra

Terraform infrastructure for the Craftalism AWS deployment boundary.

This repository provisions the minimum AWS resources required by the 2026-04-08 Craftalism infra audit:

- one low-cost VPC with a single public subnet by default
- one EC2 instance for the full hobby-scale stack
- one security group that exposes only Minecraft and HTTPS entry points
- optional SSH restricted to explicit operator CIDRs
- optional Elastic IP and Route53 records for stable public endpoints
- optional AWS budget alerts for monthly cost guardrails
- host bootstrap for Docker and a Caddy edge proxy with automatic TLS

It does not replace `craftalism-deployment`. Runtime composition, container image versions, and application environment wiring remain owned by that repository.

## Scope

This repo owns:

- AWS host provisioning
- public network boundaries
- edge TLS termination
- dashboard basic-auth protection
- operator-facing bootstrap for the host

This repo does not own:

- Docker Compose application runtime
- service image tags/digests
- application business logic
- cross-repo contract definitions

## Design Constraints

This implementation follows Craftalism governance:

- preserve the existing multi-service architecture
- keep deployment on a single EC2 instance
- stay near-zero-cost and avoid managed-service sprawl
- do not expose Postgres, API, auth, dashboard raw ports, or RCON publicly
- terminate TLS at the instance edge

## Repository Layout

```text
craftalism-infra/
  docs/
  templates/
  .github/workflows/
  main.tf
  variables.tf
  outputs.tf
  versions.tf
  terraform.tfvars.example
```

## Prerequisites

- Terraform 1.6+
- AWS credentials with permission to manage EC2, VPC, EIP, security groups, budgets, and optional Route53 records
- a target AWS region
- placeholder or real hostnames for:
  - dashboard
  - API
  - auth issuer

## Quick Start

1. Copy the example variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Generate a bcrypt password hash for dashboard basic auth:

```bash
docker run --rm caddy:2.10.0-alpine caddy hash-password --plaintext 'replace-me'
```

3. Fill in `terraform.tfvars` with your region, hostnames, budget email, and restricted SSH CIDRs.

4. Decide whether this first apply should create the network:

```hcl
create_vpc = true
```

This is the default and is the right choice for a brand-new AWS account. Only set `create_vpc = false` when you already have a VPC and subnet to target.

5. For repeatable environments, prepare remote state:

```bash
cp backend.hcl.example backend.hcl
# edit backend.hcl with your S3 bucket and DynamoDB lock table
```

6. Apply the infrastructure:

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

For one-off local-state testing, you can still run:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## DNS Model

The edge proxy expects three HTTPS hostnames:

- `dashboard_hostname`
- `api_hostname`
- `auth_hostname`

If `create_route53_records = true`, Terraform creates `A` records in the provided hosted zone. Otherwise, point those hostnames to the instance public IP or Elastic IP outside Terraform.

If you have not bought a domain yet, keep `create_route53_records = false` and treat the hostname inputs as placeholders until DNS is ready.

## Network Exposure

Public ingress is intentionally limited to:

- `25565/tcp` for Minecraft
- `443/tcp` for HTTPS
- `80/tcp` for HTTP to HTTPS redirect
- `22/tcp` only when `ssh_allowed_cidrs` is explicitly set

The security group does not publish:

- PostgreSQL
- API raw port
- auth raw port
- dashboard raw port
- RCON

The bootstrap edge proxy forwards HTTPS traffic to the local ports currently used by `craftalism-deployment`:

- dashboard: `localhost:8080`
- API: `localhost:3000`
- auth: `localhost:9000`

## Network Bootstrap

With `create_vpc = true`, Terraform creates:

- one VPC with CIDR `10.0.0.0/16`
- one public subnet with CIDR `10.0.1.0/24`
- one internet gateway
- one public route table

This avoids NAT Gateway and private subnet cost/complexity during the first account bootstrap.

## Cost Guardrails

If `budget_alert_email` is set, Terraform creates a monthly AWS budget with alerts at:

- 80% of the configured limit
- 100% of the configured limit

This is an alerting mechanism only. AWS Budgets does not hard-stop spending.

## Bootstrap Behavior

Cloud-init installs Docker, writes a Caddy config, and starts an edge proxy container on the EC2 host. The edge proxy:

- redirects HTTP to HTTPS
- terminates TLS automatically
- applies basic auth to the dashboard hostname
- proxies API and auth hostnames without exposing their raw ports publicly

The edge container runs in host network mode so its `localhost` upstreams reach
the loopback-only ports published by `craftalism-deployment` on the EC2 host.

Application containers are still expected to be started separately from `craftalism-deployment`.

## Validation

This repo includes a GitHub Actions workflow that runs:

- `terraform fmt -check`
- `terraform init -backend=false`
- `terraform validate`

Local verification:

```bash
terraform fmt -check
terraform init -backend=false
terraform validate
```

## First Deploy

Before the first real AWS apply, use:

- [docs/first-deploy-checklist.md](/home/henriquemichelini/IdeaProjects/craftalism-infra/docs/first-deploy-checklist.md)
- [docs/operations-runbook.md](/home/henriquemichelini/IdeaProjects/craftalism-infra/docs/operations-runbook.md)

These documents cover:

- remote state preparation
- first-account network bootstrap
- AWS and DNS preflight checks
- first `terraform plan` and `apply`
- post-apply verification
- operational recovery expectations

## Operational Notes

- Restrict `ssh_allowed_cidrs` to your current public IP or VPN CIDR.
- Keep `dashboard_basic_auth_password_hash` out of Git.
- Keep `backend.hcl` and `terraform.tfvars` out of Git.
- Prefer `us-east-1` over `sa-east-1` if the primary goal is minimizing spend rather than latency to Brazil.
- Use persistent RSA keys and the canonical `AUTH_ISSUER_URI` in `craftalism-deployment`; this repo does not redefine those contracts.
- If you do not need SSH, leave `ssh_allowed_cidrs = []` and rely on console/SSM alternatives you configure separately.
