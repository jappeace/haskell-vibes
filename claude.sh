#! /usr/bin/env bash

set -xe

# 1. Build and load the Docker image via Nix
# nix-build creates an executable script that streams the image tarball; we pipe it to docker load.
docker load -i "$(nix-build default.nix)"

# 2. Run the container
docker run -it \
    --init \
    -e NODE_OPTIONS="--dns-result-order=ipv4first" \
    -e TERM=xterm-256color \
    -e COLORTERM=truecolor \
    -e GH_TOKEN="$(cat ~/.gh_token)" \
    -e HOME="/home/claude" \
    --user "$(id -u):$(id -g)" \
    -v /nix/store:/nix/store:ro \
    -v "$(pwd)/root":/home/claude \
    -v "$(pwd)/../vibes":/home/claude/vibes \
    -v "$HOME/.ssh/sloth:/tmp/.ssh/id_ed25519" \
    -v "$(pwd)/instances/kyle.json":/home/claude/.claude.json \
    -v "$(pwd)/instances/kyle":/home/claude/.claude \
    --rm \
    claude-env:latest \
    claude
