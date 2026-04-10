# AGENTS.md — craftalism-infra

## Purpose
This repository is part of the Craftalism ecosystem and MUST follow all shared contracts, standards, and governance rules defined in the root Craftalism documentation.

This agent (Codex) operates under a strict **audit → implement → re-verify** workflow.

---

## Core Workflow

### 1. Audit (READ-ONLY)
- Analyze the repository against:
  - Craftalism shared contracts
  - Craftalism standards (CI/CD, security, testing, documentation)
  - Industry best practices (infra, DevOps, cloud architecture)
- Identify:
  - Contract violations
  - Performance bottlenecks
  - Reliability risks
  - Security gaps
  - Maintainability issues

🚨 Do NOT implement changes during audit.

---

### 2. Implement
- Apply fixes based on audit findings
- Changes MUST:
  - Follow Craftalism contracts and standards
  - Be production-grade and senior-level quality
  - Preserve system behavior (no breaking changes unless explicitly required)
  - Improve:
    - Performance
    - Reliability
    - Observability
    - Security

- Prefer:
  - Incremental, safe changes
  - Clear structure and modularity
  - Infrastructure-as-Code best practices
  - Deterministic and reproducible environments

---

### 3. Re-verify
- Validate that:
  - All identified issues are resolved
  - No regressions were introduced
  - Contracts are fully respected
  - System behavior remains correct

- Ensure:
  - CI/CD passes
  - Runtime assumptions hold
  - Deployment flow is stable

---

## Non-Negotiable Rules

- Follow **Craftalism governance as the single source of truth**
- Do NOT redefine cross-repo contracts
- Do NOT introduce conflicting patterns
- Do NOT bypass standards for convenience

---

## Quality Bar

All changes MUST reflect **senior-level engineering standards**:

- Clean, readable, maintainable code
- Strong architectural decisions
- Explicit and safe configurations
- Proper error handling and fail-fast behavior
- Secure by default (least privilege, deny-by-default)
- Observability-ready (logs, healthchecks, metrics where applicable)

---

## Performance Requirement

Performance improvements are **mandatory but safe**:

- Optimize without breaking behavior
- Avoid premature optimization
- Focus on:
  - Resource efficiency
  - Startup time
  - Deployment speed
  - Runtime stability

- Any optimization MUST:
  - Be measurable or justifiable
  - Not compromise correctness

---

## Infra-Specific Expectations

- Deterministic environments (no hidden defaults)
- Fail-fast production configuration
- Clear separation of environments (dev/staging/prod)
- Idempotent deployments
- Minimal and secure surface area
- Explicit dependency management

---

## Output Expectations

When acting, the agent MUST:
- Be precise and structured
- Justify decisions when non-obvious
- Avoid unnecessary complexity
- Prefer clarity over cleverness

---

## Summary

This repository must:
- Fully comply with Craftalism rules
- Maintain high engineering standards
- Improve performance safely
- Follow audit → implement → re-verify strictly

Failure to follow these principles is not acceptable.
