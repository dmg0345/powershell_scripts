#!/bin/bash
#
# Bootstrap management script for Bash kind of terminals.
#
# Do not edit manually — changes will be overwritten.

# [Initializations] ####################################################################################################

# Stop on first error found or unbound variables.
set -euo pipefail

# [Declarations] #######################################################################################################
# Path to the management environment configuration YAML file for the management environment.
# shellcheck disable=SC2155
readonly PWSH_MANAGE_ENV_YAML_FILE="./manage-env.yml";
# Path to the management environment directory.
# shellcheck disable=SC2155
readonly PWSH_MANAGE_ENV_DIR="./.manage-env";
# Path to a directory with the local dependencies.
readonly PWSH_MANAGE_ENV_DEP_DIR="${PWSH_MANAGE_ENV_DIR}/local-deps";
# Path to the lock file of an already configured management environment.
readonly PWSH_MANAGE_ENV_LOCK_FILE="${PWSH_MANAGE_ENV_DIR}/manage-env.lock.yml";
# Path to the PowerShell Core scripts local dependency directory.
readonly PWSH_SCRIPTS_DIR="${PWSH_MANAGE_ENV_DEP_DIR}/pwsh-scripts";
# Path to the PowerShell Core main management script where to delegate the logic past the bootstrap phase.
readonly PWSH_SCRIPTS_MAIN_SCRIPT_FILE"${PWSH_SCRIPTS_DIR}/manage.main.ps1";
# Minimum PowerShell Core version.
readonly PWSH_VERSION_MIN="7.4.3";
# Major version of the minimum PowerShell Core version.
# shellcheck disable=SC2155
readonly PWSH_VERSION_MAJOR_MIN=$(echo "${PWSH_VERSION_MIN}" | cut -d '.' -f '1');
# Minor version number of the minimum PowerShell Core version.
# shellcheck disable=SC2155
readonly PWSH_VERSION_MINOR_MIN=$(echo "${PWSH_VERSION_MIN}" | cut -d '.' -f '2');
# Path to the local PowerShell Core directory.
readonly PWSH_LOCAL_DIR="${PWSH_MANAGE_ENV_DIR}/pwsh-local";

# [Internal Functions] #################################################################################################
# @brief Obtains details of the environment running the scripts.
# @return A string indicating the executing platform, one of: 'linux-x64', 'darwin-x64', 'win-x64' or an empty string if
# not possible to determine.
function Get-Platform()
{
    # Use environment variables to get OS and ARCH, for details refer to:
    #   - https://www.gnu.org/software/bash/manual/bash.html#index-OSTYPE
    #   - https://www.gnu.org/software/bash/manual/bash.html#index-HOSTTYPE
    local -r lowercaseOSTYPE="${OSTYPE,,}";
    local -r lowercaseARCH="${HOSTTYPE,,}";

    # Determine if running Bash in Linux.
    if [[ ${lowercaseOSTYPE} =~ linux|wsl && ${lowercaseARCH} =~ amd64|x86_64 ]]; then
        echo "linux-x64";
    # Determine if running Bash in MacOS.
    elif [[ ${lowercaseOSTYPE} =~ darwin && ${lowercaseARCH} =~ amd64|x86_64 ]]; then
        echo "darwin-x64";
    # Determine if running Bash in Windows.
    elif [[ ${lowercaseOSTYPE} =~ msys|cygwin|mingw && ${lowercaseARCH} =~ amd64|x86_64 ]]; then
        echo "win-x64";
    else
        # Not possible to determine platform.
        echo "";
    fi
}

# @brief Gets a version of a management environment from the YAML file, without parsing it.
# @param $1 Path to the management configuration YAML file.
# @return A string with the version, or an empty string if it was not posible to find one.
function Get-EnvironmentVersion()
{
    local -r regex="^version[[:space:]]*\\:[[:space:]]*[\"']?([a-zA-Z0-9\\-\\.\\/]+)[\"']?[[:space:]]*$";

    # If the file with the environment does not exist, do not attempt to parse.
    if [[ -f "${1}" ]]; then
        # Read line by line and find the top-level element 'version', then return its value.
        while IFS='' read -r line; do
            if [[ $line =~ $regex ]]; then
                echo "${BASH_REMATCH[1]}";
                break;
            fi
        done < "${1}";
    fi

    echo "";
}

# @brief Installs the local management environment for the given version.
# @param $1 Version as read from the management environment configuration YAML file.
function Install-ManagementEnvironment()
{
    # Get version of locked environment, if there is a version mismatch, recreate the environment entirely.
    lockVersion=$(Get-EnvironmentVersion "${PWSH_MANAGE_ENV_LOCK_FILE}");
    if [[ "${1}" == "${lockVersion}" ]]; then
        return;
    fi

    # Ensure the management environment directory is created anew.
    rm -rf "${PWSH_MANAGE_ENV_DIR}";
    mkdir -p "${PWSH_MANAGE_ENV_DIR}";

    # Log start of installation.
    echo "Installing local management environment '${1}' at '${PWSH_MANAGE_ENV_DIR}'...";

    # Ensure the destination folder where the main management script file will be deployed exists.
    mkdir -p "${PWSH_SCRIPTS_DIR}";

    # Download the local main management script file and install it in the folder.
    curl -Lfo "${PWSH_SCRIPTS_MAIN_SCRIPT_FILE}" \
        "https://raw.githubusercontent.com/dmg0345/powershell_scripts/${1}/manage.main.ps1";

    # Lock version with the contents of the original YAML.
    cat "${PWSH_MANAGE_ENV_YAML_FILE}" > "${PWSH_MANAGE_ENV_LOCK_FILE}";
}

# @brief Determines if the PowerShell Core given is available and satisfies version requirements.
# @param $1 Path to the 'pwsh' executable to test.
# @return 0 if the system PowerShell Core is available and ready for use and 1 if otherwise.
# shellcheck disable=SC2312,SC2016
function Test-Pwsh()
{
    # Ensure the path exists and it can be executed.
    if [[ -x "${1}" ]]; then
        # Get the current major / minor version numbers of the PowerShell Core given.
        local -r cMajor=$("${1}" -NoLogo -Command '$PSVersionTable.PSVersion.Major.ToString()' 2>/dev/null);
        local -r cMinor=$("${1}" -NoLogo -Command '$PSVersionTable.PSVersion.Minor.ToString()' 2>/dev/null);
        # Perform version check comparison against minimum major and minor version numbers.
        if [[
            (${cMajor} -gt ${PWSH_VERSION_MAJOR_MIN}) ||
            ((${cMajor} -eq ${PWSH_VERSION_MAJOR_MIN}) && (${cMinor} -ge ${PWSH_VERSION_MINOR_MIN}))
        ]]; then
                return 0;
        fi
    fi

    # Command failed to execute or version did not match.
    return 1;
}

# @brief Installs the local PowerShell Core if not already installed.
# shellcheck disable=SC2310
function Install-LocalPwsh()
{
    # Log start of installation.
    echo "Installing local PowerShell Core '${PWSH_VERSION_MIN}' at '${PWSH_LOCAL_DIR}'...";

    # Ensure the local folder is removed and created anew.
    rm -rf "${PWSH_LOCAL_DIR}";
    mkdir -p "${PWSH_LOCAL_DIR}";

    # Download the local PowerShell Core file and install it in the folder.
    # shellcheck disable=SC2312
    local -r platform=$(Get-Platform);
    local outputFilePath="${PWSH_MANAGE_ENV_DIR}/local-pwsh-install-file";
    local downloadPath="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION_MIN}";
    if [[ ${platform} == "linux-x64" ]]; then
        # Set correct variables for Linux x64.
        downloadPath="${downloadPath}/powershell-${PWSH_VERSION_MIN}-linux-x64.tar.gz";
        outputFilePath="${outputFilePath}.tar.gz";
        trap 'rm -f "$outputFilePath"' EXIT;
        # Download from the official releases site.
        curl -Lfo "${outputFilePath}" "${downloadPath}";
        # Untar and install.
        tar -xzf "${outputFilePath}" -C "${PWSH_LOCAL_DIR}";
        # Ensure proper permissions are set on relevant files.
        chmod +x "$PWSH_LOCAL_DIR/pwsh";
    elif [[ ${platform} == "darwin-x64" ]]; then
        # Set correct variables for MacOS x64.
        downloadPath="${downloadPath}/powershell-${PWSH_VERSION_MIN}-osx-x64.tar.gz";
        outputFilePath="${outputFilePath}.tar.gz";
        trap 'rm -f "$outputFilePath"' EXIT;
        # Download from the official releases site.
        curl -Lfo "${outputFilePath}" "${downloadPath}";
        # Untar and install.
        tar -xzf "${outputFilePath}" -C "${PWSH_LOCAL_DIR}";
        # Ensure proper permissions are set on relevant files.
        chmod +x "$PWSH_LOCAL_DIR/pwsh";
    elif [[ ${platform} == "win-x64" ]]; then
        # Set correct variables for Windows x64.
        downloadPath="${downloadPath}/PowerShell-${PWSH_VERSION_MIN}-win-x64.zip";
        outputFilePath="${outputFilePath}.zip";
        trap 'rm -f "$outputFilePath"' EXIT;
        # Download from the official releases site.
        curl -Lfo "${outputFilePath}" "${downloadPath}";
        # Unzip and install.
        unzip -q "${outputFilePath}" -d "${PWSH_LOCAL_DIR}";
    else
        echo "Could not determine platform for local PowerShell Core installation." >&2;
        exit 1;
    fi

    # On success, do not wait for the trap to remove the temporary download, remove it ASAP.
    rm -f "${outputFilePath}";
    trap - EXIT;
}

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Ensure the current location is the location of the script.
# shellcheck disable=SC2312
if [[ $(realpath "$(dirname "$0")") != $(realpath "$(pwd)") ]]; then
    echo "The script must run from the root directory, where this script is located." >&2;
    exit 1;
fi

# Get version of target environment and ensure one exists.
targetVersion=$(Get-EnvironmentVersion "${PWSH_MANAGE_ENV_YAML_FILE}");
if [[ -z "$targetVersion" ]]; then
    echo "Unable to determine management environment version from YAML file." >&2;
    exit 1;
fi

# Ensure we are running in a known and supported platform.
platform=$(Get-Platform);
if [[ -z "${platform}" ]]; then
    echo "The platform is not supported in management environment.";
    exit 1;
fi

# Install the management environment.
Install-ManagementEnvironment "${targetVersion}";

# Resolve paths to system PowerShell Core executable in PATH, and local PowerShell Core executable.
if [[ $platform == "win-x64" ]]; then
    systemPwshExe=$(command -v "pwsh.exe");
    localPwshExe="${PWSH_LOCAL_DIR}/pwsh.exe";
elif [[ $platform == "linux-x64" || $platform == "darwin-x64" ]]; then
    systemPwshExe=$(command -v "pwsh");
    localPwshExe="${PWSH_LOCAL_DIR}/pwsh";
fi

# Determine if using system PowerShell Core or local PowerShell core.
# shellcheck disable=SC2310
if Test-Pwsh "${systemPwshExe}"; then
    # Use system PowerShell Core as it satisfies minimum requirements.
    pwshPath="${systemPwshExe}"
else
    if ! Test-Pwsh "${localPwshExe}"; then
        # Ensure local PowerShell is installed.
        Install-LocalPwsh;

        # Ensure the installation completed successfully.
        if ! Test-Pwsh "${localPwshExe}"; then
            echo "Installation of local PowerShell Core failed." >&2;
            exit 1;
        fi
    fi

    # Use local PowerShell Core as the system PowerShell Core does not satisfy minimum requirements.
    pwshPath="${localPwshExe}";
fi

# Delegate further execution to PowerShell Core and exit with its error code.
"${pwshPath}" -File "${PWSH_MANAGE_ENV_MAIN_SCRIPT_FILE}" \
    -ManagementEnvironmentDir "${PWSH_MANAGE_ENV_DIR}" \
    -ManagementEnvironmentPwsh "${pwshPath}" \
    -ManagementEnvironmentVersion "${targetVersion}" \
    -ManagementEnvironmentPlatform "${platform}" \
    "$@";
