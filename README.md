# Custom "Full" GitHub Actions Runner Image
This repository contains a Dockerfile to build a "Batteries-Included" GitHub Actions Runner.

It combines the official [GitHub Actions Runner agent](https://github.com/actions/runner) with the [catthehacker/ubuntu:full-24.04](https://github.com/catthehacker/docker_images) base image. This ensures your runner comes pre-installed with a massive suite of tools (Node, Python, Go, Rust, PHP, AWS CLI, gcloud, kubectl, etc.), similar to the GitHub-hosted `ubuntu-24.04` runners.

## Features
- Base OS: Ubuntu 24.04 (Noble Numbat)

- Tooling: Includes almost all tools found in standard GitHub-hosted runners (via `catthehacker`).

- Orchestration: Includes `runner-container-hooks` for Kubernetes (ARC) integration.

- Docker: Installs a specific version of Docker CLI and Buildx.

- User: Runs as non-root user `runner` (UID 1001) with `sudo` and docker `privileges`.