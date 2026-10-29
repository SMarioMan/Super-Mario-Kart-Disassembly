# Build from this repository root: docker build -t smk-link-rom .
# Optional git_ca BuildKit secret supplies a corporate Git CA without storing it.
FROM debian:trixie-slim
ARG JOBS=4
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git build-essential cmake python3 \
    && rm -rf /var/lib/apt/lists/*
RUN --mount=type=secret,id=git_ca \
    if [ -f /run/secrets/git_ca ]; then export GIT_SSL_CAINFO=/run/secrets/git_ca; fi; \
    git clone --branch v1.71 --depth 1 https://github.com/RPGHacker/asar.git /tmp/asar \
    && test "$(git -C /tmp/asar rev-parse HEAD)" = 217a93ffd44a44f196a06cff9b96ddb7dc892b8b \
    && cmake -S /tmp/asar/src -B /tmp/asar-build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/asar-build -j "$JOBS" \
    && install /tmp/asar-build/asar/asar-standalone /usr/local/bin/asar \
    && rm -rf /tmp/asar /tmp/asar-build
COPY . /opt/disassembly
RUN chmod -R a+rX /opt/disassembly
ENTRYPOINT ["python3", "/opt/disassembly/tools/docker_build.py"]
