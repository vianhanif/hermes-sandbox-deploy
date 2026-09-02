---
status: todo
priority: high
---

# Provision VPS data directories

On host:

```bash
mkdir -p /opt/hermes-sandbox/data/{hermes,workbench,ssh}
chown -R 1000:1000 /opt/hermes-sandbox/data/
```

(Design §10.3 Option A.)