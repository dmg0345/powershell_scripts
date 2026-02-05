#!/bin/bash
#
# Deploys a Visual Studio Code multi-root workspace file. Run as './vscode-deploy-multi-root-workspace.sh <dir|cwd>'.
#
# 27/01/2026: Dev Containers do not work well with multi-root workspace.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################
# The directory where to deploy the multi-root workspace.
readonly DEST_DIR="${1:-$PWD}";
# The path to the multi-root workspace file to create.
readonly DEST_FILE="${DEST_DIR}/workspace.code-workspace";

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Installing Visual Studio Code multi-root workspace at '${DEST_DIR}'...";

# If the destination directory does not exist, then raise an error.
if [[ ! -d "${DEST_DIR}" ]]; then
    echo "Destination directory '${DEST_DIR}' does not exist." >&2;
    exit 1;
fi;

# If the file already exists, then skip and do nothing.
if [[ -f "${DEST_FILE}" ]]; then
    exit 0;
fi;

# If the workspace file already exists, delete it to start anew.
rm -f "${DEST_FILE}";
touch "${DEST_FILE}";

echo "{" >> "${DEST_FILE}";
echo "    \"folders\": [" >> "${DEST_FILE}";

# Loop directories at first level
itemCount=0
for dirPath in "${DEST_DIR}"/*/; do
    # Look for '.vscode' folder to consider it a subproject.
    [[ -d "$dirPath/.vscode" ]] || continue;

    # Check if closing a previous item.
    if [[ $itemCount -ne 0 ]]; then
        echo "        }," >> "${DEST_FILE}";
    fi;

    # Create item with 'path' element and add it.
    echo "        {" >> "${DEST_FILE}";
    echo "            \"path\": \"$(basename "$dirPath")\"" >> "${DEST_FILE}";

    # Increase number of items.
    itemCount=$(( itemCount + 1 ));
done;

# Add closure to last item, if any.
if [[ $itemCount -ne 0 ]]; then
    echo "        }" >> "${DEST_FILE}";
fi;

echo "    ]" >> "${DEST_FILE}";
echo "}" >> "${DEST_FILE}";

echo "Installed Visual Studio Code multi-root workspace at '${DEST_FILE}'.";
