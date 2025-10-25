# Phase 0 Research – Day 1 Labs

## Environment Automation Stack

- **Decision**: Keep environment provisioning scripted with POSIX-compliant Bash orchestrating Docker, kind, kubectl, and Helm.
- **Rationale**: The lab audience already enables shell scripts; Bash keeps parity across macOS, Linux, and WSL2 while reusing existing `lab-01` assets.
- **Alternatives considered**:
  - **Python CLI**: Adds interpreter dependency for users focused on Lab 01; increases maintenance cost.
  - **Ansible playbooks**: Overkill for single-node developer clusters and increases prerequisite complexity.

## Reference MCP Server Implementation

- **Decision**: Use Python 3.11 with the `mcp` SDK, `pydantic` validation, and `structlog` logging for the Day 1 sample server.
- **Rationale**: Python matches existing course materials, allows rich inline documentation, and lets learners focus on MCP concepts instead of language setup.
- **Alternatives considered**:
  - **Go implementation**: Great for production agents but adds toolchain complexity for new learners.
  - **Node.js**: Would require retooling labs and contradict current Python-centric examples.

## Metrics & Observability Toolkit

- **Decision**: Standardize on kube-prometheus-stack with Prometheus + Grafana, exposing metrics via `/metrics` Prometheus format from the sample MCP server.
- **Rationale**: Aligns with Lab 03 objectives, leverages existing Helm charts, and offers immediate visualization through Grafana dashboards.
- **Alternatives considered**:
  - **Manual Prometheus configuration**: More control but slower for learners; Helm chart abstracts boilerplate.
  - **OpenTelemetry-only approach**: Interesting but introduces extra collectors and cognitive load beyond Day 1 scope.

## Demo & Troubleshooting Assets

- **Decision**: Package instructor demos as scripted command transcripts with optional screen recordings, and ship troubleshooting matrices keyed to verification script outputs.
- **Rationale**: Provides reproducible guidance for instructors and support, reducing prep time and ambiguity.
- **Alternatives considered**:
  - **Ad-hoc slide decks per cohort**: Inconsistent and easy to drift; difficult to maintain.
  - **Live-only demos**: Risk of failure without dry-run assets; no reusable recordings for async learners.

## Cross-Platform Compatibility

- **Decision**: Validate all scripts against macOS (zsh), Ubuntu (bash), and WSL2 (Ubuntu) with conditional branches for package managers where required.
- **Rationale**: Ensures the published "supported platforms" statement is accurate and reduces support tickets.
- **Alternatives considered**:
  - **macOS-only focus**: Cuts testing effort but leaves Windows/Linux learners unsupported.
  - **Container-only workflow**: Simplifies host setup but hides Kubernetes concepts learners must understand.
