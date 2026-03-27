FROM ubuntu:jammy AS build

ARG TARGETOS
ARG TARGETARCH
ARG RUNNER_VERSION=2.332.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.5.1
ARG DOCKER_VERSION=24.0.6
ARG BUILDX_VERSION=0.11.2

WORKDIR /actions-runner

RUN apt update -y && apt install curl unzip -y

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; elif [ "$RUNNER_ARCH" = "arm64" ]; then export RUNNER_ARCH=arm64 ; fi \
    && curl -fkLo runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${TARGETOS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

RUN curl -fkLo runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export DOCKER_ARCH=x86_64 ; fi \
    && if [ "$RUNNER_ARCH" = "arm64" ]; then export DOCKER_ARCH=aarch64 ; fi \
    && curl -fkLo docker.tgz https://download.docker.com/${TARGETOS}/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && rm -rf docker.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fkLo /usr/local/lib/docker/cli-plugins/docker-buildx \
        "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

FROM ubuntu:jammy

ARG TARGETOS
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

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

# Install helm (pinned version)
ARG HELM_VERSION=3.17.1
RUN curl -fksSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xz \
    && mv linux-${TARGETARCH}/helm /usr/local/bin/helm \
    && rm -rf linux-${TARGETARCH}

# Install kubectl
RUN curl -fkLO "https://dl.k8s.io/release/$(curl -fkLs https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install Devspace
RUN curl -fkLo devspace "https://github.com/loft-sh/devspace/releases/latest/download/devspace-linux-${TARGETARCH}" \
    && install -c -m 0755 devspace /usr/local/bin \
    && rm devspace

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

WORKDIR /home/runner

COPY --chown=runner:docker --from=build /actions-runner .
COPY --from=build /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx

RUN install -o root -g root -m 755 docker/* /usr/bin/ && rm -rf docker

USER runner
