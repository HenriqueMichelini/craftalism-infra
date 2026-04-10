# Craftalism Infra Portfolio Backlog

Date: 2026-04-10

## Purpose

This backlog focuses on making `craftalism-infra` a stronger example of
pragmatic, low-cost AWS provisioning and operational discipline.

Source:

- [portfolio-evolution-roadmap.md](/home/henriquemichelini/IdeaProjects/craftalism/docs/portfolio-evolution-roadmap.md)
- [repo-requirement-pack.md](/home/henriquemichelini/IdeaProjects/craftalism-infra/docs/repo-requirement-pack.md)

## Now

### High priority

- Add CI validation for `terraform fmt -check`, `terraform validate`, and a
  basic static policy check for ingress exposure assumptions.
- Make remote-state setup the documented default for repeatable environments.
- Add stronger bootstrap validation guidance for DNS, certificates, host edge,
  and first-instance bring-up.
- Add a recovery runbook for failed bootstrap, bad DNS, and incorrect public
  ingress assumptions.

### Medium priority

- Add clearer operator guidance for EC2 instance sizing, disk sizing, and
  practical free-tier boundaries.
- Add explicit notes about what remains protected by security groups versus what
  is protected by the edge proxy.

## Next

### High priority

- Add documented key-rotation, certificate-troubleshooting, and host-maintenance
  procedures.
- Add EBS snapshot backup and restore guidance aligned with the single-host
  operating model.
- Add a minimal host-hardening checklist covering updates, operator access, log
  retention, and firewall stance.

### Medium priority

- Add cost documentation that explains expected monthly footprint and which
  options increase spend.
- Add policy guidance that makes accidental raw-port exposure harder to
  introduce.

## Later

- Add optional lightweight AWS-native log visibility if it remains aligned with
  the low-cost model.
- Add stronger static policy enforcement if the repo grows in complexity.

## Done When

- The infra repo shows disciplined AWS thinking without overengineering.
- Operators can provision, validate, and recover the host boundary with
  confidence.
- Security exposure decisions are explicit and easy to audit.
