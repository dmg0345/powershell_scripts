<#
.SYNOPSIS
    Bootstrap management script for Windows PowerShell (v5.1) and PowerShell Core kind of terminals.

    Do not edit manually — changes will be overwritten.
#>

# [Initializations] ####################################################################################################
param ()

# Stop on first error found.
$ErrorActionPreference = "Stop";
# Do not show progress bars.
$ProgressPreference = 'SilentlyContinue';

# [Declarations] #######################################################################################################
# Path to the management environment configuration YAML file for the management environment.
$PWSH_MANAGE_ENV_YAML_FILE = Join-Path -Path "${PSScriptRoot}" -ChildPath "manage-env.yml";
# Path to the management environment directory.
$PWSH_MANAGE_ENV_DIR = Join-Path -Path "${PSScriptRoot}" -ChildPath ".manage-env";
# Path to the lock file of an already configured management environment.
$PWSH_MANAGE_ENV_LOCK_FILE = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "manage-env.lock.yml";
# Path to the PowerShell Core main management script where to delegate the logic past the bootstrap phase.
$PWSH_MANAGE_ENV_MAIN_SCRIPT_FILE = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "manage.main.ps1";

# Minimum PowerShell Core version.
$PWSH_VERSION_MIN = "7.4.3";
# Major version of the minimum PowerShell Core version.
$PWSH_VERSION_MAJOR_MIN = [int](($PWSH_VERSION_MIN -split '\.')[0]);
# Minor version number of the minimum PowerShell Core version.
$PWSH_VERSION_MINOR_MIN = [int](($PWSH_VERSION_MIN -split '\.')[1]);
# Path to the system PowerShell Core executable.
$PWSH_SYSTEM_EXE = "pwsh";
# Path to the local PowerShell Core directory.
$PWSH_LOCAL_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "pwsh-local";
# Path to the local PowerShell Core executable.
$PWSH_LOCAL_EXE = Join-Path -Path "$PWSH_LOCAL_DIR" -ChildPath "pwsh";

# [Internal Functions] #################################################################################################
function Get-Platform
{
    <#
    .DESCRIPTION
        Obtains details of the running environment.

    .OUTPUTS
        A string indicating the executing platform, one of: 'linux-x64', 'darwin-x64', 'win-x64' or an empty string if
        not possible to determine.
    #>

    # Determine if running system PowerShell Core in Linux x64, for details refer to:
    #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables#islinux
    #   - https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.runtimeinformation.processarchitecture
    if (($IsLinux) -and ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq "X64"))
    {
        return "linux-x64";
    }
    # Determine if running system PowerShell Core in MacOS x64, for details refer to:
    #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables#ismacos
    #   - https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.runtimeinformation.processarchitecture
    elseif (($IsMacOS) -and ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq "X64"))
    {
        return "darwin-x64";
    }
    # Determine if running built-in Windows PowerShell (v5.1) or PowerShell Core in Windows x64, for details refer to:
    #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_editions#long-description
    #   - https://learn.microsoft.com/en-us/windows/win32/winprog64/wow64-implementation-details
    #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables#iswindows
    #   - https://learn.microsoft.com/en-us/dotnet/api/system.environment.is64bitoperatingsystem
    elseif ((($PSVersionTable.PSEdition -eq "Desktop") -and ($ENV:PROCESSOR_ARCHITECTURE -eq "AMD64")) -or
        (($IsWindows) -and ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq "X64")))
    {
        return "win-x64";
    }

    # Not possible to determine platform.
    return "";
}

function Get-EnvironmentVersion
{
    <#
    .DESCRIPTION
        Gets a version of a management environment from the YAML file, without parsing it.

    .PARAMETER YamlPath
        Path to the management configuration YAML file. Can be an absolute path or a relative path.

    .OUTPUTS
        A string with the version, or an empty string if it was not posible to find one.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $YamlPath
    )
    $regex = "^version\s*\:\s*[`"']?([a-zA-Z0-9\-\.\/]+)[`"']?\s*$";

    # If the file with the environment does not exist, do not attempt to parse.
    if (Test-Path -Path "$YamlPath")
    {
        # Read line by line and find the top-level element 'version', then return its value.
        foreach ($line in Get-Content -Path $YamlPath -Encoding "utf8")
        {
            if ($line -match $regex)
            {
                return $Matches[1];
            }
        }
    }

    # No version found.
    return "";
}

function Install-ManagementEnvironment
{
    <#
    .DESCRIPTION
        Installs the local management environment for the given version.
    #>
    param()

    # Get version of target environment and ensure one exists.
    $targetVersion = Get-EnvironmentVersion -YamlPath "${PWSH_MANAGE_ENV_YAML_FILE}";
    if ($targetVersion.Length -eq 0)
    {
        throw "Unable to determine management environment version from YAML file.";
    }

    # Get version of locked environment, if there is a version mismatch, recreate the environment entirely.
    $lockVersion = Get-EnvironmentVersion -YamlPath "${PWSH_MANAGE_ENV_LOCK_FILE}";
    if ($targetVersion -eq $lockVersion)
    {
        return;
    }

    # Ensure the management environment directory is created anew.
    Remove-Item -Path "${PWSH_MANAGE_ENV_DIR}" -Force -Recurse -ErrorAction "SilentlyContinue";
    New-Item -Path "${PWSH_MANAGE_ENV_DIR}" -ItemType Directory -Force | Out-Null;

    # Log start of installation.
    Write-Output "Installing local management environment '${targetVersion}'...";

    # Ensure we are running in a known platform.
    $platform = Get-Platform;
    if ($platform.Length -eq 0)
    {
        throw "The platform is not supported.";
    }

    # Download the local main management script file and install it in the folder.
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dmg0345/powershell_scripts/${targetVersion}/manage.main.ps1" `
        -OutFile "${PWSH_MANAGE_ENV_MAIN_SCRIPT_FILE}";

    # Lock version with the contents of the original YAML.
    Copy-Item -Path "${PWSH_MANAGE_ENV_YAML_FILE}" -Destination "${PWSH_MANAGE_ENV_LOCK_FILE}" -Force;

    # Fill additional information in the lock file.
    Add-Content -Path "${PWSH_MANAGE_ENV_LOCK_FILE}" -Value "platform: '${platform}'";

    # Report success in installation.
    Write-Output "Installed local management environment.";
}

function Test-Pwsh
{
    <#
    .DESCRIPTION
        Determines if the PowerShell Core given is available and satisfies version requirements.

    .PARAMETER PwshPath
        Path to the 'pwsh' executable to test. Can be an absolute path or a relative path.

    .OUTPUTS
        True if the PowerShell Core given is available and ready for use and false if otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $PwshPath
    )

    try
    {
        # Get the current major version number of the system PowerShell Core available, and check against minimum.
        $cMajor = & "$PwshPath" -NoLogo -Command '$PSVersionTable.PSVersion.Major.ToString()' 2>$null;
        if ($cMajor -ge $PWSH_VERSION_MAJOR_MIN)
        {
            # Get the current minor version number of the system PowerShell Core available, and check against minimum.
            $cMinor = & "$PwshPath" -NoLogo -Command '$PSVersionTable.PSVersion.Minor.ToString()' 2>$null;
            if ($cMinor -ge $PWSH_VERSION_MINOR_MIN)
            {
                return $true;
            }
        }
    }
    catch { }

    # Commands to retrieve version failed to execute or version did not match.
    return $false;
}

function Install-LocalPwsh
{
    <#
    .DESCRIPTION
        Installs the local PowerShell Core if not already installed.
    #>
    param()

    # Check if local PowerShell Core is already installed, and in that case do nothing.
    if (Test-Pwsh -PwshPath "$PWSH_LOCAL_EXE")
    {
        return;
    }

    # Log start of installation.
    Write-Output "Installing local PowerShell Core '$PWSH_VERSION_MIN' in local environment...";

    # Ensure the local folder is removed and created anew.
    Remove-Item -Path "$PWSH_LOCAL_DIR" -Force -Recurse -ErrorAction SilentlyContinue;
    New-Item -Path "$PWSH_LOCAL_DIR" -ItemType Directory -Force | Out-Null;

    # Download the local PowerShell Core file and install it in the folder.
    $outputFilePath = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "local-pwsh-install-file";
    $downloadPath = "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH_VERSION_MIN";
    try
    {
        switch (Get-Platform)
        {
            "linux-x64"
            {
                # Set correct variables for Linux x64.
                $downloadPath = "$downloadPath/powershell-$PWSH_VERSION_MIN-linux-x64.tar.gz";
                $outputFilePath = "$outputFilePath.tar.gz";
                # Download from the official releases site.
                Invoke-WebRequest -Uri "$downloadPath" -OutFile "$outputFilePath";
                # Untar and install.
                tar -xzf "$outputFilePath" -C "$PWSH_LOCAL_DIR";
            }
            "darwin-x64"
            {
                # Set correct variables for MacOS x64.
                $downloadPath = "$downloadPath/powershell-$PWSH_VERSION_MIN-osx-x64.tar.gz";
                $outputFilePath = "$outputFilePath.tar.gz";
                # Download from the official releases site.
                Invoke-WebRequest -Uri "$downloadPath" -OutFile "$outputFilePath";
                # Untar and install.
                tar -xzf "$outputFilePath" -C "$PWSH_LOCAL_DIR";
            }
            "win-x64"
            {
                # Set correct variables for Windows x64.
                $downloadPath = "$downloadPath/PowerShell-$PWSH_VERSION_MIN-win-x64.zip";
                $outputFilePath = "$outputFilePath.zip";
                # Download from the official releases site.
                Invoke-WebRequest -Uri "$downloadPath" -OutFile "$outputFilePath";
                # Unzip and install.
                Expand-Archive -Path "$outputFilePath" -DestinationPath "$PWSH_LOCAL_DIR" -Force;
            }
            default
            {
                throw "Could not determine platform for local PowerShell Core installation.";
            }
        }
    }
    finally
    {
        Remove-Item -Path "$outputFilePath" -Force -ErrorAction SilentlyContinue;
    }

    # Ensure installation completed successfully.
    if (-not (Test-Pwsh -PwshPath "$PWSH_LOCAL_EXE"))
    {
        throw "Installation of local PowerShell Core failed."
    }

    # Report success in installation.
    Write-Output "Installed local PowerShell Core in local environment.";
}

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Ensure the current location is the location of the script.
if (((Resolve-Path "$PSScriptRoot").Path) -ne ((Resolve-Path "$PWD").Path))
{
    throw "The script must run from the root directory, where this script is located."
}

# Install the management environment.
Install-ManagementEnvironment;

# Determine if using system PowerShell Core or local PowerShell core.
if (Test-Pwsh -PwshPath "$PWSH_SYSTEM_EXE")
{
    $pwshPath = "$PWSH_SYSTEM_EXE";
}
else
{
    # Ensure local PowerShell Core is installed.
    Install-LocalPwsh;

    $pwshPath = "$PWSH_LOCAL_EXE";
}

# Delegate execution of main management script to PowerShell Core and exit with its error code.
& "$pwshPath" -File "$PWSH_MANAGE_ENV_MAIN_SCRIPT_FILE" @args;
