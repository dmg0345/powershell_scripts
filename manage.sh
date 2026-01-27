#!/bin/bash
#
# Bootstrap management script for Bash kind of terminals.
#
# Do not edit manually — changes will be overwritten.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################
# Minimum PowerShell Core version.
readonly PWSH_VERSION_MIN="7.4.3";
# Major version of the minimum PowerShell Core version.
readonly PWSH_VERSION_MAJOR_MIN=$(echo "$PWSH_VERSION_MIN" | cut -d '.' -f '1');
# Minor version number of the minimum PowerShell Core version.
readonly PWSH_VERSION_MINOR_MIN=$(echo "$PWSH_VERSION_MIN" | cut -d '.' -f '2');
# Path to the PowerShell Core management environment directory.
readonly PWSH_MANAGE_ENV_DIR="./.manage_env";
# Path to the PowerShell Core main management script where to delegate the logic past the bootstrap phase.
readonly PWSH_MANAGE_MAIN_SCRIPT="./manage.main.ps1";

# Path to the system PowerShell Core executable.
readonly PWSH_SYSTEM_EXE=$(printenv 'PWSH_SYSTEM_EXE' || echo 'pwsh');
# Path to the local PowerShell Core directory.
readonly PWSH_LOCAL_DIR="$PWSH_MANAGE_ENV_DIR/pwsh-local-bootstrap-sh";
# Path to the local PowerShell Core executable.
readonly PWSH_LOCAL_EXE="$PWSH_LOCAL_DIR/pwsh";

# [Internal Functions] #################################################################################################
# @brief Determines if the system PowerShell Core is available.
# @return 0 if the system PowerShell Core is available and ready for use and 1 if otherwise.
function Test-SystemPwsh()
{
    # Get the current major version number of the system PowerShell Core available, and check against minimum.
    local cMajor=$("$PWSH_SYSTEM_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Major.ToString()' 2>/dev/null);
    if [[ $cMajor -ge $PWSH_VERSION_MAJOR_MIN ]]; then
        # Get the current minor version number of the system PowerShell Core available, and check against minimum.
        local cMinor=$("$PWSH_SYSTEM_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Minor.ToString()' 2>/dev/null);
        if [[ $cMinor -ge $PWSH_VERSION_MINOR_MIN ]]; then
            return 0;
        fi;
    fi;

    # Command failed to execute or version did not match.
    return 1;
}

# @brief Determines if the local PowerShell Core is available.
# @return 0 if the local PowerShell Core is available and ready for use and 1 if otherwise.
function Test-LocalPwsh()
{
    # Ensure local PowerShell Core directory exists.
    if [[ ! -d $PWSH_LOCAL_DIR ]]; then
        return 1;
    fi;

    # Get the current major version number of the local PowerShell Core available, and check against minimum.
    local cMajor=$("$PWSH_LOCAL_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Major.ToString()' 2>/dev/null);
    if [[ $cMajor -ge $PWSH_VERSION_MAJOR_MIN ]]; then
        # Get the current minor version number of the local PowerShell Core available, and check against minimum.
        local cMinor=$("$PWSH_LOCAL_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Minor.ToString()' 2>/dev/null);
        if [[ $cMinor -ge $PWSH_VERSION_MINOR_MIN ]]; then
            return 0;
        fi;
    fi;

    # Command failed to execute or version did not match.
    return 1;
}

# @brief Installs the local PowerShell Core if not already installed.
function Install-LocalPwsh()
{
    # Check if local PowerShell Core is already installed, and in that case do nothing.
    if Test-LocalPwsh; then
        return;
    fi;
    
    # Log start of installation.
    echo "Installing local PowerShell Core v$PWSH_VERSION_MIN at '$PWSH_LOCAL_DIR'..." > /dev/tty;
    
    # Ensure the local folder is removed and created anew.
    rm -rf "$PWSH_LOCAL_DIR";
    mkdir -p "$PWSH_LOCAL_DIR";
    
    # Download the local PowerShell Core file and install it in the folder.
    outputFilePath="$PWSH_MANAGE_ENV_DIR/local-pwsh-install-file-sh";
    downloadPath="https://github.com/PowerShell/PowerShell/releases/download/v$PWSH_VERSION_MIN";
    lowercaseOSTYPE="${OSTYPE,,}";
    # Determine if running Bash in Linux.
    if [[ $lowercaseOSTYPE =~ linux|wsl ]]; then
        # Set correct variables for Linux.
        downloadPath="$downloadPath/powershell-$PWSH_VERSION_MIN-linux-x64.tar.gz";
        outputFilePath="$outputFilePath.tar.gz";
        trap 'rm -f "$outputFilePath"' EXIT;

        # Download from the official releases site.
        echo "Downloading Linux local PowerShell from '$downloadPath' to '$outputFilePath'..." > /dev/tty;
        curl -Lso "$outputFilePath" "$downloadPath";

        # Untar and install.
        echo "Untarring local PowerShell to '$PWSH_LOCAL_DIR'..." > /dev/tty;
        tar -xzf "$outputFilePath" -C "$PWSH_LOCAL_DIR";
    # Determine if running Bash in MacOS.
    elif [[ $lowercaseOSTYPE =~ darwin ]]; then
        # Set correct variables for MacOS.
        downloadPath="$downloadPath/powershell-$PWSH_VERSION_MIN-osx-x64.tar.gz";
        outputFilePath="$outputFilePath.tar.gz";
        trap 'rm -f "$outputFilePath"' EXIT;

        # Download from the official releases site.
        echo "Downloading MacOS local PowerShell from '$downloadPath' to '$outputFilePath'..." > /dev/tty;
        curl -Lso "$outputFilePath" "$downloadPath";

        # Untar and install.
        echo "Untarring local PowerShell to '$PWSH_LOCAL_DIR'..." > /dev/tty;
        tar -xzf "$outputFilePath" -C "$PWSH_LOCAL_DIR";
    # Determine if running Bash in Windows.
    elif [[ $lowercaseOSTYPE =~ msys|cygwin|mingw ]]; then
        # Set correct variables for Windows.
        downloadPath="$downloadPath/PowerShell-$PWSH_VERSION_MIN-win-x64.zip";
        outputFilePath="$outputFilePath.zip";
        trap 'rm -f "$outputFilePath"' EXIT;

        # Download from the official releases site.
        echo "Downloading Windows local PowerShell from '$downloadPath' to '$outputFilePath'..." > /dev/tty;
        curl -Lso "$outputFilePath" "$downloadPath";

        # Unzip and install.
        echo "Unzipping local PowerShell to '$PWSH_LOCAL_DIR'..." > /dev/tty;
        unzip -q "$outputFilePath" -d "$PWSH_LOCAL_DIR";
    else
        echo "Could not determine platform for local PowerShell Core installation." >&2;
        exit 1;
    fi;

    # Ensure installation completed successfully.
    if ! Test-LocalPwsh; then
        echo "Installation of local PowerShell Core failed." >&2;
        exit 1;
    fi;
    
    # On success, do not wait for the trap to remove the temporary download, remove it ASAP.
    rm -f "$outputFilePath";
    trap - EXIT;

    # Report success in installation.
    echo "Installed local PowerShell Core at '$PWSH_LOCAL_DIR'." > /dev/tty;
}

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Ensure the current location is the location of the script.
if [[ $(realpath "$(dirname "$0")") != $(realpath "$(pwd)") ]]; then
    echo "The script must run from the root directory, where this script is located." >&2;
    exit 1;
fi;

# Ensure application management script is available.
if [[ ! -f $PWSH_MANAGE_MAIN_SCRIPT ]]; then
    echo "No main management script available at '$PWSH_MANAGE_MAIN_SCRIPT'." >&2;
    exit 1;
fi;

# Ensure the management environment directory exists.
mkdir -p "$PWSH_MANAGE_ENV_DIR";

# Determine if using system PowerShell Core or local PowerShell core.
if Test-SystemPwsh; then
    pwshPath="$PWSH_SYSTEM_EXE"
else
    # Ensure local PowerShell is installed.
    Install-LocalPwsh;
    
    # Delegate execution of application management script to local PowerShell and exit with its error code.
    pwshPath="$PWSH_LOCAL_EXE";
fi;

# Determine if arguments were passed or not.
if [[ $# -eq 0 ]]; then
    # Start an interactive PowerShell Core shell without calling the main management script.
    "$pwshPath" -NoExit -NoLogo -Interactive -File "$PWSH_MANAGE_MAIN_SCRIPT" -Command "pwsh-load";
else
    # Delegate execution of application management script to PowerShell Core and exit with its error code.
    "$pwshPath" -File "$PWSH_MANAGE_MAIN_SCRIPT" "$@";
fi;
