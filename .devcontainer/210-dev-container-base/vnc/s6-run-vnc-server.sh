#!/bin/bash
#
# s6-overlay run script for VNC server service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################
# The display string to pass to VNC server, defaults to ':1'.
readonly SERVER_DISPLAY="${VNC_SERVER_DISPLAY:-":1"}";
# The VNC user password, defaults to the username.
readonly SERVER_PASSWORD="${VNC_SERVER_PASSWORD:-"${USER}"}";
# The identifier for the geometry, defaults to '1920x1080'.
readonly SERVER_GEOMETRY="${VNC_SERVER_GEOMETRY:-"1920x1080"}";

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Perform cleanup for all running user relevant files prior to starting session, for details regarding the files:
#   - https://manpages.debian.org/trixie/xserver-common/Xserver.1.en.html#FILES
#   - https://manpages.debian.org/trixie/xauth/xauth.1.en.html#FILES
#   - https://manpages.debian.org/trixie/tigervnc-standalone-server/tigervncserver.1.en.html#FILES
#   - https://manpages.debian.org/trixie/tigervnc-standalone-server/tigervncserver.1.en.html#clean
#   - https://manpages.debian.org/trixie/tigervnc-standalone-server/tigervncserver.1.en.html#cleanstale
tigervncserver -kill ":*" -clean || true;
tigervncserver -list ":*" -cleanstale || true;

# Ensure the configuration folder exists for the user.
mkdir -p "${HOME}/.config/tigervnc";

# Ensure password is provisioned.
rm -f "${HOME}/.config/tigervnc/passwd";
echo "${SERVER_PASSWORD}" | tigervncpasswd -f > "${HOME}/.config/tigervnc/passwd";

# Start server in the foreground for port 5900 + DISPLAY_NUMBER, for a unique user, the one running the service.
# NOTE: No username will be prompted, just a password, since the username is unique.
tigervncserver -display "${SERVER_DISPLAY}"                                                                            \
               -localhost "no"                                                                                         \
               -SecurityTypes "VncAuth"                                                                                \
               -PasswordFile "${HOME}/.config/tigervnc/passwd"                                                         \
               -PlainUsers "${USER}"                                                                                   \
               -fg                                                                                                     \
               -geometry "${SERVER_GEOMETRY}"                                                                          \
               -xstartup "/usr/local/bin/tigervnc-xstartup.sh"                                                         \
               -desktop "'${USER}' - VNC desktop"                                                                      \
               -depth "32"                                                                                             \
               -pixelformat "rgb888";
