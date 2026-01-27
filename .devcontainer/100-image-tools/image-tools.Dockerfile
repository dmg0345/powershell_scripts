# Image tools Dockerfile file, for details, refer to: 
#   - https://docs.docker.com/reference/dockerfile/

# syntax=docker/dockerfile:1
# escape=\

FROM docker.io/debian:13.3-slim

# Ensure root user is selected during the build phase.
USER root
# Ensure working from a known working directory.
WORKDIR "/"
# Ensure a Bash shell that stops on first error found.
SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

# Install minimal dependencies.
RUN apt-get --assume-yes update;                                                                                       \
    apt-get --assume-yes --show-progress --no-install-recommends install                                               \
    git                                                                                                                \
    bash                                                                                                               \
    tar                                                                                                                \
    ca-certificates                                                                                                    \
    curl;                                                                                                              \
                                                                                                                       \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf /var/lib/apt/lists/*;

# Provision scripts from build context in '/usr/local/bin'.
COPY --chown=root:root --chmod=0755 --from=host-image-tools-dir                                                        \
    "./vscode/vscode-deploy-code-server.sh"                                                                            \
    "./vscode/vscode-deploy-multi-root-workspace.sh"                                                                   \
    "./vscode/vscode-export-artifacts.sh"                                                                              \
    "/usr/local/bin/"
