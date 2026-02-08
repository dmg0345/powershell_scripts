#!/bin/bash
#
# The 'xstartup' script for TigerVNC server, called to run a IceWM session. Run as './tigervnc-xstartup.sh'.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Start icewm session under the hood of an isolated dbus session, for details refer to:
#   - https://manpages.debian.org/trixie/tigervnc-standalone-server/tigervncserver.1.en.html#xstartup
#   - https://ice-wm.org/man/icewm-session.html
#   - https://dbus.freedesktop.org/doc/dbus-run-session.1.html
# Note that the DISPLAY environment variable is automaticalled passed by VNC server.
exec dbus-run-session -- icewm-session;
