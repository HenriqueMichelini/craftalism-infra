# CARD-001: Restore Dashboard Edge Auth

## Status

implemented

## Objective

Add a controlled runtime sync path that restores dashboard basic auth on the existing production edge without replacing the EC2 instance.

## Context

The production dashboard currently returns HTTP 200 without an authentication challenge. The bootstrap Caddy template already defines dashboard basic auth, but cloud-init is first-boot configuration and this repository has no runtime edge sync mechanism for the existing stateful host.

## Required Reading

- `../../docs/repo-contract-map.md`
- `../../docs/repo-requirement-pack.md`
- `../../docs/operations-runbook.md`
- `../../templates/cloud-init.yaml.tftpl`

## Expected Behavior

Operators can render, validate, atomically install, and reload the repo-owned Caddy edge configuration on an existing host. After sync, unauthenticated dashboard requests return HTTP 401 with a `WWW-Authenticate` header, while authenticated requests continue to proxy to the existing dashboard upstream.

## Acceptance Criteria

- [x] A repo-owned script renders the dashboard, API, and auth edge routes from explicit inputs.
- [x] The rendered dashboard route applies basic auth before proxying to `127.0.0.1:8080` by default.
- [x] The script validates the candidate Caddy configuration before installing it.
- [x] The script installs the configuration atomically and recreates the infra-owned edge container.
- [x] The script verifies unauthenticated dashboard access returns HTTP 401 with a `WWW-Authenticate` header.
- [x] Operator documentation describes the controlled production edge sync and authenticated follow-up check.

## Expected Files to Change

```text
scripts/sync_edge_config.sh
scripts/check_edge_config.sh
docs/operations-runbook.md
.github/workflows/terraform.yml
docs/cards/CARD-001-restore-dashboard-edge-auth.md
```

## Constraints

- Do not replace or recreate the EC2 instance.
- Do not change `craftalism-deployment` runtime composition.
- Do not change the standalone edge profile.
- Keep credentials and password hashes out of version control and process arguments where practical.

## Validation Commands

```bash
bash -n scripts/sync_edge_config.sh scripts/check_edge_config.sh
./scripts/check_edge_config.sh
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
curl -sS -D - -o /dev/null https://dashboard.craftalism.com/
```

Production execution requires explicit edge inputs and privileged host access. If host access is unavailable, validate the script and generated Caddy configuration locally and report production verification as blocked.

## Out of Scope

- Application-level dashboard authentication.
- Changes in `craftalism-deployment`.
- EC2 replacement or cloud-init replay.
- Credential rotation.

## Completion Notes

Added a controlled runtime edge sync script, a CI policy check covering both
bootstrap and runtime-rendered dashboard routes, and operator instructions. The
sync also reclaims the production edge if the deployment repository's optional
standalone edge displaced it.

Production verification on 2026-06-05 confirmed the public dashboard returns
HTTP 401 with a Basic challenge, the live edge mounts
`/opt/craftalism/edge/Caddyfile`, and the loopback dashboard upstream returns
HTTP 200.
