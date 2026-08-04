# Cross-platform Jenkins inbound agent

This repository builds Linux and Windows variants of one Docker image for
Jenkins agents. Both variants extend the official
[`jenkins/inbound-agent`](https://hub.docker.com/r/jenkins/inbound-agent)
image and use Java 21.

The image is intended for Jenkins jobs that need Git, Unity Version Control
(the `cm` command), and access to a Docker daemon supplied by the host. This
includes Jenkinsfiles that use the Docker Pipeline plugin's
`docker.image("image").inside { ... }` syntax. The image contains only the
Docker client; it does not contain or run a Docker daemon.

## Image variants

| Variant | Dockerfile | Base image | Docker context |
| --- | --- | --- | --- |
| Linux | `linux/Dockerfile` | `jenkins/inbound-agent:trixie-jdk21` | `linux` |
| Windows | `windows/Dockerfile` | `jenkins/inbound-agent:jdk21-windowsservercore-ltsc2019` | `windows` |

Both variants provide the same agent-level capabilities:

| Capability | Linux | Windows |
| --- | --- | --- |
| Jenkins inbound-agent runtime | Yes | Yes |
| Java 21 | Yes | Yes |
| Git and Git LFS | Yes | Yes |
| Unity Version Control 11 CLI (`cm`) | Core client package | Client installer |
| Docker CLI 29 | Client binary only | Client binary only |

Docker Compose is intentionally not installed. The Jenkins Docker Pipeline
plugin uses the Docker CLI directly and does not require Compose for
`docker.image(...).inside { ... }`.

Both Dockerfiles follow Docker major version 29 and Unity Version Control major
version 11. Each platform resolves and installs its newest available release in
that major line during the build. Linux and Windows versions can differ when a
release is not yet available for both platforms, but neither image silently
upgrades to a new major version.

Remote package indexes are explicit Dockerfile inputs, so publishing a new
compatible release invalidates the installation layer even when a previous
build cache is available. Both variants currently target x86-64 hosts.

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
Java starts successfully and reports its version. The shared test runner
executes the command through the platform's shell so the same command works
with both upstream agent entrypoints.

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

For `docker.image(...).inside { ... }`, the Jenkins agent and Docker daemon
must also see the same workspace filesystem. Jenkins detects that the agent is
running in a container and uses `--volumes-from` to share its workspace with
the nested build container.

Configure the Jenkins node's **Remote root directory** to match the image:

| Variant | Remote root | Job workspace root |
| --- | --- | --- |
| Linux | `/jenkins` | `/jenkins/workspace` |
| Windows | `C:\jenkins` | `C:\jenkins\workspace` |

Both `AGENT_WORKDIR` image metadata and the inbound launcher's
`JENKINS_AGENT_WORKDIR` are set to the corresponding remote root. The
`workspace` directory is deliberately a child of that root and is the path to
mount when workspace persistence or host access is required.

Refer to the
[`jenkins/inbound-agent` documentation](https://github.com/jenkinsci/docker-agent)
for the supported Jenkins connection modes and launch examples.

## Runtime defaults and security

- Linux processes run as `root`; Windows processes run as
  `ContainerAdministrator`.
- `JAVA_OPTS` sets the Jenkins Git client operation timeout to 60 minutes.
- Git treats every repository path as a safe directory. This avoids ownership
  checks for host-mounted workspaces but removes that Git security boundary.
- Linux installs Docker from Docker's signed APT repository. The Windows Unity
  Version Control installer must have a valid Unity Authenticode signature.
- The Linux Unity Version Control repository currently requires an
  unauthenticated APT install because its legacy repository signature is
  rejected by current Debian policy.

These defaults are suitable only for trusted Jenkins workloads and should be
reviewed before exposing agents to untrusted jobs.

## Automation

The GitHub Actions workflow publishes the configured image through the shared
`Faulo/workflows-docker` workflow. It runs when either Dockerfile changes, can
be started manually, and runs monthly to pick up refreshed base images.

The shared workflow persists Linux BuildKit layers in the GitHub Actions cache.
For Windows, it pulls the previously published platform image and passes it to
Docker as the build cache source. Local Docker builds use each context's normal
layer cache automatically.
