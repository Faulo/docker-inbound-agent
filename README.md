# Cross-platform Jenkins inbound agent

This repository builds Linux and Windows variants of one Docker image for
Jenkins agents. Both variants extend the official
[`jenkins/inbound-agent`](https://hub.docker.com/r/jenkins/inbound-agent)
image and use Java 21.

The image is intended for Jenkins jobs that need Git, Unity Version Control
(the `cm` command), and access to a Docker daemon supplied by the host. It does
not run a Docker daemon of its own.

## Image variants

| Variant | Dockerfile | Base image | Docker context |
| --- | --- | --- | --- |
| Linux | `linux/Dockerfile` | `jenkins/inbound-agent:latest-jdk21` | `linux` |
| Windows | `windows/Dockerfile` | `jenkins/inbound-agent:jdk21-windowsservercore-ltsc2019` | `windows` |

The variants share the same core purpose, but their installed tools are not
currently identical:

| Capability | Linux | Windows |
| --- | --- | --- |
| Jenkins inbound-agent runtime | Yes | Yes |
| Java 21 | Yes | Yes |
| Git and Git LFS | Yes | Yes |
| Unity Version Control CLI (`cm`) | Core client package | Cloud Edition installer |
| Docker CLI | Docker APT repository | Pinned static archive |
| Docker Compose | Yes | No |
| Additional command-line tools | `curl`, `wget`, `zip`, `unzip`, `nano`, `pciutils`, `tini` | `curl.exe` from Windows |

The Linux container connects to
`unix:///var/run/docker.sock`. The Windows container connects to
`npipe:////./pipe/docker_engine`. The matching socket or named pipe must be
made available when the container is started.

## Prerequisites

- A Docker client on the host.
- A Linux Docker daemon available through the `linux` Docker context.
- A Windows Docker daemon available through the `windows` Docker context.
- A Windows host version compatible with the
  `windowsservercore-ltsc2019` base image when building or running the Windows
  variant.

Check the daemons before building:

```text
docker --context linux info
docker --context windows info
```

The commands must report `linux` and `windows`, respectively.

## Build

The project configuration in `.env` sets the image name. With the repository's
default configuration, local builds are tagged as
`tmp/inbound-agent:latest`.

Build directly from the repository root:

```text
docker --context linux build --tag tmp/inbound-agent:latest --file linux/Dockerfile linux
docker --context windows build --tag tmp/inbound-agent:latest --file windows/Dockerfile windows
```

On Windows, the following interactive entry points provide the same builds and
pause before closing so their output remains visible:

- `docker-build-linux.bat`
- `docker-build-windows.bat`

The shared `docker-build.bat` script accepts `linux` or `windows` as its first
argument. When called without an argument, it builds for the active Docker
daemon.

## Test

The root `.env` defines the local image name, test command, shared run options,
and platform-specific run options. The checked-in test currently verifies that
Java starts successfully.

Run the configured test through:

- `docker-test-linux.bat`
- `docker-test-windows.bat`

The shared `docker-test.bat` script also accepts `linux` or `windows` as its
first argument. The platform-specific run options are where the Docker socket
or named pipe and any required environment are supplied.

Do not commit credentials to `.env`. Treat access to a host Docker socket or
named pipe as privileged access to that Docker daemon.

## Use with Jenkins

Start the image using the same connection arguments or environment variables
supported by the upstream `jenkins/inbound-agent` image. Jenkins commonly
provides the controller URL, agent name, and agent secret when configuring an
inbound agent.

In addition to the Jenkins connection settings, mount the platform's Docker
endpoint if jobs need to invoke Docker. Any job using this image can then use
the host daemon through the included Docker CLI.

Refer to the
[`jenkins/inbound-agent` documentation](https://github.com/jenkinsci/docker-agent)
for the supported Jenkins connection modes and launch examples.

## Runtime defaults and security

- Linux processes run as `root`; Windows processes run as
  `ContainerAdministrator`.
- `JAVA_OPTS` disables the Jenkins directory browser Content Security Policy.
  This supports trusted build artifacts that contain active content, but it
  weakens browser-side protection.
- The Linux Plastic package repository is currently configured as trusted and
  permits an unauthenticated package install.
- The Linux Docker client follows the current stable APT repository version.
  The Windows Docker client is pinned in its Dockerfile.

These defaults are suitable only for trusted Jenkins workloads and should be
reviewed before exposing agents to untrusted jobs.

## Automation

The GitHub Actions workflow publishes the configured image through the shared
`Faulo/workflows-docker` workflow. It runs when either Dockerfile changes, can
be started manually, and runs monthly to pick up refreshed base images and
unpinned dependencies.
