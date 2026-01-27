#!/bin/bash
#
# Exports the Visual Studio Code artifacts deployed to a specific folder, as a 1:1 copy. If the destination directory
# already exists it is removed. Run as './vscode-export-artifacts.sh <dest_dir>'.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################
# Deployment directory for the extensions for all Visual Studio Code instances.
readonly GLOBAL_DEPLOY_EXTENSIONS_DIR="${HOME}/.vscode-server/extensions";

# The destination directory where to export artifacts.
readonly DEST_DIR="${1:?A destination path where to export artifacts was not provided.}";
# The destination directory where to export scripts.
readonly DEST_SCRIPTS_DIR="${DEST_DIR}/scripts";
# The destination directory where to export extensions.
readonly DEST_EXTENSIONS_DIR="${DEST_DIR}/extensions";

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Exporting Visual Studio Code artifacts to '${DEST_DIR}'...";

# If the destination directory exists, remove it.
rm -rf "${DEST_DIR}";

# If the directory with extensions exists, copy it accross.
if [[ -d "${GLOBAL_DEPLOY_EXTENSIONS_DIR}" ]]; then
    echo "Exporting extensions from '${GLOBAL_DEPLOY_EXTENSIONS_DIR}' to '${DEST_EXTENSIONS_DIR}'...";
    
    # Create extensions directory.
    mkdir -p "${DEST_EXTENSIONS_DIR}";
    
    # Copy the extensions directory 1:1 to the destination.
    # NOTE: Visual Studio Code extensions do not have symbolic links that could break...
    cp -a "${GLOBAL_DEPLOY_EXTENSIONS_DIR}/." "${DEST_EXTENSIONS_DIR}/";
fi;

# Create directory with scripts.
mkdir -p "${DEST_SCRIPTS_DIR}";

# Copy relevant scripts.
for scriptName in \
    "vscode-deploy-code-server.sh" \
    "vscode-deploy-multi-root-workspace.sh" \
; do
    srcPath="/usr/local/bin/${scriptName}";
    destPath="${DEST_SCRIPTS_DIR}/${scriptName}";

    echo "Exporting script '${srcPath}' to '${destPath}'...";
    cp -a "${srcPath}" "${destPath}";
done;

echo "Exported Visual Studio Code artifacts to '${DEST_DIR}'.";
