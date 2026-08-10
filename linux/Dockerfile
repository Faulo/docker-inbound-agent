FROM jenkins/inbound-agent:trixie-jdk21

ARG DEBIAN_FRONTEND=noninteractive
ARG DOCKER_MAJOR=29
ARG PLASTIC_MAJOR=11

# Jenkins
USER root
ENV USER=root \
    HOME=/root \
    AGENT_WORKDIR=/jenkins \
    JENKINS_AGENT_WORKDIR=/jenkins \
    JENKINS_WEB_SOCKET=true \
    JAVA_OPTS="-Dorg.jenkinsci.plugins.gitclient.Git.timeOut=60"
WORKDIR /jenkins
RUN mkdir -p /jenkins/workspace
VOLUME ["/jenkins/workspace"]

# Git
RUN git config --global --add safe.directory '*'

# Docker CLI
ENV DOCKER_HOST=unix:///var/run/docker.sock

# The remote index invalidates this layer when Docker publishes a release.
ADD https://download.docker.com/linux/static/stable/x86_64/ /tmp/docker-versions

RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends "docker-ce-cli=5:${DOCKER_MAJOR}.*" && \
    rm -f /tmp/docker-versions /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    docker --version | grep -E "^Docker version ${DOCKER_MAJOR}\."

# Unity Version Control
ADD https://www.plasticscm.com/plasticrepo/stable/debian/Packages /tmp/plastic-packages

RUN echo 'deb [trusted=yes allow-insecure=yes] https://www.plasticscm.com/plasticrepo/stable/debian ./' \
      > /etc/apt/sources.list.d/plasticscm.list && \
    apt-get update -o Acquire::AllowInsecureRepositories=true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
      "plasticscm-client-core=${PLASTIC_MAJOR}.*" && \
    rm -f /tmp/plastic-packages /etc/apt/sources.list.d/plasticscm.list && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    cm version | grep -E "^${PLASTIC_MAJOR}\."
