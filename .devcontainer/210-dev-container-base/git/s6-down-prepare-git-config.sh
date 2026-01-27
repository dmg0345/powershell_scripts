#!/bin/bash
#
# s6-overlay down script for prepare Git configuration service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Destroying Git configuration at '${HOME}/.gitconfig'...";

# Ensure that if there is an existing configuration, it is removed.
rm -f "${HOME}/.gitconfig";
rm -f "${HOME}/.gitconfig.sign.key";

echo "Destroyed Git configuration at '${HOME}/.gitconfig'.";
