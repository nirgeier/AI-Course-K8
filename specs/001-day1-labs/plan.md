# Implementation Plan: Day 1 Labs – Complete Implementation & Demo Assets

**Branch**: `001-day1-labs` | **Date**: 2025-10-25 | **Spec**: [spec.md](../spec.md)
**Input**: Feature specification from `/specs/001-day1-labs/spec.md`

## Summary

Deliver production-ready Day 1 lab materials that enable learners to set up the MCP/Kagent environment, build their first MCP server, and implement foundational metrics. Ship accompanying demo assets, troubleshooting guides, and verification tooling so instructors and support staff can replicate or diagnose every scenario without ad‑hoc work.

## Technical Context

**Language/Version**: Bash (POSIX-compatible), Python 3.11 for MCP server sample, YAML for Kubernetes manifests, Markdown for guides.  
**Primary Dependencies**: Docker Desktop, kind, kubectl, Helm 3, Prometheus kube-prometheus-stack charts, Python packages (`mcp`, `structlog`, `pydantic`, `kubernetes`, `prometheus_client`, `aiohttp`).  
**Storage**: Ephemeral Kubernetes cluster resources; no persistent database requirements beyond kube-state storage handled by kind.  
**Testing**: Shell validation scripts (bash with exit-code assertions), pytest suite for sample MCP server, Kubernetes `kubectl wait`/`kubectl get` based smoke checks.  
**Target Platform**: macOS 13+, Ubuntu 20.04+/Debian-based Linux, Windows 11 with WSL2 (Ubuntu).  
**Project Type**: Multi-component training assets (scripts + reference MCP service + documentation).  
**Performance Goals**: Environment bootstrap completes in ≤30 minutes on recommended hardware; demo MCP server responds to tool calls in <1 second locally; monitoring stack stable for ≥4 hours continuous lab usage.  
**Constraints**: Must operate on developer-grade laptops (≥8 GB RAM, ≥20 GB disk); no outbound internet beyond container registries/GitHub; all instructions must succeed offline after initial dependency download.  
**Scale/Scope**: Designed for cohorts up to 30 concurrent learners with individual clusters; artifacts must support recurring classes without rework.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution file is currently a placeholder with no ratified principles or gates. Treating constitution compliance as **PASS (no enforced constraints defined)**. Will re-evaluate if governance text is later populated.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
day-1/
├── README.md
├── labs/
│   ├── lab-01-environment-setup/
│   │   ├── README.md
│   │   ├── IMPLEMENTATION.md
│   │   ├── scripts/
│   │   │   ├── setup.sh
│   │   │   ├── install-*.sh
│   │   │   └── verify/quick-test utilities
│   │   └── config/
│   │       ├── kind-config.yaml
│   │       └── mcp-rbac.yaml
│   ├── lab-02-first-mcp-server/
│   │   └── README.md
│   └── lab-03-metrics-collection/
│       └── README.md
├── lectures/
│   ├── 01-mcp-protocol-foundation.md
│   └── 02-kagent-architecture.md
└── demos/ (to be created)
  ├── environment-runbooks/
  ├── mcp-server/
  └── metrics-dashboards/

resources/templates/simple-mcp-server/
└── README.md (existing starter template to expand or clone for demos)

docs/
├── best-practices.md
├── troubleshooting.md
└── references.md

tests/ (to be introduced)
├── shell/
└── python/
```

**Structure Decision**: This repository already houses documentation under `day-1/...`, supporting scripts in `day-1/labs/lab-01-environment-setup/scripts/`, configuration in `day-1/labs/lab-01-environment-setup/config/`, lecture materials in `day-1/lectures/`, and global docs under `docs/`. Implementation work will extend those folders plus add the reference MCP server under `resources/templates/simple-mcp-server/` (or a new `day-1/examples/` subdirectory if warranted) while keeping specs/plans in `specs/001-day1-labs/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
