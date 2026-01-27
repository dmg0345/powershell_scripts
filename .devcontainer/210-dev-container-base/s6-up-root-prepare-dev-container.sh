#!/bin/bash
#
# s6-overlay root user up script for prepare dev container service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

# If there is a dev container volume, set correct permissions for the dev user.
if [[ -d "${DEV_CONTAINER_VOLUME_DIR}" ]]; then
    chmod 0755 "${DEV_CONTAINER_VOLUME_DIR}";
    chown devuser:devusers "${DEV_CONTAINER_VOLUME_DIR}";
fi;

# If there is a user script execute it.
if [[ -f "${DEV_CONTAINER_UP_SCRIPT_FILE}" ]]; then
    exec s6-setuidgid devuser s6-envdir /s6-devuser-env "${DEV_CONTAINER_UP_SCRIPT_FILE}"
fi;
