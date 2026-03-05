#! /usr/bin/env bash

set -xe

# Ensure the config file exists locally so Docker mounts it as a file, not a directory
touch "$HOME/.claude.json"

echo "FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y gh git curl xz-utils && rm -rf /var/lib/apt/lists/*

RUN usermod -u $(id -u) node || true
RUN groupmod -g $(id -g) node || true

RUN npm install -g @anthropic-ai/claude-code
RUN mkdir -m 0755 /nix && chown node:node /nix

USER node
ENV USER=node

RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
RUN git config --global user.name \"jappeace-sloth\"
RUN git config --global user.email \"sloth@jappie.me\"

ENV PATH=\"/home/node/.nix-profile/bin:\$PATH\"

WORKDIR /projects
" | docker build -t claude-env --load -

docker run -it \
    --init \
    -e NODE_OPTIONS="--dns-result-order=ipv4first" \
    -e TERM=xterm-256color \
    -e COLORTERM=truecolor \
    -e GH_TOKEN=$(cat ~/.gh_token) \
    --user $(id -u):$(id -g) \
    -v /nix:/nix \
    -v "$(pwd)/root":/projects \
    -v "$(pwd)/../vibes":/projects/vibes \
    -v "$HOME/.ssh/sloth:/home/node/.ssh/id_ed25519" \
    -v "$(pwd)/instances/kyle.json":/home/node/.claude.json \
    -v "$(pwd)/instances/kyle":/home/node/.claude \
    --rm \
    claude-env \
    bash
