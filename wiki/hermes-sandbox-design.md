# Hermes Agentic Sandbox — Design & Implementation Plan

## 1. Problem statement

Build a persistent, containerized AI-agent dev environment on the Tencent Cloud VPS.
Goals:
- Survives user downtime (continuity across busy periods).
- Harness: **Hermes Agent** (Nous Research).
- Reuses the local `~/.agents/` structure: Delegation Gate, role skills, MCP `9router-gateway`.
- Mirrors the `9router-deploy` infra pattern (docker-compose + CI scp + per-service env).
- Full tool access copied in: GitHub (gh), GitLab (glab), SSH keys.
- Simple access from the local Mac: `ssh tencent-cloud` (alias in `~/.ssh/config`).

## 2. Current state

- `9router-deploy` runs a 4-service stack on the VPS: `9router`, `9router-api`, `caddy`, `cloudflared`.
- Compose project is named `9router` (top-level `name:`), so the Docker bridge network is actually **`9router_9router-net`** — verified via `docker network ls`. The hermes compose must reference this exact external name.
- `9router-api` (port 20127) is the LLM+MCP gateway, live at `9router.vianhanif.link` via Cloudflare Tunnel.
- VPS reachable as `tencent-cloud` in `~/.ssh/config` (root, host `43.159.44.207`).
- Local `~/.agents/` holds AGENTS.md + role skills + 9router-gateway MCP wiring.
- Local project roots follow two trees:
  - `/Users/pid-alvian/Documents/personal/github/`
  - `/Users/pid-alvian/Documents/work/gitlab/`

## 3. Topology

```
Local Mac ── ssh tencent-cloud ──► VPS (/opt/hermes-sandbox)
                              │
                      docker-compose (hermes joins 9router_9router-net)
                              │
                      ┌───────▼────────┐
                      │     hermes     │  Hermes Agent container
                      │  CLI + gateway │  kanban + dispatcher
                      └───────┬────────┘
                              │
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
              hermes      hermes      hermes
              profile     profile     profile
              (coder)   (reviewer)   (tester)  ...
                              │
                    http://9router-api:20127
                              │  (internal compose DNS)
                    ┌─────────▼─────────┐
                    │ 9router-gateway   │  MCP: context7, firecrawl,
                    │       MCP         │  jam, metabase, jira...
                    └───────────────────┘
```

Key: Hermes reaches the MCP gateway over the shared `9router_9router-net` via container DNS (`9router-api:20127`) — no Cloudflare round-trip.

## 4. Repository layout

Two new repos:

### 4.1 `agents` (public)

The entire `~/.agents/` — `AGENTS.md`, role skills, delegate/orchestration skills, non-employer-coupled utility skills — lives in a **public GitHub repo** so the pattern can be shared, versioned, and consumed as the single source of truth by every environment (local Mac, VPS container, future machines).

```
agents/                          # github.com/<you>/agents (public)
├── README.md                    # the pitch: 5-role sessions, delegation gate, session chain
├── AGENTS.md                    # canonical (was ~/.agents/AGENTS.md), sanitized
├── skills/
│   ├── planner/  coder/  review/  tester/  analyzer/
│   ├── firecrawl*/  context7-mcp/
│   └── system-wiper/
├── install.sh                   # moves repo into ~/.agents (backup + mv pattern)
└── LICENSE (MIT)
```

**Sanitization rules (public-safe):**
- No secrets, no tokens, no gateway keys — reference `${ROUTER9_GATEWAY_KEY}` placeholders only.
- No employer-specific ticket prefixes, JIRA project keys, Metabase instance slugs, or internal URLs.
- Employer-coupled skills (`jira-sprint-orchestrator`, `sprint-jam-triage`, `sprint-review-orchestrator`, `mcp-gateway-sync`) either **stay out of this repo** (kept locally / in a separate private repo) or are genericized before publishing.
- MCP config in `AGENTS.md` references the gateway URL/pattern but never a real key.

**Local Mac usage:** `git clone` once, then run `install.sh` which backs up any existing `~/.agents` and moves the cloned repo into place as `~/.agents`.

### 4.2 `hermes-sandbox-deploy` (private, mirrors `9router-deploy`)

```
hermes-sandbox-deploy/
├── docker-compose.yml           # hermes service, joins 9router-net
├── Dockerfile                   # Hermes + gh/glab/node/git/rg/fd/jq; clones public agents repo
├── .env.example
├── .gitignore                   # env/*.env, data/
├── env/
│   └── hermes.env.example       # model keys, ROUTER9_GATEWAY_KEY (real values gitignored)
├── config/
│   ├── config.yaml              # Hermes config (terminal backend, kanban plugin enabled)
│   └── mcp.json                 # points at http://9router-api:20127/api/mcp-gateway
├── data/                        # gitignored — persistent .hermes state, workbench
└── .github/workflows/deploy.yml # scp + compose build/up (mirrors 9router-deploy)
```

AGENTS.md and skills are **not** vendored here — they are pulled from the public `agents` repo at build time. Stays private because it holds the deploy pipeline, env references, and infra glue.

Remote path on VPS: `/opt/hermes-sandbox/`.

## 5. AGENTS.md — project root structure

The public `agents` repo already contains a Project Root Detection section in `AGENTS.md`. The VPS Hermes container must reproduce the same dual-root layout so paths are consistent whether the agent runs locally or in the container:

- Personal github repos root: `~/Documents/personal/github/`
- Work gitlab repos root: `~/Documents/work/gitlab/`

Subproject roots are the deepest dir under either tree containing a project file (`package.json`, `go.mod`, `pyproject.toml`, etc.). When the agent works a repo, it must resolve the absolute root under its active tree first, then operate relative to it — never assume it is in the repo's root already. On the VPS container these paths are provisioned once under the mounted `/workbench` volume (see §7).

## 5.1 Hermes config.yaml

`config/config.yaml` (deploy-specific, not in the public repo) enables the role profiles and kanban orchestration. Derived from the **current stable Hermes config surface** — not the earlier draft's invalid `kanban.enabled` key:

```yaml
# role profiles mirroring ~/.agents roles
profiles:
  - name: planner
  - name: coder
  - name: reviewer
  - name: tester
  - name: analyzer

kanban:
  orchestrator_profile: planner        # decomposes triage tasks
  default_assignee: coder              # fallback route when no profile fits
  auto_decompose: true                 # auto-expand triage -> child tasks
  dispatch_in_gateway: true            # dispatcher lives in the gateway process

auxiliary:
  kanban_decomposer: ${AUX_MODEL}      # model used for task decomposition
```

Notes:
- The dispatcher runs **inside the gateway** by default (`kanban.dispatch_in_gateway: true`), so the container must start Hermes in **gateway mode** for kanban workers to spawn — not just a bare CLI session.
- No messaging gateway is configured yet (no Telegram/Discord/WhatsApp). Kanban is driven via CLI + dashboard only.
- Model refs like `${AUX_MODEL}` are injected from `env/hermes.env` at provision time — never hardcoded.

## 6. Dockerfile (draft)

```dockerfile
# hermes-sandbox-deploy/Dockerfile
FROM ghcr.io/nousresearch/hermes-agent:latest

USER root
# dev tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ripgrep fd-find jq python3 nodejs npm \
    && curl -fsSL https://cli.github.com/ghcli.tar.gz | tar xz -C /usr/local/bin --strip 1 \
    && rm -rf /var/lib/apt/lists/*

# clone the PUBLIC agents repo at build time — no auth needed, single source of truth
ARG AGENTS_REPO=https://github.com/vianhanif/agents.git
ARG AGENTS_REF=master
RUN git clone --depth 1 --branch "$AGENTS_REF" "$AGENTS_REPO" /home/hermes/.agents \
    && mkdir -p /home/hermes/.hermes \
    && ln -s /home/hermes/.agents/AGENTS.md /home/hermes/.hermes/AGENTS.md \
    && ln -s /home/hermes/.agents/skills /home/hermes/.hermes/skills

# hermes-only container config (mcp.json + config.yaml) — deploy-specific, not in public repo
COPY config/mcp.json /home/hermes/.hermes/mcp.json
COPY config/config.yaml /home/hermes/.hermes/config.yaml

USER hermes
WORKDIR /workbench
ENTRYPOINT ["hermes"]
```

Notes:
- Public `agents` repo is cloned unauthenticated at build. Rebuild picks up new skills.
- Real tools/auth mounted at runtime, not baked: `gh` token via `GH_TOKEN`, `glab` via `GITLAB_TOKEN`, SSH via mounted `~/.ssh`.
- Symlinks (not copies) so `~/.agents/**` remains the canonical tree; volume-mount `data/agents:/home/hermes/.agents` optional if you want to `git pull` without rebuilding.

## 7. docker-compose.yml (draft)

Two compose files keep local runs portable (no external network needed) while VPS deploys join the 9router network:

`docker-compose.yml` (local-runnable default):

```yaml
name: hermes-sandbox

services:
  hermes:
    build: .
    container_name: hermes
    restart: unless-stopped
    env_file: ./env/hermes.env
    environment:
      HOME: /home/hermes
      # gateway-mode needed so the kanban dispatcher runs
      HERMES_DASHBOARD: 1            # supervised web dashboard (port 9119)
      HERMES_DASHBOARD_PORT: 9119
      # keys for tool access (sampled via env/.env, never committed)
      GH_TOKEN: ${GH_TOKEN}
      GITLAB_TOKEN: ${GITLAB_TOKEN}
      ROUTER9_GATEWAY_URL: ${ROUTER9_GATEWAY_URL}
      ROUTER9_GATEWAY_KEY: ${ROUTER9_GATEWAY_KEY}
    volumes:
      - ./data/hermes:/home/hermes/.hermes      # persistent state, memory, sessions, kanban SQLite
      - ./data/workbench:/workbench             # repo checkouts / git worktrees (dual-root layout)
      - ./data/ssh:/home/hermes/.ssh:ro         # ssh keys provisioned once, host-side
    ports:
      - "9119:9119"                             # web dashboard (Kanban tab)
    stdin_open: true
    tty: true
```

`docker-compose.vps.yml` (override used only on VPS — joins the 9router network):

```yaml
services:
  hermes:
    networks:
      - 9router_9router-net

networks:
  9router_9router-net:
    external: true     # existing 9router stack network on the VPS
```

Local run: `docker compose up -d --build` (no external network).
VPS run: `docker compose -f docker-compose.yml -f docker-compose.vps.yml up -d --build`.

Remote layout `/opt/hermes-sandbox/`:
- `data/hermes/` → persistent `.hermes` (sessions, memory, kanban SQLite board).
- `data/workbench/` → checkouts + worktrees under dual-root layout: `workbench/personal/github/` and `workbench/work/gitlab/`.
- `data/ssh/` → SSH keys (gitlab/github deploy access), provisioned once, not committed.

**Secrets sampling (`.env`, not committed):**
- `env/hermes.env.example` is committed with placeholder values (`<fill-me>`).
- Real values live in a gitignored `env/hermes.env`, copied from the example once and filled on the VPS. `.env.list` / `.env.example` follow the same pattern as `9router-deploy`.
- Never commit `env/hermes.env`, `data/`, or any real token/key.

## 8. MCP wiring

`config/mcp.json` inside container:

```json
{
  "servers": {
    "9router-gateway": {
      "url": "http://9router-api:20127/api/mcp-gateway",
      "headers": { "Authorization": "Bearer ${ROUTER9_GATEWAY_KEY}" }
    }
  }
}
```

`${ROUTER9_GATEWAY_KEY}` injected from `env/hermes.env` at provision time — never committed. MCP URL is also env-driven (`${ROUTER9_GATEWAY_URL}`) so the same `config/mcp.json` works locally (uses `host.docker.internal`) and on the VPS (uses compose DNS).

## 9. Kanban & orchestration

Hermes Kanban is a bundled, durable multi-profile task board — **no messaging gateway required**. It has two surfaced front doors:
- **CLI** (`hermes kanban …`) — for humans/automation.
- **Dashboard** — `hermes dashboard` serves a Kanban tab (port 9119) with drag-drop board UI. Bundled dashboard-tab plugins (kanban, etc.) are auto-discovered at runtime; there is **no** `kanban.enabled` config key — the board is enabled by starting the dashboard. The agent-side toolset is gated by the `kanban` plugin for orchestrator profiles.

Core flow (single default board):
```bash
hermes kanban init                     # optional; first use auto-inits
hermes kanban create "<task>" --assignee <profile>
hermes kanban list / watch / stats
hermes dashboard                       # serves http://127.0.0.1:9119 (Kanban tab)
```

Statuses: `Triage → Todo → Ready → Running → Blocked → Done → Archived`.

Dispatching (via `config.yaml`, §5.1): `orchestrator_profile`/`default_assignee` set routing, `auto_decompose` expands triage, `dispatch_in_gateway: true` runs the dispatcher inside the gateway process. The container runs in **gateway mode** so the dispatcher is live and workers spawn.

Named Hermes profiles map to `~/.agents` roles: `planner`, `coder`, `reviewer`, `tester`, `analyzer`.
Worktrees under `/workbench` per task = the `AGENTS.md` isolated-worktree rule.

## 10. Access from local Mac

The container exposes the Hermes CLI and web dashboard. No messaging gateway is configured yet.

### 10.1 CLI (primary)

SSH into the VPS and attach to the running `hermes` container:
```bash
# one-shot: attach to the Hermes CLI inside the container
ssh tencent-cloud -t 'docker exec -it hermes hermes'
```

Prerequisite on the VPS host: `docker` CLI available and runnable for the SSH user. You must be in the `docker` group (or root) to run `docker exec` without sudo. Verify once:
```bash
ssh tencent-cloud 'docker version'          # if "permission denied", add user to docker group
```

### 10.2 Web dashboard (Kanban board UI)

The dashboard binds `0.0.0.0:9119` inside the container and is published to the host on `9119`. Do **not** open it to the public internet — reach it via SSH tunnel:
```bash
# from local Mac: forward VPS:9119 -> localhost:9119, then open browser
ssh tencent-cloud -L 9119:localhost:9119
# then browse http://127.0.0.1:9119  →  Kanban tab
```

### 10.3 Data directory permissions

Because the container runs as non-root user `hermes` (UID 1000), the host must pre-create data directories with ownership matching. Two options:

**Option A — chown (recommended):**
```bash
# on the VPS host, before first deploy:
sudo mkdir -p /opt/hermes-sandbox/data/{hermes,workbench,ssh}
sudo chown -R 1000:1000 /opt/hermes-sandbox/data/
```

**Option B — Docker user namespace remap:**
Enable userns-remap in `/etc/docker/daemon.json` to map host UID 1000 to container UID 1000. More complex, avoids host-side chown but requires daemon restart.

Start with Option A. If permission errors persist inside the container despite chown, run `docker exec -u root hermes chown -R 1000:1000 /home/hermes/.hermes` to fix from inside.

## 11. Implementation roadmap

1. Verify upstream: on first installed container run `hermes kanban --help`; confirm plugin exists before relying on it.
2. **Extract `~/.agents/` → public `agents` repo.**
   - Audit for secrets (`gitleaks detect`) and employer refs (`grep -rE 'aus-api|jira|metabase|<internal>'`).
   - Move employer-coupled skills out; keep or genericize.
   - Add dual-root project structure section (personal/github, work/gitlab) to `AGENTS.md`.
   - Publish to GitHub public. Add `install.sh` that does `ln -s $PWD ~/.agents`.
   - Local Mac: `mv ~/.agents ~/.agents.bak`, clone the repo, run `install.sh`, validate every existing skill resolves.
3. Create `hermes-sandbox-deploy` repo skeleton (compose, Dockerfile, env, config, CI). Dockerfile clones the public `agents` repo.
4. Provision VPS secrets once (not via CI): `env/hermes.env`, mounted `~/.ssh` for GitHub/GitLab access.
5. Deploy via `.github/workflows/deploy.yml` (scp + compose build/up).
6. Validate: `hermes doctor`, `hermes kanban --help`, `curl http://9router-api:20127/api/health` from inside container, `ls ~/.hermes/skills/` shows all public repo skills.
7. **Update flow going forward:** commits to `agents` repo → rebuild container (or `git -C ~/.agents pull` if agents dir is volume-mounted) to pick up new skills.

## 12. Open questions / risks

- **Kanban availability** — confirmed by ChatGPT via repo scan but not yet verified against the pinned deploy version. Step 1 gates the kanban plan.
- **MCP gateway auth** — confirm Bearer auth at container-internal URL works without Cloudflare (`9router-api:20127` listens on the compose network).
- **`~/.agents` public repo hygiene** — one public repo is the single source of truth. Anything employer-coupled or secret must be stripped out before first push, and CI (pre-commit `gitleaks`) enforces it. Truly private items (e.g. `mcp-gateway-sync` if it exposes internal topology) live outside this repo entirely.
- **Single-node vs fabric** — start single Hermes node. Escalate to `hermes-super-agent` fabric only if parallel fan-out (>10) or multi-day durable workflows are actually needed. YAGNI.
