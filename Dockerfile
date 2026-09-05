FROM nousresearch/hermes-agent:latest

# Hermes Agent container
USER root
# dev tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ripgrep fd-find jq python3 nodejs npm gnupg ca-certificates \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# clone the PUBLIC agents repo at build time — no auth needed, single source of truth
ARG AGENTS_REPO=https://github.com/vianhanif/agents.git
ARG AGENTS_REF=master
RUN git clone --depth 1 --branch "$AGENTS_REF" "$AGENTS_REPO" /home/hermes/.agents \
    && mkdir -p /home/hermes/.hermes \
    && ln -s /home/hermes/.agents/AGENTS.md /home/hermes/.hermes/AGENTS.md \
    && ln -s /home/hermes/.agents/skills /home/hermes/.hermes/skills

# hermes-only container config (mcp.json + config.yaml) — deploy-specific, not in public repo
COPY config/mcp.json /opt/hermes-seed/mcp.json
COPY config/config.yaml /opt/hermes-seed/config.yaml
COPY scripts/entrypoint.sh /usr/local/bin/hermes-entrypoint
RUN chmod +x /usr/local/bin/hermes-entrypoint

USER hermes
WORKDIR /workbench
ENTRYPOINT ["/usr/local/bin/hermes-entrypoint"]
