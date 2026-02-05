# Image base with Debian Dockerfile file, for details, refer to: 
#   - https://docs.docker.com/reference/dockerfile/

# syntax=docker/dockerfile:1
# escape=\

# The official Debian image to use as a base for USV and SVR, provided from the Docker Bake file.
ARG BASE_IMAGE=arg-from/docker-bake:file-missing

# The stage to use as a base for USV images, provided from the Docker Bake file.
ARG BASE_USV_STAGE=arg-from/docker-bake:file-missing
# The stage to use as a base for SVR images, provided from the Docker Bake file.
ARG BASE_SVR_STAGE=arg-from/docker-bake:file-missing

## Debian 13 USV Stage #################################################################################################
FROM ${BASE_IMAGE} AS debian-13-usv-stage

## Debian 12 USV Stage #################################################################################################
FROM ${BASE_IMAGE} AS debian-12-usv-stage

## Debian USV Commons Stage ############################################################################################
FROM ${BASE_USV_STAGE} AS debian-usv-commons-stage

# Ensure root user is selected.
USER root
# Ensure working from a known working directory.
WORKDIR "/"
# Ensure a Bash shell that stops on first error found.
SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

# Ensure locales are properly configured for all users, for details refer to:
#   - https://stackoverflow.com/a/41797247
#   - https://wiki.debian.org/Locale
#   - https://hub.docker.com/_/debian#locales
ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
ENV LC_ALL=C.UTF-8

# Pre-configure apt-get for all images. Do not upgrade base image packages for reproducibility. For details refer to:
#   - https://packages.debian.org/index
#   - https://manpages.debian.org/trixie/apt/apt-get.8.en.html
#   - https://docs.docker.com/develop/develop-images/dockerfile_best-practices/ (apt-get)
#   - https://askubuntu.com/questions/875213/apt-get-to-retry-downloading (apt-get retries)
# It is possible that Dockerfiles breas over time as pinned versions for packages might be deprecated and not exist
# anymore when updates or upgrades are released, in this scenario, the pinned package versions will need to be updated.
RUN echo 'Acquire::Retries "6";' > /etc/apt/apt.conf.d/80-retries;

# Create user named 'devuser' in primary group 'devusers', with a default Bash shell, for details refer to:
#   - https://askubuntu.com/a/878705.
# NOTE: 'devuser:1000' user and 'devusers:1000' users should not be changed, these values should be considered fixed.
RUN groupadd --gid 1000 devusers;                                                                                      \
    useradd --create-home --uid 1000 --gid 1000 --shell /bin/bash devuser;

# Ensure blank profile exists for Bash terminal for the user created, for details refer to:
#   - https://manpages.debian.org/trixie/bash/bash.1.en.html#FILES
USER devuser
RUN rm -f "${HOME}/.bashrc";                                                                                           \
    touch "${HOME}/.bashrc";                                                                                           \
    chmod 0700 "${HOME}/.bashrc";
USER root

## Debian 13 USV Image #################################################################################################
FROM debian-usv-commons-stage AS debian-13-usv-image

## Debian 12 USV Image #################################################################################################
FROM debian-usv-commons-stage AS debian-12-usv-image

## Debian SVR Commons Stage ############################################################################################
FROM ${BASE_SVR_STAGE} AS debian-svr-commons-stage

# s6-overlay version, provided from the Docker Bake file.
ARG S6_OVERLAY_VERSION=arg-from/docker-bake:file-missing

# Download and install s6-overlay (requires xz-utils temporarily). For usage details refer to:
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#installation
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#releases
#   - https://skarnet.org/software/s6-rc/s6-rc-compile.html#source (details of all the files involved)
# For creation of 'longrun' services, start and finish scripts refer to:
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#writing-a-service-script
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#writing-an-optional-finish-script
# For creation of 'oneshot' services, up and down files refer to:
#   - https://github.com/just-containers/s6-overlay/blob/master/MOVING-TO-V3.md#service-management-related-changes
# For the topic of dropping privileges from root to another non-root user refer to:
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#dropping-privileges
#   - https://github.com/just-containers/s6-overlay/issues/491#issuecomment-1300464835 (su vs s6-setuidgid)
#   - https://github.com/just-containers/s6-overlay/issues/165#issuecomment-241183921 (on usage of USER / HOME etc)
# Regarding the usage of container environment variables in scripts, refer to:
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#container-environment
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#customizing-s6-overlay-behaviour (S6_KEEP_ENV=0)
#   - https://github.com/just-containers/s6-overlay/issues/588#issuecomment-2249017145 (append custom variables)
ADD "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"  \
    "/s6-overlay-noarch.tar.xz"
ADD "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz"  \
    "/s6-overlay-x86_64.tar.xz"
RUN apt-get --assume-yes update;                                                                                       \
    apt-get --assume-yes --show-progress --no-install-recommends install xz-utils;                                     \
    tar -Jxpf "./s6-overlay-noarch.tar.xz" -C "/";                                                                     \
    tar -Jxpf "./s6-overlay-x86_64.tar.xz" -C "/";                                                                     \
    rm -f "./s6-overlay-noarch.tar.xz";                                                                                \
    rm -f "./s6-overlay-x86_64.tar.xz";                                                                                \
    apt-get --assume-yes purge xz-utils;                                                                               \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf /var/lib/apt/lists/*;

# Provision custom s6 environment directories with user environment variables that can be appended in services.
RUN mkdir -p "/s6-devuser-env";                                                                                        \
    echo "devuser" > "/s6-devuser-env/USER";                                                                           \
    echo "devuser" > "/s6-devuser-env/LOGNAME";                                                                        \
    echo "/home/devuser" > "/s6-devuser-env/HOME";

# Set the entry point to container to s6-overlay supervisor. Once started, the container will not finish unless stopped.
# NOTE: The entry must not be changed, thus beware of ENTRYPOINT and CMD directives, for details refer to:
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#usage
# NOTE: Note that the supervisor must run as 'root' user, thus beware of USER directives, for details refer to:
#   - https://github.com/just-containers/s6-overlay?tab=readme-ov-file#user-directive
ENTRYPOINT ["/init"]

## Debian 13 SVR Image #################################################################################################
FROM debian-svr-commons-stage AS debian-13-svr-image

## Debian 12 SVR Image #################################################################################################
FROM debian-svr-commons-stage AS debian-12-svr-image
