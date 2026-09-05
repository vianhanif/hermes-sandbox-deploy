#!/usr/bin/env bash
set -euo pipefail

# Seed persistent ~/.hermes (host volume is empty on first boot and shadows
# the image-baked config). Only seeds missing paths so later manual edits win.
SEED_DIR=/opt/hermes-seed

mkdir -p "$HOME/.hermes"
[[ -e "$HOME/.hermes/AGENTS.md" ]] || ln -sfn /home/hermes/.agents/AGENTS.md "$HOME/.hermes/AGENTS.md"
[[ -e "$HOME/.hermes/skills" ]] || ln -sfn /home/hermes/.agents/skills "$HOME/.hermes/skills"
[[ -e "$HOME/.hermes/mcp.json" ]] || cp "$SEED_DIR/mcp.json" "$HOME/.hermes/mcp.json"
[[ -e "$HOME/.hermes/config.yaml" ]] || cp "$SEED_DIR/config.yaml" "$HOME/.hermes/config.yaml"

# Launch dashboard in background if auth is configured (idempotent — skips
# if something already listens on 9119, e.g. HERMES_DASHBOARD self-supervision)
if grep -q '^dashboard:' "$HOME/.hermes/config.yaml" 2>/dev/null \
   && ! curl -fsS -o /dev/null -m 2 http://localhost:9119/ 2>/dev/null; then
  nohup hermes dashboard --no-open --host 0.0.0.0 --port 9119 >/dev/null 2>&1 &
fi

exec hermes "$@"
