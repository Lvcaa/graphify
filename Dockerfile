# =============================================================================
# Hardened by BreachBench — Deterministic Static Container Hardening
# Stage 1: Build & Deterministic Attack-Surface Stripping (breachbench-builder)
# =============================================================================
# graphify MCP server as a shared HTTP service (issue #1143).
#
# Build:  docker build -t graphify .
# Run:    docker run -p 8080:8080 -v "$(pwd)/graphify-out:/data" graphify \
#             /data/graph.json --transport http --host 0.0.0.0 --api-key "$SECRET"
#
# Builds from source so the image includes the Streamable HTTP transport even
# before it lands on PyPI. The graph.json is mounted at runtime (-v), never
# baked into the image.
FROM python:3.12-slim AS breachbench-builder

WORKDIR /app
COPY . /app

# The [mcp] extra pulls mcp + starlette + uvicorn, which the HTTP transport needs.
RUN pip install --no-cache-dir ".[mcp]"

# Run as a non-root user — the server is network-exposed.
RUN useradd --create-home --uid 10001 graphify
USER graphify

EXPOSE 8080

ENTRYPOINT ["python", "-m", "graphify.serve"]
CMD ["/data/graph.json", "--transport", "http", "--host", "0.0.0.0", "--port", "8080"]

# Deterministic Static Hardening: non-root user provisioning, cache cleanup & tool removal
USER root
RUN mkdir -p /app /tmp && \
    (grep -q '^nonroot:' /etc/passwd 2>/dev/null || echo 'nonroot:x:65532:65532:nonroot:/nonexistent:/sbin/nologin' >> /etc/passwd) && \
    (grep -q '^nonroot:' /etc/group 2>/dev/null || echo 'nonroot:x:65532:' >> /etc/group) && \
    chown -R 65532:65532 /app /tmp && \
    rm -rf /var/lib/apt/lists/* /var/cache/apk/* /root/.cache /tmp/* && \
    rm -f /usr/bin/apt /usr/bin/apt-get /usr/bin/apt-cache /usr/bin/dpkg /sbin/apk /usr/bin/dnf /usr/bin/yum /usr/bin/microdnf /usr/bin/pip /usr/bin/pip3 /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/npm /usr/local/bin/npx /usr/bin/npm /usr/bin/npx /usr/local/bin/yarn /usr/local/bin/corepack /usr/bin/curl /usr/bin/wget /usr/bin/nc /bin/nc /usr/bin/netcat /bin/netcat /usr/bin/socat /usr/bin/ssh /usr/bin/scp && \
    rm -f /bin/sh /bin/bash /bin/dash /bin/ash /bin/zsh /usr/bin/sh /usr/bin/bash /usr/bin/dash /usr/bin/ash /usr/bin/zsh

# =============================================================================
# Stage 2: Minimal Flattened Runtime Image (Zero Deleted-Layer Leakage)
# =============================================================================
FROM scratch

COPY --from=breachbench-builder / /

WORKDIR /app
EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["python", "-m", "graphify.serve"]
CMD ["/data/graph.json", "--transport", "http", "--host", "0.0.0.0", "--port", "8080"]
