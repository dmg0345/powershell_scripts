# Dev Container base image with Debian Dockerfile file, for details, refer to:
#   - https://docs.docker.com/reference/dockerfile/

# syntax=docker/dockerfile:1
# escape=\

# The Debian image with supervisor to use as a base for CLI / GUI images, provided from the Docker Bake file.
ARG BASE_IMAGE=arg-from/docker-bake:file-missing

# The stage to use as a base for CLI images, provided from the Docker Bake file.
ARG BASE_CLI_STAGE=arg-from/docker-bake:file-missing
# The stage to use as a base for GUI images, provided from the Docker Bake file.
ARG BASE_GUI_STAGE=arg-from/docker-bake:file-missing

## Debian 13 CLI Stage #################################################################################################
FROM ${BASE_IMAGE} AS debian-13-cli-stage

# Install common packages for CLI.
RUN apt-get --assume-yes update;                                                                                       \
    apt-get --assume-yes --show-progress --no-install-recommends install                                               \
    ## Git related packages ############################################################################################
    git=1:2.47.3-0+deb13u1                                                                                             \
    ## Bash related packages ###########################################################################################
    bash=5.2.37-2+b7                                                                                                   \
    shellcheck=0.10.0-1                                                                                                \
    shfmt=3.8.0-1+b8                                                                                                   \
    ## PowerShell related packages #####################################################################################
    libicu76=76.1-4                                                                                                    \
    ## Compression / Decompression related packages ####################################################################
    tar=1.35+dfsg-3.1                                                                                                  \
    xz-utils=5.8.1-1                                                                                                   \
    unzip=6.0-29                                                                                                       \
    lbzip2=2.5-4                                                                                                       \
    ## Network related packages ########################################################################################
    curl=8.14.1-2+deb13u2                                                                                              \
    ca-certificates=20250419                                                                                           \
    openssh-client=1:10.0p1-7                                                                                          \
    ## Other ###########################################################################################################
    dos2unix=7.5.2-1                                                                                                   \
    nano=8.4-1                                                                                                         \
    locales=2.41-12+deb13u1;                                                                                           \
                                                                                                                       \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf /var/lib/apt/lists/*;

## Debian 12 CLI Stage #################################################################################################
FROM ${BASE_IMAGE} AS debian-12-cli-stage

# Install common packages for CLI.
RUN apt-get --assume-yes update;                                                                                       \
    apt-get --assume-yes --show-progress --no-install-recommends install                                               \
    ## Git related packages ############################################################################################
    git=1:2.39.5-0+deb12u3                                                                                             \
    ## Bash related packages ###########################################################################################
    bash=5.2.15-2+b10                                                                                                  \
    shellcheck=0.9.0-1                                                                                                 \
    shfmt=3.6.0-1+b2                                                                                                   \
    ## PowerShell related packages #####################################################################################
    libicu72=72.1-3+deb12u1                                                                                            \
    ## Compression / Decompression related packages ####################################################################
    tar=1.34+dfsg-1.2+deb12u1                                                                                          \
    xz-utils=5.4.1-1                                                                                                   \
    unzip=6.0-28                                                                                                       \
    lbzip2=2.5-2.3                                                                                                     \
    ## Network related packages ########################################################################################
    curl=7.88.1-10+deb12u14                                                                                            \
    ca-certificates=20230311+deb12u1                                                                                   \
    openssh-client=1:9.2p1-2+deb12u7                                                                                   \
    ## Other ###########################################################################################################
    dos2unix=7.4.3-1                                                                                                   \
    nano=7.2-1+deb12u1                                                                                                 \
    locales=2.36-9+deb12u13;                                                                                           \
                                                                                                                       \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf /var/lib/apt/lists/*;

## Debian CLI Commons Stage ############################################################################################
FROM ${BASE_CLI_STAGE} AS debian-cli-commons-stage

# Additional Git configurations for all users, for details refer to:
#   - https://linuxhint.com/git-handle-symbolic-links/#3
#   - https://stackoverflow.com/questions/6842687/the-remote-end-hung-up-unexpectedly-while-git-cloning
#   - https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key
# This forces the signing of all commits and tags, user must provide 'user.name', 'user.email' and 'user.signingkey'.
RUN git config --system core.symlinks true;                                                                            \
    git config --system http.postBuffer 500M;                                                                          \
    git config --system http.maxRequestBuffer 100M;                                                                    \
    git config --system core.compression 0;                                                                            \
    git config --system gpg.format ssh;                                                                                \
    git config --system tag.gpgSign true;                                                                              \
    git config --system commit.gpgsign true;

# Additional nano configurations for all users, for details refer to:
#   - https://www.nano-editor.org/dist/v2.9/nanorc.5.html
RUN echo "set constantshow" >> "/etc/nanorc";                                                                          \
    echo "set indicator" >> "/etc/nanorc";                                                                             \
    echo "set linenumbers" >> "/etc/nanorc";                                                                           \
    echo "set tabsize 4" >> "/etc/nanorc";                                                                             \
    echo "set tabstospaces" >> "/etc/nanorc";

# PowerShell Core version, provided from the Docker Bake file.
ARG PWSH_VERSION=arg-from/docker-bake:file-missing

# Download and install PowerShell Core, for details refer to:
#   - https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian?view=powershell-7.5#installation-via-direct-download
RUN curl -fLvo "./pwsh.deb" "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell_${PWSH_VERSION}-1.deb_amd64.deb"; \
    apt-get --assume-yes update;                                                                                       \
    dpkg --install "./pwsh.deb";                                                                                       \
    apt-get --assume-yes --no-install-recommends --fix-broken install;                                                 \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf /var/lib/apt/lists/*;                                                                                       \
    rm -f "./pwsh.deb";

# To switch to PowerShell Core shell at any time in the build stage, use the following directive:
# SHELL ["/usr/bin/pwsh", "-Command", "$PSNativeCommandUseErrorActionPreference = $true; $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Download and install PowerShell Script Analyzer linter and formatter, for details refer to:
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules#installing-psscriptanalyzer
#   - https://www.powershellgallery.com/packages/PSScriptAnalyzer
#   - https://github.com/PowerShell/PSScriptAnalyzer
RUN pwsh -Command "Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.24.0 -Scope AllUsers -AcceptLicense";

# Make PowerShell Core shell the default shell for 'devuser'.
RUN chsh --shell /usr/bin/pwsh devuser;

# Ensure blank profile exists for PowerShell Core for the user created, for details refer to:
#   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.5#profile-types-and-locations
USER devuser
RUN mkdir -p "${HOME}/.config/powershell";                                                                             \
    rm -f "${HOME}/.config/powershell/profile.ps1";                                                                    \
    touch "${HOME}/.config/powershell/profile.ps1";                                                                    \
    chmod 0700 "${HOME}/.config/powershell/profile.ps1";
USER root

# Provision and install s6-overlay scripts for all users.
COPY --chown=root:root --chmod=0755 --from=host-dev-container-base-dir                                                 \
    "./s6-up-root-prepare-dev-container.sh"                                                                            \
    "./s6-down-root-prepare-dev-container.sh"                                                                          \
    "./s6-up-prepare-dev-container.sh"                                                                                 \
    "./s6-down-prepare-dev-container.sh"                                                                               \
    "./ssh/s6-up-prepare-ssh-config.sh"                                                                                \
    "./ssh/s6-down-prepare-ssh-config.sh"                                                                              \
    "./git/s6-up-prepare-git-config.sh"                                                                                \
    "./git/s6-down-prepare-git-config.sh"                                                                              \
    "/usr/local/bin/"

# Create service that prepares the SSH configuration.
RUN mkdir -p "/etc/s6-overlay/s6-rc.d/prepare-ssh-config";                                                             \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/prepare-ssh-config";                                                           \
    mkdir -p "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/dependencies.d";                                              \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/dependencies.d";                                            \
    ## Register Service to 'user' bundle of services
    touch "/etc/s6-overlay/s6-rc.d/user/contents.d/prepare-ssh-config";                                                \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/user/contents.d/prepare-ssh-config";                                           \
    ## One Shot Service
    echo "oneshot" > "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/type";                                                \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/type";                                                      \
    ## Depends On
    touch "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/dependencies.d/base";                                            \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/dependencies.d/base";                                       \
    ## Makes Depend On
    ## Up Script
    echo "exec with-contenv s6-setuidgid devuser s6-envdir /s6-devuser-env s6-up-prepare-ssh-config.sh" >> "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/up"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/up";                                                        \
    ## Down Script
    echo "exec with-contenv s6-setuidgid devuser s6-envdir /s6-devuser-env s6-down-prepare-ssh-config.sh" >> "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/down"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-ssh-config/down";

# Create service that prepares the Git configuration.
RUN mkdir -p "/etc/s6-overlay/s6-rc.d/prepare-git-config";                                                             \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/prepare-git-config";                                                           \
    mkdir -p "/etc/s6-overlay/s6-rc.d/prepare-git-config/dependencies.d";                                              \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/prepare-git-config/dependencies.d";                                            \
    ## Register Service to 'user' bundle of services
    touch "/etc/s6-overlay/s6-rc.d/user/contents.d/prepare-git-config";                                                \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/user/contents.d/prepare-git-config";                                           \
    ## One Shot Service
    echo "oneshot" > "/etc/s6-overlay/s6-rc.d/prepare-git-config/type";                                                \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-git-config/type";                                                      \
    ## Depends On
    touch "/etc/s6-overlay/s6-rc.d/prepare-git-config/dependencies.d/base";                                            \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-git-config/dependencies.d/base";                                       \
    ## Makes Depend On
    ## Up Script
    echo "exec with-contenv s6-setuidgid devuser s6-envdir /s6-devuser-env s6-up-prepare-git-config.sh" >> "/etc/s6-overlay/s6-rc.d/prepare-git-config/up"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-git-config/up";                                                        \
    ## Down Script
    echo "exec with-contenv s6-setuidgid devuser s6-envdir /s6-devuser-env s6-down-prepare-git-config.sh" >> "/etc/s6-overlay/s6-rc.d/prepare-git-config/down"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-git-config/down";

# Create service that prepares the Dev Container initialization.
RUN mkdir -p "/etc/s6-overlay/s6-rc.d/prepare-dev-container";                                                          \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/prepare-dev-container";                                                        \
    mkdir -p "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d";                                           \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d";                                         \
    ## Register Service to 'user' bundle of services
    touch "/etc/s6-overlay/s6-rc.d/user/contents.d/prepare-dev-container";                                             \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/user/contents.d/prepare-dev-container";                                        \
    ## One Shot Service
    echo "oneshot" > "/etc/s6-overlay/s6-rc.d/prepare-dev-container/type";                                             \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/type";                                                   \
    ## Depends On
    touch "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d/base";                                         \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d/base";                                    \
    touch "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d/prepare-ssh-config";                           \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d/prepare-ssh-config";                      \
    touch "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d/prepare-git-config";                           \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/dependencies.d/prepare-git-config";                      \
    ## Makes Depend On
    ## Up Script
    echo "exec with-contenv s6-up-root-prepare-dev-container.sh" > "/etc/s6-overlay/s6-rc.d/prepare-dev-container/up"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/up";                                                     \
    ## Down Script
    echo "exec with-contenv s6-down-root-prepare-dev-container.sh" > "/etc/s6-overlay/s6-rc.d/prepare-dev-container/down"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/prepare-dev-container/down";

# Export the paths to the up and down scripts so that end user can write to them directly.
ENV DEV_CONTAINER_UP_SCRIPT_FILE=/usr/local/bin/s6-up-prepare-dev-container.sh
ENV DEV_CONTAINER_DOWN_SCRIPT_FILE=/usr/local/bin/s6-down-prepare-dev-container.sh

## Debian 13 CLI Image #################################################################################################
FROM debian-cli-commons-stage AS debian-13-cli-image

## Debian 12 CLI Image #################################################################################################
FROM debian-cli-commons-stage AS debian-12-cli-image

## Debian 13 GUI Stage #################################################################################################
FROM debian-13-cli-image AS debian-13-gui-stage

# Install minimal packages to provide a Window Manager over VNC, for details refer to:
#   - https://manpages.debian.org/trixie/tigervnc-standalone-server/tigervncserver.1.en.html
# Note that some additional utilities are added on top of window manager for convenience.
RUN apt-get --assume-yes update;                                                                                       \
    apt-get --assume-yes --show-progress --no-install-recommends install                                               \
    ## VNC Server related packages #####################################################################################
    tigervnc-standalone-server=1.15.0+dfsg-2                                                                           \
    tigervnc-tools=1.15.0+dfsg-2                                                                                       \
    ## Window Manager and GUI related packages #########################################################################
    icewm=3.7.4-1                                                                                                      \
    xfce4-terminal=1.1.4-1                                                                                             \
    thunar=4.20.2-1+deb13u1                                                                                            \
    mousepad=0.6.3-1                                                                                                   \
    gnome-icon-theme=3.12.0-6                                                                                          \
    xfonts-base=1:1.0.5+nmu1                                                                                           \
    ## Settings CLI related packages ###################################################################################
    dconf-cli=0.40.0-5                                                                                                 \
    xfconf=4.20.0-1                                                                                                    \
    ## Other ###########################################################################################################
    dbus-daemon=1.16.2-2                                                                                               \
    xdg-utils=1.2.1-2;                                                                                                 \
                                                                                                                       \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf "/var/lib/apt/lists/*";

# Copy relevant default GUI configurations for image to temporary folder.
COPY --chown=root:root --chmod=0644 --from=host-dev-container-base-dir                                                 \
    "./vnc/icewm/icewm-config/menu"                                                                                    \
    "./vnc/icewm/icewm-config/programs"                                                                                \
    "./vnc/icewm/icewm-config/theme"                                                                                   \
    "./vnc/icewm/icewm-config/toolbar"                                                                                 \
    "./vnc/icewm/icewm-config/Spoof-IceWM-3-8-Mods.tar.gz"                                                             \
    "./vnc/icewm/thunar-config/4.20.2/thunar.xml"                                                                      \
    "./vnc/icewm/xfce4-terminal-config/1.1.4/xfce4-terminal.xml"                                                       \
    "./vnc/icewm/mousepad-config/0.6.3/00-mousepad-dconf"                                                              \
    "/tmp-gui-configs/"

## Debian 12 GUI Stage #################################################################################################
FROM debian-12-cli-image AS debian-12-gui-stage

# Install minimal packages to provide a Window Manager over VNC, for details refer to:
#   - https://manpages.debian.org/bookworm/tigervnc-standalone-server/tigervncserver.1.en.html
# Note that some additional utilities are added on top of window manager for convenience.
RUN apt-get --assume-yes update;                                                                                       \
    apt-get --assume-yes --show-progress --no-install-recommends install                                               \
    ## VNC Server related packages #####################################################################################
    tigervnc-standalone-server=1.12.0+dfsg-8                                                                           \
    tigervnc-tools=1.12.0+dfsg-8                                                                                       \
    ## Window Manager and GUI related packages #########################################################################
    icewm=3.3.1-1                                                                                                      \
    xfce4-terminal=1.0.4-1                                                                                             \
    thunar=4.18.4-1                                                                                                    \
    mousepad=0.5.10-2                                                                                                  \
    gnome-icon-theme=3.12.0-5                                                                                          \
    xfonts-base=1:1.0.5+nmu1                                                                                           \
    ## Settings CLI related packages ###################################################################################
    dconf-cli=0.40.0-4                                                                                                 \
    xfconf=4.18.0-2                                                                                                    \
    ## Other ###########################################################################################################
    dbus-daemon=1.14.10-1~deb12u1                                                                                      \
    xdg-utils=1.1.3-4.1;                                                                                               \
                                                                                                                       \
    apt-get --assume-yes clean;                                                                                        \
    apt-get --assume-yes autoremove;                                                                                   \
    rm -rf "/var/lib/apt/lists/*";

# Copy relevant default GUI configurations for image to temporary folder.
COPY --chown=root:root --chmod=0644 --from=host-dev-container-base-dir                                                 \
    "./vnc/icewm/icewm-config/menu"                                                                                    \
    "./vnc/icewm/icewm-config/programs"                                                                                \
    "./vnc/icewm/icewm-config/theme"                                                                                   \
    "./vnc/icewm/icewm-config/toolbar"                                                                                 \
    "./vnc/icewm/icewm-config/Spoof-IceWM-3-8-Mods.tar.gz"                                                             \
    "./vnc/icewm/thunar-config/4.18.4/thunar.xml"                                                                      \
    "./vnc/icewm/xfce4-terminal-config/1.0.4/terminalrc"                                                               \
    "./vnc/icewm/xfce4-terminal-config/1.0.4/xfce4-terminal.xml"                                                       \
    "./vnc/icewm/mousepad-config/0.5.10/00-mousepad-dconf"                                                             \
    "/tmp-gui-configs/"

## Debian GUI Commons Stage ############################################################################################
FROM ${BASE_GUI_STAGE} AS debian-gui-commons-stage

# Ensure there is 'dconf' and 'xfconf' infrastructure for system settings for all users, for details refer to:
#   - https://ice-wm.org/manual/ (Resource Path)
#   - https://manpages.debian.org/testing/dconf-cli/dconf.7.en.html#PROFILES
#   - https://forum.xfce.org/viewtopic.php?id=16398
# NOTE: The approach is read only defaults at system level that can be overwritten at the user level.
RUN mkdir -p "/etc/dconf/profile";                                                                                     \
    mkdir -p "/etc/dconf/db/local.d";                                                                                  \
    echo "user-db:user" > "/etc/dconf/profile/user";                                                                   \
    echo "system-db:local" >> "/etc/dconf/profile/user";                                                               \
    mkdir -p "/etc/xdg/xfce4/xfconf/xfce-perchannel-xml";

# Provision and install IceWM themes and configuration for all users, for details refer to:
#   - https://ice-wm.org/manual/icewm-8.html
RUN cp -a                                                                                                              \
    "/tmp-gui-configs/menu"                                                                                            \
    "/tmp-gui-configs/programs"                                                                                        \
    "/tmp-gui-configs/theme"                                                                                           \
    "/tmp-gui-configs/toolbar"                                                                                         \
    "/usr/share/icewm/";                                                                                               \
    tar -xzf "/tmp-gui-configs/Spoof-IceWM-3-8-Mods.tar.gz" -C "/usr/share/icewm/themes/";

# Provision and install default system 'xfconf' configurations for all users.
RUN cp -a                                                                                                              \
    "/tmp-gui-configs/thunar.xml"                                                                                      \
    "/tmp-gui-configs/xfce4-terminal.xml"                                                                              \
    "/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/";

# Some versions of 'xfce4-terminal', (<=1.0) do not use 'xfconf', provision 'terminalrc', for details refer to:
#    - https://forum.xfce.org/viewtopic.php?pid=74569#p74569
RUN if [[ -f "/tmp-gui-configs/terminalrc" ]]; then                                                                    \
        mkdir -p "/etc/xdg/xfce4/terminal"; cp -a "/tmp-gui-configs/terminalrc" "/etc/xdg/xfce4/terminal/";            \
    fi;

# Provision and install default system 'dconf' configurations for all users, and afterwards update databases.
RUN cp -a                                                                                                              \
    "/tmp-gui-configs/00-mousepad-dconf"                                                                               \
    "/etc/dconf/db/local.d/";                                                                                          \
    dconf update;

# Delete temporary directory with GUI configurations ocne finished.
RUN rm -rf "/tmp-gui-configs";

# Provision and install s6-overlay scripts for all users.
COPY --chown=root:root --chmod=0755 --from=host-dev-container-base-dir                                                 \
    "./vnc/s6-run-vnc-server.sh"                                                                                       \
    "./vnc/s6-finish-vnc-server.sh"                                                                                    \
    "./vnc/tigervnc-xstartup.sh"                                                                                       \
    "/usr/local/bin/"

# Create service that runs the VNC server.
RUN mkdir -p "/etc/s6-overlay/s6-rc.d/vnc-server";                                                                     \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/vnc-server";                                                                   \
    mkdir -p "/etc/s6-overlay/s6-rc.d/vnc-server/dependencies.d";                                                      \
    chmod 0700 "/etc/s6-overlay/s6-rc.d/vnc-server/dependencies.d";                                                    \
    ## Register Service to 'user' bundle of services
    touch "/etc/s6-overlay/s6-rc.d/user/contents.d/vnc-server";                                                        \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/user/contents.d/vnc-server";                                                   \
    ## Long Running Service
    echo "longrun" > "/etc/s6-overlay/s6-rc.d/vnc-server/type";                                                        \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/vnc-server/type";                                                              \
    ## Depends On
    touch "/etc/s6-overlay/s6-rc.d/vnc-server/dependencies.d/prepare-dev-container";                                   \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/vnc-server/dependencies.d/prepare-dev-container";                              \
    ## Makes Depend On
    ## Run Script
    echo "#!/command/with-contenv /bin/bash" > "/etc/s6-overlay/s6-rc.d/vnc-server/run";                               \
    echo "set -euo pipefail" >> "/etc/s6-overlay/s6-rc.d/vnc-server/run";                                              \
    echo "exec s6-setuidgid devuser s6-envdir /s6-devuser-env s6-run-vnc-server.sh" >> "/etc/s6-overlay/s6-rc.d/vnc-server/run"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/vnc-server/run";                                                               \
    ## Finish Script
    echo "#!/command/with-contenv /bin/bash" > "/etc/s6-overlay/s6-rc.d/vnc-server/finish";                            \
    echo "set -euo pipefail" >> "/etc/s6-overlay/s6-rc.d/vnc-server/finish";                                           \
    echo "exec s6-setuidgid devuser s6-envdir /s6-devuser-env s6-finish-vnc-server.sh" >> "/etc/s6-overlay/s6-rc.d/vnc-server/finish"; \
    chmod 0600 "/etc/s6-overlay/s6-rc.d/vnc-server/finish";

## Debian 13 GUI Image #################################################################################################
FROM debian-gui-commons-stage AS debian-13-gui-image

## Debian 12 GUI Image #################################################################################################
FROM debian-gui-commons-stage AS debian-12-gui-image
