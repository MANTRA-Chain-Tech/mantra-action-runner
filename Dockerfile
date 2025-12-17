# -------------------------------------------------------------------------
# STAGE 1: Build & Download Artifacts
# -------------------------------------------------------------------------
# We use a standard ubuntu image for the build stage to keep it clean
FROM ubuntu:24.04 AS build

ARG TARGETOS=linux
ARG TARGETARCH
ARG RUNNER_VERSION
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DOCKER_VERSION=29.0.2
ARG BUILDX_VERSION=0.30.1

# Install minimal tools to download artifacts
RUN apt-get update -y && apt-get install -y curl unzip

WORKDIR /actions-runner

# 1. Download GitHub Actions Runner
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
    && curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${TARGETOS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

# 2. Download K8s Hooks (Volume)
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

# 3. Download K8s Hooks (No Volume)
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v0.8.0/actions-runner-hooks-k8s-0.8.0.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s-novolume \
    && rm runner-container-hooks.zip

# 4. Download Docker CLI (Optional: catthehacker already has docker, but this ensures specific version)
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export DOCKER_ARCH=x86_64 ; fi \
    && if [ "$RUNNER_ARCH" = "arm64" ]; then export DOCKER_ARCH=aarch64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/${TARGETOS}/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && rm -rf docker.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fLo /usr/local/lib/docker/cli-plugins/docker-buildx \
    "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# -------------------------------------------------------------------------
# STAGE 2: Final Image (The "Fat" Runner)
# -------------------------------------------------------------------------
FROM catthehacker/ubuntu:full-24.04

# Switch to root to perform installations and permissions fixes
USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV ImageOS=ubuntu24

# 1. Install Runner Dependencies
# catthehacker has most tools, but we ensure .NET dependencies (libicu) and base utils are present.
# We skip installing git/curl/jq as they are definitely in the full image.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
       libicu-dev \
       sudo \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure User 'runner'
# catthehacker image usually creates a user 'runner' (uid 1001) or 'act'. 
# We detect if it exists; if not, create it. Then ensure sudo/docker rights.
RUN if ! id -u runner > /dev/null 2>&1; then \
        adduser --disabled-password --gecos "" --uid 1001 runner; \
    fi \
    && groupadd -f docker \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

# 3. Setup Runner Directory
# We must ensure permissions are correct for the 'runner' user
WORKDIR /home/runner
RUN chmod 777 /home/runner

# 4. Install Docker CLI & Buildx (From Build Stage)
# Overwriting the pre-installed docker cli ensures you get the version you defined in ARG
COPY --from=build /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx
COPY --from=build /actions-runner/docker/docker /usr/bin/docker

# 5. Install Actions Runner Binaries (From Build Stage)
COPY --chown=runner:docker --from=build /actions-runner .

# Switch back to the runner user for execution
USER runner