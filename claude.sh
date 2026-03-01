#! /usr/bin/env bash

set -xe

# Ensure the config file exists locally so Docker mounts it as a file, not a directory
touch "$HOME/.claude.json"

echo "FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y git curl xz-utils && rm -rf /var/lib/apt/lists/*

RUN usermod -u $(id -u) node || true
RUN groupmod -g $(id -g) node || true

RUN npm install -g @anthropic-ai/claude-code
RUN mkdir -m 0755 /nix && chown node:node /nix

USER node
ENV USER=node

RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

ENV PATH=\"/home/node/.nix-profile/bin:\$PATH\"

WORKDIR /projects
" | docker build -t claude-env --load -

docker run -it \
    --init \
    -e NODE_OPTIONS="--dns-result-order=ipv4first" \
    -e TERM=xterm-256color \
    -e COLORTERM=truecolor \
    --user $(id -u):$(id -g) \
    -v /nix:/nix
    -v "$(pwd)":/projects \
    -v "$(pwd)../crypton":/projects/crypton \
    -v "$(pwd)../hs-memory":/projects/memory \
    -v "$HOME/.claude.json":/home/node/.claude.json \
    -v "$HOME/.claude":/home/node/.claude \
    -w /app \
    --rm \
    claude-env \
    bash
