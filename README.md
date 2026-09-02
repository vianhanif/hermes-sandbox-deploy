# Hermes Sandbox Deployment

Containerized AI-agent development environment for VPS deployment, tightly coupled with the `vianhanif/9router-deploy` infrastructure pattern.

## Use Case Flow

1. **Deployment**: CI/CD (`.github/workflows/deploy.yml`) builds the hermes container (which clones your public `vianhanif/agents` repo for role skills) and deploys via `docker-compose`.
2. **Setup**: The environment initializes persistent SQLite-backed storage for Kanban tasks, memory, and git worktrees.
3. **Workflow**:
    - **Triage**: Tasks land in the `Triage` column.
    - **Dispatch**: The dispatcher orchestrator (planner) decomposes tasks and routes them to specific worker profiles (`coder`, `reviewer`, `tester`).
    - **Execution**: Worker agents operate inside isolated git worktrees.
    - **Review**: Reviewers inspect changes; results are hand-off via durable Kanban metadata.
4. **Access**: Attach to the CLI via SSH (`ssh tencent-cloud -t 'docker exec -it hermes hermes'`) or use the local Kanban dashboard via SSH tunnel (`ssh tencent-cloud -L 9119:localhost:9119`).

## Running Locally

To support local runs (e.g., testing orchestration logic before VPS push), this project is designed for portable execution:

1. **Config**: Uses standard `.env` sampling. Copy `env/hermes.env.example` to `env/hermes.env` and populate.
2. **Network**: The base `docker-compose.yml` uses local-runnable defaults. No external networks required for local testing.
3. **Gateway**: For local MCP gateway access, ensure `ROUTER9_GATEWAY_URL` in `env/hermes.env` points to your local 9router gateway (e.g., `http://host.docker.internal:20127/api/mcp-gateway`).
4. **Start**: `docker compose up -d --build`

## Architecture Highlights
- **Tightly Coupled**: Built as a peer to `9router-deploy` (shared network `9router_9router-net`, shared infra patterns).
- **Public-Private Split**: Role skills (`agents` repo) are public for portability, while infra/secrets/config (`hermes-sandbox-deploy`) remain private.
- **Durable Kanban**: SQLite-backed board surviving restarts.

## Documentation
The complete technical design and infrastructure roadmap is in `wiki/hermes-sandbox-design.md`.
