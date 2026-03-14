# Stage 1: Get the actions-runner binaries
FROM ghcr.io/actions/actions-runner:2.332.0 AS runner-base

# Stage 2: Get docker CLI + buildx
FROM docker:27.3.1-cli AS docker-base

# Stage 3: Build the final runner image
FROM ubuntu:22.04

ARG TARGETOS
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

# Install base packages
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    sudo \
    lsb-release \
    libicu-dev \
    curl \
    unzip \
    zip \
    git \
    jq \
    awscli \
    openssh-client \
    build-essential \
    maven \
    && rm -rf /var/lib/apt/lists/*

RUN eval $(ssh-agent -s)

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kubectl
RUN curl -fLO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install devspace
RUN curl -f -L -o devspace https://github.com/loft-sh/devspace/releases/latest/download/devspace-linux-${TARGETARCH} \
    && install -c -m 0755 devspace /usr/local/bin \
    && rm devspace

# Create runner user and docker group
RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

WORKDIR /home/runner

# Copy actions-runner binaries from official image
COPY --from=runner-base --chown=runner:docker /home/runner /home/runner

# Copy docker buildx plugin
COPY --from=docker-base /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx

# Copy docker CLI binaries
COPY --from=docker-base /usr/local/bin/docker /usr/bin/docker

USER runner
