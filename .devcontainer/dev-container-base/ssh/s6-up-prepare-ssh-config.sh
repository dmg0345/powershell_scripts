#!/bin/bash
#
# s6-overlay up script for prepare SSH configuration service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Provisioning SSH configuration at '${HOME}/.ssh'...";

# Ensure that if there is an existing configuration, it is removed, and loaded from scratch.
rm -rf "${HOME}/.ssh";

# Create folder structure and ensure correct permissions, for details refer to:
#   - https://man.openbsd.org/ssh.1#FILES
#   - https://man.openbsd.org/ssh_config.5
#   - https://man.openbsd.org/ssh-keyscan.1
mkdir -p "${HOME}/.ssh";
chmod 0700 "${HOME}/.ssh";
touch "${HOME}/.ssh/config";
chmod 0600 "${HOME}/.ssh/config";
touch "${HOME}/.ssh/known_hosts";
chmod 0600 "${HOME}/.ssh/known_hosts";

# Provision known hosts beforehand.
ssh-keyscan "github.com" >> "${HOME}/.ssh/known_hosts";

# Check if provisioning credentials for Github.
if [[ -n "${GITHUB_USERNAME-}" && -n "${GITHUB_SSH_AUTH_KEY_FILE-}" && -f "${GITHUB_SSH_AUTH_KEY_FILE}" ]]; then
    echo "Provisioning SSH configuration for Github...";
    
    # Make a local copy of the key that is destroyed on finish script, and set proper permissions to it.
    # NOTE: This is necessary in case the key comes from a filesystem that does not allow ownership / permission changes.
    cp -f "${GITHUB_SSH_AUTH_KEY_FILE}" "${HOME}/.ssh/.github.auth.key";
    chmod 0600 "${HOME}/.ssh/.github.auth.key";
    
    # Provision configuration.
    cat << EOF >> "${HOME}/.ssh/config"
Host github.com
    User=${GITHUB_USERNAME}
    IdentityFile=${HOME}/.ssh/.github.auth.key
    IdentitiesOnly=yes
    StrictHostKeyChecking=yes
EOF
fi;

echo "Provisioned SSH configuration at '${HOME}/.ssh'.";
