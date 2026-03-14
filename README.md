# GitHub Actions Self-Hosted Runner

Multi-arch Docker image for self-hosted GitHub Actions runners with DinD (Docker-in-Docker) support. Automatically rebuilds when GitHub releases a new runner version.

## What's included

| Tool | Source |
|------|--------|
| GitHub Actions Runner | [actions/runner](https://github.com/actions/runner) (auto-updated) |
| Docker CLI + Buildx | [docker:27.3.1-cli](https://hub.docker.com/_/docker) |
| Helm | Latest via get-helm-3 |
| kubectl | Latest stable |
| DevSpace | Latest |
| Maven | Ubuntu package |
| AWS CLI | Ubuntu package |
| Build tools | build-essential, git, curl, jq, zip, unzip, openssh-client |

**Base:** Ubuntu 22.04
**Architectures:** linux/amd64, linux/arm64

## Usage

### Pull from GHCR

```bash
docker pull ghcr.io/rpsadarangani/github-runners:v2.332.0
```

### Build locally

```bash
# Single arch
docker build --build-arg RUNNER_VERSION=2.332.0 -t github-runners:v2.332.0 .

# Multi-arch
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg RUNNER_VERSION=2.332.0 \
  -t github-runners:v2.332.0 --push .
```

### Use with actions-runner-controller

This image is designed for [ARC (actions-runner-controller)](https://github.com/actions/actions-runner-controller) with DinD mode. Example runner scale set values:

```yaml
template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/rpsadarangani/github-runners:v2.332.0
        command: ["/home/runner/run.sh"]
        env:
          - name: DOCKER_HOST
            value: unix:///run/docker/docker.sock
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /run/docker
            readOnly: true
      - name: dind
        image: docker:27.3.1-dind
        args:
          - dockerd
          - --host=unix:///run/docker/docker.sock
          - --group=$(DOCKER_GROUP_GID)
        env:
          - name: DOCKER_GROUP_GID
            value: "123"
        securityContext:
          privileged: true
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /run/docker
          - name: dind-externals
            mountPath: /home/runner/externals
    initContainers:
      - name: init-dind-externals
        image: ghcr.io/rpsadarangani/github-runners:v2.332.0
        command: ["cp", "-r", "-v", "/home/runner/externals/.", "/home/runner/tmpDir/"]
        volumeMounts:
          - name: dind-externals
            mountPath: /home/runner/tmpDir
    volumes:
      - name: work
        emptyDir: {}
      - name: dind-sock
        emptyDir: {}
      - name: dind-externals
        emptyDir: {}
```

## CI / Automation

### How it works

A GitHub Actions workflow runs **every 6 hours** to check for new runner releases:

1. Fetches the latest version from [actions/runner releases](https://github.com/actions/runner/releases)
2. Checks if that version already exists in GHCR
3. If new version found, builds multi-arch image and pushes to GHCR
4. If version already exists, skips (completes in ~10s)

### Image tags

Each build produces three tags:

| Tag | Example | Description |
|-----|---------|-------------|
| `v{version}` | `v2.332.0` | Runner version |
| `v{version}-{date}` | `v2.332.0-20260314` | Version + build date |
| `latest` | `latest` | Most recent build |

### Triggers

| Trigger | Behavior |
|---------|----------|
| **Schedule** (every 6h) | Auto-detects latest version, builds only if new |
| **Push to main** | Always builds with latest version |
| **Manual dispatch** | Optionally override with a specific version |

### Deploying to a private registry

After a new image is built in GHCR, copy it to a private registry using [crane](https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md):

```bash
crane copy --platform all \
  ghcr.io/rpsadarangani/github-runners:v2.332.0 \
  <your-registry>/github-runners:v2.332.0
```

### Updating ARC runner sets via Helm

```bash
helm get values <release-name> -n <namespace> > values.yaml
# Update the runner image tag in values.yaml, then:
helm upgrade <release-name> \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  -n <namespace> -f values.yaml
```
