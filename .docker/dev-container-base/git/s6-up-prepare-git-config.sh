#!/bin/bash
#
# s6-overlay up script for prepare Git configuration service.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################

echo "Provisioning Git configuration at '${HOME}/.gitconfig'...";

# Ensure that if there is an existing configuration, it is removed, and loaded from scratch.
rm -f "${HOME}/.gitconfig";
rm -f "${HOME}/.gitconfig.sign.key";

# Create folder structure and ensure correct permissions, for details refer to:
#   - https://git-scm.com/docs/git-config
#   - https://git-scm.com/docs/git-config#Documentation/git-config.txt---global
#   - https://git-scm.com/docs/git-config#Documentation/git-config.txt-username
#   - https://git-scm.com/docs/git-config#Documentation/git-config.txt-useremail
#   - https://git-scm.com/docs/git-config#Documentation/git-config.txt-usersigningKey
touch "${HOME}/.gitconfig";
chmod 0600 "${HOME}/.gitconfig";

# Provision username if specified.
if [[ -n "${GIT_USERNAME-}" ]]; then
    echo "Provisioning username configuration for Git..."

    git config --global user.name "${GIT_USERNAME}";
    git config --global author.name "${GIT_USERNAME}";
    git config --global committer.name "${GIT_USERNAME}";
fi;

# Provision email if specified.
if [[ -n "${GIT_EMAIL-}" ]]; then
    echo "Provisioning email configuration for Git..."

    git config --global user.email "${GIT_EMAIL}";
    git config --global author.email "${GIT_EMAIL}";
    git config --global committer.email "${GIT_EMAIL}";
fi;

# Provision signing key if specified.
if [[ -n "${GIT_SSH_SIGN_KEY_FILE-}" && -f "${GIT_SSH_SIGN_KEY_FILE}" ]]; then
    echo "Provisioning signing key configuration for Git...";

    # Make a local copy of the key that is destroyed on finish script, and set proper permissions to it.
    # NOTE: This is necessary in case the key comes from a filesystem that does not allow ownership / permission changes.
    cp -f "${GIT_SSH_SIGN_KEY_FILE}" "${HOME}/.gitconfig.sign.key";
    chmod 0600 "${HOME}/.gitconfig.sign.key";

    git config --global user.signingKey "${HOME}/.gitconfig.sign.key";
fi;

echo "Provisioned Git configuration at '${HOME}/.gitconfig'.";
