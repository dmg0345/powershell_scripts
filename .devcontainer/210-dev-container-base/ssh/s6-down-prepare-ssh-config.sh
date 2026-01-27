#!/bin/bash
#
# s6-overlay down script for prepare SSH configuration service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Destroying SSH configuration at '${HOME}/.ssh'...";

# Ensure that if there is an existing configuration, it is removed.
rm -rf "${HOME}/.ssh";

echo "Destroyed SSH configuration at '${HOME}/.ssh'.";
