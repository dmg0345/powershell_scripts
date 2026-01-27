#!/bin/bash
#
# s6-overlay root user down script for prepare dev container service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

# If there is a user script execute it.
if [[ -f "${DEV_CONTAINER_DOWN_SCRIPT_FILE}" ]]; then
    exec s6-setuidgid devuser s6-envdir /s6-devuser-env "${DEV_CONTAINER_DOWN_SCRIPT_FILE}"
fi;
