#!/bin/bash
#
# Deploys versions of Visual Studio Code Server in the environment. Allows to deploy multiple versions in the same
# environment. Run as './vscode-deploy-code-server.sh <version|latest>'.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################
# The Visual Studio Code Server version to install, provided as a command line argument.
readonly VSCODE_SERVER_VERSION="${1:-latest}";
# Deployment directory for the structure of the different instances of Visual Studio Code Server.
readonly GLOBAL_DEPLOY_DIR="${HOME}/.vscode-server";

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Installing Visual Studio Code Server '${VSCODE_SERVER_VERSION}'...";

# If the global installation directory does not exist, create structure.
if [[ ! -d "${GLOBAL_DEPLOY_DIR}" ]]; then
    mkdir -p "${GLOBAL_DEPLOY_DIR}";
    mkdir -p "${GLOBAL_DEPLOY_DIR}/bin";
fi;

# If using a specific version, attempt to query Git first to see if it exists.
if [[ "$VSCODE_SERVER_VERSION" != "latest" ]]; then
    # Fetch commit hash from the version provided.
    gitCommitHash="$(git ls-remote --tags --refs "https://github.com/microsoft/vscode.git" "refs/tags/${VSCODE_SERVER_VERSION}" | cut -f1)";

    # Ensure the a commit hash was found for the version provided.
    if [[ -z "$gitCommitHash" ]]; then
        echo "No commit hash found for Visual Studio Code Server version '${VSCODE_SERVER_VERSION}'." >&2;
        exit 1;
    fi;
fi;

# Download the Visual Studio Code Server version specified, for details refer to:
#   - https://gist.github.com/cvcore/8e187163f41a77f5271c26a870e52778
#   - https://github.com/microsoft/vscode/tags (commit for each version, alternatively, code --version)
curl -fLvo "${HOME}/vscode-server.tar.gz" "https://update.code.visualstudio.com/${VSCODE_SERVER_VERSION}/server-linux-x64/stable";

# Untar it to a temporary directory, if it already exists, remove it.
rm -rf "${HOME}/vscode-server-tmp";
mkdir -p "${HOME}/vscode-server-tmp";
tar -xzf "${HOME}/vscode-server.tar.gz" -C "${HOME}/vscode-server-tmp" --strip-components 1;

# Fetch version and commit hash from the command line for the downloaded files.
readarray -t outputLines < <("${HOME}/vscode-server-tmp/bin/code-server" --version);
dlVersion="${outputLines[0]}";
dlHash="${outputLines[1]}";

# Deploy instance, if the directory already exists, remove it.
instanceDeployDir="${GLOBAL_DEPLOY_DIR}/bin/${dlHash}";
rm -rf "${instanceDeployDir}";
mv "${HOME}/vscode-server-tmp" "${instanceDeployDir}";

# Create versioned symbolic link and last version deployed symbolic links.
ln -sf "${instanceDeployDir}/bin/code-server" "/usr/local/bin/code-server.${dlVersion}";
ln -sf "/usr/local/bin/code-server.${dlVersion}" "/usr/local/bin/code-server";

# Remove leftovers.
rm -f "${HOME}/vscode-server.tar.gz";

echo "Installed Visual Studio Code Server '${dlVersion} (${dlHash})' at '${instanceDeployDir}'...";
