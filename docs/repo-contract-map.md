# Repo Contract Map: craftalism-infra

## Repository Role
`craftalism-infra` is the AWS provisioning layer for Craftalism. It owns cloud resources, public network boundaries, host bootstrap, and edge ingress controls for the single-node deployment model.

## Owned Contracts
- AWS infrastructure shape for the single-node deployment
- Public ingress boundary for EC2-hosted Craftalism
- Instance bootstrap needed to provide Docker and edge TLS termination
- Operator-facing infrastructure documentation for AWS provisioning

## Consumed Contracts
- `auth-issuer`
  - Must preserve the canonical auth issuer hostname and avoid redefining issuer behavior
- `documentation`
  - Must keep infrastructure docs explicit, accurate, and honest about limits
- `testing`
  - Must provide automation for infrastructure validation appropriate to this repo
- `ci-cd`
  - Must run Terraform quality checks on pull request and push
- `security-access-control`
  - Must make public vs private surfaces explicit and enforce the intended exposure boundary
- Runtime assumptions from `craftalism-deployment`
  - Must not break the expected localhost upstream ports used by the current compose stack

## Local-Only Responsibilities
- EC2 instance provisioning
- Security groups and ingress rules
- Elastic IP attachment
- Optional Route53 DNS records
- Cloud-init and edge proxy bootstrap
- Infrastructure variables and outputs

## Out of Scope
- Docker Compose application lifecycle
- Service image versioning or digest pinning
- API, auth-server, dashboard, or plugin business logic
- Shared contract ownership already assigned to other repositories
- Multi-node or managed-service redesigns

## Compliance Questions
- Does this repo preserve the one-EC2 architecture required by Craftalism?
- Does it prevent public exposure of internal service ports and RCON?
- Does it provide a minimal HTTPS edge with explicit dashboard protection?
- Are infrastructure assumptions documented without overstating security guarantees?
- Do Terraform validation checks run automatically?

## Success Signal
This repo is compliant when it provisions a low-cost, single-node AWS host with explicit ingress controls, a working TLS edge, and documentation that cleanly separates infrastructure ownership from runtime composition ownership.
