# Day 1 Labs Quickstart

## Prerequisites

- macOS 13+, Ubuntu 20.04+, or Windows 11 with WSL2 (Ubuntu profile)
- 8 GB RAM (16 GB recommended) and 20 GB free disk space
- Admin rights to install Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Stable internet connection for initial dependency downloads

## 10-Minute Overview

1. **Clone the repository**

   ```bash
   git clone https://github.com/nirgeier/AI-Course.git
   cd AI-Course
   git checkout 001-day1-labs
   ```

2. **Run the automated environment build** (Lab 01)

   ```bash
   cd day-1/labs/lab-01-environment-setup/scripts
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Validate the cluster**

   ```bash
   ./verify-environment.sh
   ./quick-test.sh
   ```

4. **Launch the reference MCP server** (Lab 02)

   ```bash
   cd ../../lab-02-first-mcp-server/reference
   ./scripts/bootstrap.sh      # creates virtualenv, installs deps
   ./scripts/run-dev.sh        # starts MCP server with metrics exporter
   ```

5. **Explore metrics dashboards** (Lab 03)

   ```bash
   # In a new terminal
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```

   Open [http://localhost:3000](http://localhost:3000) and import `day-1/demos/metrics-dashboards/day1-overview.json`.

## Instructor Demo Flow

1. Review the runbook at `day-1/demos/environment-runbooks/day1-demo.md`.
2. Rehearse the checkpoint commands; record outputs for learners.
3. Capture screen/audio using the template in `day-1/demos/recordings/README.md`.
4. Share the generated assets via the cohort communication channel.

## Troubleshooting Highlights

- **Setup failures**: Inspect `logs/setup-*.log` produced by `setup.sh` and cross-reference `specs/001-day1-labs/diagnostics/issue-matrix.md`.
- **MCP server errors**: Run `pytest` inside `lab-02` reference project; check `logs/server/*.log` for structlog traces.
- **Metrics missing**: Ensure `kubectl get pods -n monitoring` reports all pods Ready; redeploy via `deploy-monitoring.sh` if necessary.

## Next Steps

- Complete Day 1 success checklist in `day-1/README.md`.
- Continue to Day 2 by reviewing `day-2/README.md` and staging the Day 2 labs.
- Update generated artifacts (recordings, logs, dashboards) with cohort-specific metadata before distribution.
