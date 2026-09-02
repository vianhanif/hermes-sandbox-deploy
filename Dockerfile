# Hermes Agent container

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