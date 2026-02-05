#!/bin/bash
#
# s6-overlay finish script for VNC server service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Ensure all active VNC sessions for user, if any, are terminated and cleaned.
tigervncserver -kill ":*" -clean || true;
# Ensure all stale VNC sessions for user, if any, are cleaned.
tigervncserver -list ":*" -cleanstale || true;
