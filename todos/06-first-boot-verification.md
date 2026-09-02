---
status: todo
priority: med
---

# First-boot verification

On first container run:

- `hermes kanban --help` exists in pinned version (gates kanban plan)
- MCP Bearer auth works at internal `http://9router-api:20127` (no Cloudflare)
- `hermes doctor` passes
- `~/.hermes/skills/` symlinks resolve from public agents repo