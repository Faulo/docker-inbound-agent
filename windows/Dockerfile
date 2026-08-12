ARG OS_BASE=ltsc2019
FROM jenkins/inbound-agent:jdk21-windowsservercore-${OS_BASE}

SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-NonInteractive", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG DOCKER_MAJOR=29
ARG PLASTIC_MAJOR=11
ARG POWERSHELL_VERSION=7.6.4
ARG POWERSHELL_SHA256=80832551c52809301e6071c8bac977beb5a2f1ec953eb4db9f94deb953333793

# Jenkins
USER ContainerAdministrator
ENV USER=ContainerAdministrator \
    HOME=C:/Users/ContainerAdministrator \
    AGENT_WORKDIR=C:/jenkins \
    JENKINS_AGENT_WORKDIR=C:/jenkins \
    JENKINS_WEB_SOCKET=true \
    JAVA_OPTS="-Dorg.jenkinsci.plugins.gitclient.Git.timeOut=60"
WORKDIR C:/jenkins
RUN New-Item -ItemType Directory -Path C:\\jenkins\\workspace -Force | Out-Null
VOLUME ["C:/jenkins/workspace"]

# Git
RUN git config --global --add safe.directory *

# PowerShell 7
# The ZIP package works on Server Core and avoids installer side effects.
RUN $archive = 'C:\\powershell.zip'; \
    $uri = 'https://github.com/PowerShell/PowerShell/releases/download/v' + $env:POWERSHELL_VERSION + '/PowerShell-' + $env:POWERSHELL_VERSION + '-win-x64.zip?download=1'; \
    curl.exe -fsSL -H 'Cache-Control: no-cache' $uri -o $archive; \
    if ($LASTEXITCODE -ne 0) { throw 'Failed to download PowerShell' }; \
    $actual = (Get-FileHash -Algorithm SHA256 $archive).Hash; \
    if ($actual -ne $env:POWERSHELL_SHA256) { throw ('PowerShell SHA-256 mismatch: ' + $actual) }; \
    $destination = 'C:\\Program Files\\PowerShell\\7'; \
    New-Item -ItemType Directory -Path $destination -Force | Out-Null; \
    Expand-Archive -LiteralPath $archive -DestinationPath $destination; \
    Remove-Item -LiteralPath $archive -Force; \
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
    [Environment]::SetEnvironmentVariable('PATH', $destination + ';' + $machinePath, [EnvironmentVariableTarget]::Machine); \
    $installedVersion = & "$destination\\pwsh.exe" -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'; \
    if ($LASTEXITCODE -ne 0 -or $installedVersion -ne $env:POWERSHELL_VERSION) { throw ('Unexpected PowerShell version: ' + $installedVersion) }; \
    $installedVersion

# Docker CLI
ENV DOCKER_HOST=npipe:////./pipe/docker_engine

ADD https://download.docker.com/win/static/stable/x86_64/ docker-versions.html

RUN $dockerPattern = 'docker-(?<version>' + $env:DOCKER_MAJOR + '\.\d+\.\d+)(?:-(?<revision>\d+))?\.zip'; \
    $dockerRelease = [regex]::Matches((Get-Content docker-versions.html -Raw), $dockerPattern) | \
      Sort-Object @{ Expression = { [version]$_.Groups['version'].Value } }, @{ Expression = { [int]$_.Groups['revision'].Value } } | \
      Select-Object -Last 1; \
    if (-not $dockerRelease) { throw ('No Docker ' + $env:DOCKER_MAJOR + ' release found') }; \
    $dockerVersion = $dockerRelease.Groups['version'].Value; \
    $dockerUrl = 'https://download.docker.com/win/static/stable/x86_64/' + $dockerRelease.Value; \
    curl.exe -fsSL $dockerUrl -o docker.zip; \
    if ($LASTEXITCODE -ne 0) { throw 'Failed to download Docker' }; \
    Expand-Archive -Path docker.zip -DestinationPath . -Force; \
    Remove-Item docker.zip,docker-versions.html -Force; \
    New-Item -ItemType Directory -Path 'C:\\Program Files\\Docker' -Force | Out-Null; \
    Move-Item -Path docker\\docker.exe -Destination 'C:\\Program Files\\Docker\\docker.exe'; \
    Remove-Item docker -Recurse -Force; \
    [Environment]::SetEnvironmentVariable('PATH', 'C:\\Program Files\\Docker;'+$env:PATH, [EnvironmentVariableTarget]::Machine); \
    $installedVersion = & 'C:\\Program Files\\Docker\\docker.exe' --version; \
    if ($LASTEXITCODE -ne 0 -or $installedVersion -notmatch ('^Docker version ' + [regex]::Escape($dockerVersion) + ',')) { throw ('Unexpected Docker version: ' + $installedVersion) }; \
    $installedVersion

# Unity Version Control
ADD https://www.plasticscm.com/plasticrepo/stable/debian/Packages plastic-packages

RUN $plasticPattern = '(?m)^Version:\s*(' + $env:PLASTIC_MAJOR + '\.\S+)\s*$'; \
    $plasticVersion = [regex]::Matches((Get-Content plastic-packages -Raw), $plasticPattern) | \
      ForEach-Object { $_.Groups[1].Value } | Sort-Object { [version]$_ } | Select-Object -Last 1; \
    if (-not $plasticVersion) { throw ('No Unity Version Control ' + $env:PLASTIC_MAJOR + ' release found') }; \
    $plasticUrl = 'https://www.plasticscm.com/download/downloadinstaller/' + $plasticVersion + '/plasticscm/windows/client?flags=None'; \
    curl.exe -fsSL $plasticUrl -o plastic-installer.exe; \
    if ($LASTEXITCODE -ne 0) { throw 'Failed to download Unity Version Control' }; \
    $signature = Get-AuthenticodeSignature plastic-installer.exe; \
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Unity Technologies') { throw 'Unity Version Control signature verification failed' }; \
    $process = Start-Process \
      -FilePath plastic-installer.exe \
      -ArgumentList '--mode unattended --unattendedmodeui none' \
      -Wait -NoNewWindow -PassThru; \
    if ($process.ExitCode -ne 0) { throw "Unity Version Control installer failed with exit code $($process.ExitCode)" }; \
    Remove-Item plastic-installer.exe,plastic-packages -Force; \
    $installedVersion = & 'C:\\Program Files\\PlasticSCM5\\client\\cm.exe' version; \
    if ($LASTEXITCODE -ne 0) { throw 'Unity Version Control smoke check failed' }; \
    if ($installedVersion -notmatch ('^' + [regex]::Escape($plasticVersion) + '(?:\s|$)')) { throw ('Unexpected Unity Version Control version: ' + $installedVersion) }; \
    $installedVersion
