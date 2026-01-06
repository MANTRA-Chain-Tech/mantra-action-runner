# Custom GitHub Actions Runner Image

This repository contains the source code and automation pipeline to build a custom **GitHub Actions Runner** Docker image. This image is based on Ubuntu 24.04 (Noble) and is pre-packaged with the tools required to build, test, and release software (including Docker-in-Docker support).

## 🐳 Image Capabilities

This image is built on top of `mcr.microsoft.com/dotnet/runtime-deps:8.0-noble` and includes the following tools:

* **Core Runner:** GitHub Actions Runner (configurable version).
* **Container Hooks:** `runner-container-hooks` (versions `0.7.0` and `0.8.0`) for Kubernetes integration.
* **Docker:** Full Docker CLI and `docker-buildx` plugin for building container images.
* **Build Tools:** `build-essential` (GCC, Make), `git` (latest PPA), `python3-dev`.
* **Utilities:** `curl`, `jq`, `unzip`, `sudo`.

## 🚀 Workflow Overview

The build pipeline is defined in `.github/workflows/docker-buildx.yml`. It uses a **Matrix Strategy** to build separate images for `amd64` and `arm64` architectures in parallel.

### Triggering the Build

The workflow runs manually via `workflow_dispatch`.

### Architecture Support

| Architecture | Runner Used for Build | Docker Platform |
| --- | --- | --- |
| **AMD64** (x64) | `ubuntu-latest` | `linux/amd64` |
| **ARM64** (aarch64) | `ubuntu-24.04-arm` | `linux/arm64` |

## 📦 Output Images & Naming Convention

Unlike standard multi-arch manifests, this workflow publishes **separate image repositories** for each architecture to the Container Registry (e.g., GHCR).

The images are pushed to:

* **AMD64:** `ghcr.io/<owner>/<repo>/amd64:<tag>`
* **ARM64:** `ghcr.io/<owner>/<repo>/arm64:<tag>`

### Tags

Tags are generated automatically based on the Git metadata (using `docker/metadata-action`):

* `latest` (for the default branch)
* `pr-<number>` (for Pull Requests)
* `v1.0.0` (SemVer tags)
* `sha-<commit-hash>` (Short commit SHA)

## 🛠 Configuration

### Required Repository Variables (`vars`)

To run this build successfully, ensure the following variables are set in your GitHub Repository settings:

| Variable Name | Description | Required | Example |
| --- | --- | --- | --- |
| `RUNNER_VERSION` | The version of the GitHub Actions Runner binary to install. | **Yes** | `2.321.0` |
| `REGISTRY` | The container registry URL. Defaults to GHCR if unset. | No | `ghcr.io/mantra-chain` |
| `IMAGE_NAME` | The base name for the image. Defaults to repo name if unset. | No | `actions-runner` |

### Docker Build Arguments

The workflow passes the following build arguments to the Dockerfile:

* `RUNNER_VERSION`: Sourced from the `vars.RUNNER_VERSION` context.
* `TARGETARCH`: Explicitly set based on the matrix job (`amd64` or `arm64`).

## 🧱 Dockerfile Details

The `Dockerfile` employs a multi-stage build process:

1. **Build Stage (`build`)**:
* Downloads the specific `actions-runner` binary for the target architecture.
* Downloads `runner-container-hooks` (for Kubernetes execution).
* Downloads static Docker binaries and the `buildx` plugin.


2. **Final Stage**:
* Installs system dependencies (`git`, `make`, `gcc`, `python3-dev`).
* Configures the `runner` user (UID 1001) with `sudo` and `docker` group privileges.
* Copies prepared artifacts from the build stage.
* Sets up the entrypoint environment (`DEBIAN_FRONTEND=noninteractive`).



## 💻 Local Development

To build the image locally for testing purposes:

```bash
# Set your desired version
export RUNNER_VERSION=2.321.0

# Build for your current architecture
docker build \
  --build-arg RUNNER_VERSION=${RUNNER_VERSION} \
  --build-arg TARGETARCH=$(dpkg --print-architecture) \
  -t local-runner:test .

```