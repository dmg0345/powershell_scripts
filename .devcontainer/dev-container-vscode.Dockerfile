# Dev Container with Visual Studio Code Dockerfile file, for details, refer to: 
#   - https://docs.docker.com/reference/dockerfile/

# syntax=docker/dockerfile:1
# escape=\

FROM docker.io/dmg00345/image-tools:1.0.0 AS dev-container-tools

# Deploy Visual Studio Code Server to preinstall extensions and export them.
RUN vscode-deploy-code-server.sh "latest";                                                                             \
    ## PowerShell related extensions ###################################################################################
    code-server --install-extension "ms-vscode.powershell@2025.4.0";                                                   \
    ## Git and Github related extensions ###############################################################################
    code-server --install-extension "phil294.git-log--graph@0.1.34";                                                   \
    code-server --install-extension "github.vscode-github-actions@0.30.0";                                             \
    ## Themes ##########################################################################################################
    code-server --install-extension "thetaylorlee.pwsh-theme-unofficial@3.3.0";                                        \
    ## Other ###########################################################################################################
    vscode-export-artifacts.sh "/output";

FROM docker.io/dmg00345/dev-container-base-debian-13-gui:1.0.0

# Deploy Visual Studio Code scripts in target.
COPY --from=dev-container-tools                                                                                        \
    "/output/scripts/"                                                                                                 \
    "/usr/local/bin/"

# Deploy Visual Studio Code extensions in target.
COPY --chown=devuser:devusers --from=dev-container-tools                                                               \
    "/output/extensions/"                                                                                              \
    "/home/devuser/.vscode-server/extensions/"

# Deploy workspace configuration in target.
RUN cat << 'EOF' | dos2unix >> "${DEV_CONTAINER_UP_SCRIPT_FILE}"
cd "$DEV_CONTAINER_VOLUME_DIR";

# Clone project if it does not exist, and create symbolic link to it from workspace directory.
if [[ ! -d "./powershell_scripts" ]]; then
    git clone --recurse-submodules git@github.com:dmg0345/powershell_scripts.git;
    ln -sf "/dev-container-volume/powershell_scripts" "/dev-container-volume/vscode-workspace";
fi;

EOF
