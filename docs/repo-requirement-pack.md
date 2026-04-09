# Repo Requirement Pack: craftalism-infra

## Repo Role
`craftalism-infra` is the AWS provisioning layer for the Craftalism ecosystem. It is responsible for creating the single-node cloud footprint, enforcing public exposure boundaries at the infrastructure layer, and bootstrapping the host so `craftalism-deployment` can run behind a TLS edge.

## Owned Contracts
- AWS resource topology for the approved single-node deployment
- Public ingress rules for internet-facing infrastructure
- Host bootstrap for Docker and edge reverse proxy setup
- Infrastructure documentation for operator setup and maintenance

## Consumed Contracts
- `auth-issuer`
  - Preserve the canonical issuer hostname and do not redefine issuer semantics
- `documentation`
  - Keep infrastructure docs synchronized with actual Terraform behavior
- `testing`
  - Provide automated validation suitable for Terraform-owned responsibilities
- `ci-cd`
  - Run quality gates on PR and push
- `security-access-control`
  - Keep exposure policy explicit and aligned with the shared standard
- `craftalism-deployment`
  - Treat application runtime wiring as an external dependency, not local ownership

## Current Phase Objective
This phase is limited to creating a new infrastructure repository that implements the confirmed critical findings from the 2026-04-08 Craftalism infra audit without rearchitecting the system.

## Required This Phase
- Create a Terraform repository for single-host AWS provisioning
- Enforce the intended exposure boundary:
  - public Minecraft port
  - public HTTPS edge
  - optional HTTP redirect
  - optional SSH restricted by CIDR
  - no public raw API/auth/dashboard ports
  - no public RCON
- Bootstrap a reverse proxy that:
  - terminates TLS
  - routes dashboard, API, and auth traffic
  - protects dashboard access with basic auth
- Keep the design aligned with:
  - one EC2 instance
  - Docker Compose runtime ownership in `craftalism-deployment`
  - low-cost, hobby-scale operations
- Add minimum CI validation for Terraform syntax and structure
- Document operator assumptions, limitations, and handoff to `craftalism-deployment`

## Not Required This Phase
- Kubernetes, autoscaling, or multi-node topologies
- RDS, NAT gateways, or load balancers
- Application-level auth redesign
- Runtime compose changes inside other repositories
- Enterprise secret-management platforms as a prerequisite

## Local Requirements
- Reuse an existing VPC/subnet instead of provisioning a broad network platform
- Keep security groups simple and explicit
- Make SSH access opt-in and CIDR-limited
- Use persistent instance storage
- Make reverse-proxy upstream ports configurable but default to the current deployment repo values
- Keep secrets and password hashes out of version control

## Governance Requirements
- Follow shared `documentation`, `testing`, `ci-cd`, and `security-access-control` standards
- Respect the single-node and near-zero-cost constraints from root `AGENTS.md`
- Do not let this repo absorb runtime ownership from `craftalism-deployment`
- Keep documentation explicit about what is protected and what is merely hidden behind the security group

## Out of Scope
- Service business logic
- Shared contract changes
- Compose workflow ownership
- Dashboard feature work
- Auth-server token issuance behavior

## Audit Questions
- Does Terraform provision exactly one EC2 instance for the stack?
- Does the security group implement the approved public surface area?
- Does the host bootstrap provide a sane TLS edge and dashboard protection?
- Are raw application ports and RCON kept off the public internet?
- Are CI and docs sufficient for a new Terraform-owned repo?

## Success Criteria
- A new `craftalism-infra` repository exists with runnable Terraform
- The default design matches the 2026-04-08 audit’s critical findings
- Documentation cleanly explains ownership boundaries and operator steps
- Validation automation is present and passes locally
