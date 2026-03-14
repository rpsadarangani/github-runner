# GitHub Actions Self-Hosted Runner

Multi-arch Docker image for self-hosted GitHub Actions runners with DinD (Docker-in-Docker) support.

## What's included

| Tool | Source |
|------|--------|
| GitHub Actions Runner | [actions/runner](https://github.com/actions/runner) v2.332.0 |
| Docker CLI + Buildx | [docker:27.3.1-dind](https://hub.docker.com/_/docker) |
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
docker build -t github-runners:v2.332.0 .

# Multi-arch
docker buildx build --platform linux/amd64,linux/arm64 -t github-runners:v2.332.0 --push .
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

## CI

The GitHub Actions workflow builds and pushes the image to GHCR on every push to `main`. You can also trigger it manually with a custom runner version via **Actions > Run workflow**.

## Updating runner version

1. Update `RUNNER_VERSION` default in `.github/workflows/build-runner.yml`
2. Update the `FROM ghcr.io/actions/actions-runner:X.Y.Z` line in `Dockerfile`
3. Push to `main`

Or trigger the workflow manually with the desired version.
