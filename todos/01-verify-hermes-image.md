---
status: todo
priority: high
---

# Verify upstream Hermes Docker image

Draft `Dockerfile` uses `FROM ghcr.io/nousresearch/hermes-agent:latest`; upstream docs show `nousresearch/hermes-agent` (Docker Hub) with data at `/opt/data`.

Confirm actual tag, user, HOME, data-dir path, entrypoint; align compose volume mounts accordingly.