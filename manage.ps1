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
# Minimum PowerShell Core version.
$PWSH_VERSION_MIN = "7.4.3";
# Major version of the minimum PowerShell Core version.
$PWSH_VERSION_MAJOR_MIN = [int](($PWSH_VERSION_MIN -Split '\.')[0]);
# Minor version number of the minimum PowerShell Core version.
$PWSH_VERSION_MINOR_MIN = [int](($PWSH_VERSION_MIN -Split '\.')[1]);
# Path to the PowerShell Core management environment directory.
$PWSH_MANAGE_ENV_DIR = Join-Path -Path "." -ChildPath ".manage_env";
# Path to the PowerShell Core main management script where to delegate the logic past the bootstrap phase.
$PWSH_MANAGE_MAIN_SCRIPT = Join-Path -Path "." -ChildPath "manage.main.ps1";

# Path to the system PowerShell Core executable.
$PWSH_SYSTEM_EXE = if ($ENV:PWSH_SYSTEM_EXE) { $ENV:PWSH_SYSTEM_EXE; } else { "pwsh"; };
# Path to the local PowerShell Core directory.
$PWSH_LOCAL_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "pwsh-local-bootstrap-ps1";
# Path to the local PowerShell Core executable.
$PWSH_LOCAL_EXE = Join-Path -Path "$PWSH_LOCAL_DIR" -ChildPath "pwsh";

# [Internal Functions] #################################################################################################
function Test-SystemPwsh
{
    <#
    .DESCRIPTION
        Determines if the system PowerShell Core is available.

    .OUTPUTS
        True if the system PowerShell Core is available and ready for use and false if otherwise.
    #>
    param()

    try
    {
        # Get the current major version number of the system PowerShell Core available, and check against minimum.
        $cMajor= & "$PWSH_SYSTEM_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Major.ToString()' 2>$null;
        if ($cMajor -ge $PWSH_VERSION_MAJOR_MIN)
        {
            # Get the current minor version number of the system PowerShell Core available, and check against minimum.
            $cMinor= & "$PWSH_SYSTEM_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Minor.ToString()' 2>$null;
            if ($cMinor -ge $PWSH_VERSION_MINOR_MIN)
            {
                 return $true;
            }
        }
    }
    catch {}

    # Command failed to execute or version did not match.
    return $false;
}

function Test-LocalPwsh
{
    <#
    .DESCRIPTION
        Determines if the local PowerShell Core is available.

    .OUTPUTS
        True if the local PowerShell Core is available and ready for use and false if otherwise.
    #>
    param()

    # Ensure local PowerShell Core directory exists.
    if (-Not (Test-Path -Path "$PWSH_LOCAL_DIR"))
    {
        return $false;
    }
    
    try
    {
        # Get the current major version number of the local PowerShell Core available, and check against minimum.
        $cMajor= & "$PWSH_LOCAL_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Major.ToString()' 2>$null;
        if ($cMajor -ge $PWSH_VERSION_MAJOR_MIN)
        {
            # Get the current minor version number of the local PowerShell Core available, and check against minimum.
            $cMinor= & "$PWSH_LOCAL_EXE" -NoLogo -Command '$PSVersionTable.PSVersion.Minor.ToString()' 2>$null;
            if ($cMinor -ge $PWSH_VERSION_MINOR_MIN)
            {
                 return $true;
            }
        }
    }
    catch {}

    # Command failed to execute or version did not match.
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
    if (Test-LocalPwsh)
    {
        return;
    }
    
    # Log start of installation.
    Write-Host "Installing local PowerShell Core v$PWSH_VERSION_MIN at '$PWSH_LOCAL_DIR'...";
    
    # Ensure the local folder is removed and created anew.
    Remove-Item -Path "$PWSH_LOCAL_DIR" -Force -Recurse -ErrorAction SilentlyContinue;
    New-Item -Path "$PWSH_LOCAL_DIR" -ItemType Directory -Force | Out-Null;
    
    # Download the local PowerShell Core file and install it in the folder.
    $outputFilePath = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "local-pwsh-install-file-ps1";
    $downloadPath = "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH_VERSION_MIN";
    try
    {
        # Determine if running system PowerShell Core in Linux, for details refer to:
        #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.5#islinux
        if ($IsLinux)
        {
            # Set correct variables for Linux.
            $downloadPath = "$downloadPath/powershell-$PWSH_VERSION_MIN-linux-x64.tar.gz";
            $outputFilePath = "$outputFilePath.tar.gz";

            # Download from the official releases site.
            Write-Host "Downloading Linux local PowerShell from '$downloadPath'...";
            Invoke-WebRequest -Uri "$downloadPath" -OutFile "$outputFilePath";

            # Untar and install.
            Write-Host "Untarring local PowerShell to '$PWSH_LOCAL_DIR'...";
            tar -xzf "$outputFilePath" -C "$PWSH_LOCAL_DIR";
        }
        # Determine if running system PowerShell Core in MacOS, for details refer to:
        #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.5#ismacos
        elseif ($IsMacOS)
        {
            # Set correct variables for MacOS.
            $downloadPath = "$downloadPath/powershell-$PWSH_VERSION_MIN-osx-x64.tar.gz";
            $outputFilePath = "$outputFilePath.tar.gz";

            # Download from the official releases site.
            Write-Host "Downloading MacOS local PowerShell from '$downloadPath'...";
            Invoke-WebRequest -Uri "$downloadPath" -OutFile "$outputFilePath";

            # Untar and install.
            Write-Host "Untarring local PowerShell to '$PWSH_LOCAL_DIR'...";
            tar -xzf "$outputFilePath" -C "$PWSH_LOCAL_DIR";
        }
        # Determine if running built-in Windows PowerShell (v5.1) or PowerShell Core in Windows, for details refer to:
        #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_editions?view=powershell-7.5#long-description
        #   - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.5#iswindows
        elseif (($PSVersionTable.PSEdition -eq "Desktop") -or ($IsWindows))
        {
            # Set correct variables for Windows.
            $downloadPath = "$downloadPath/PowerShell-$PWSH_VERSION_MIN-win-x64.zip";
            $outputFilePath = "$outputFilePath.zip";

            # Download from the official releases site.
            Write-Host "Downloading Windows local PowerShell from '$downloadPath'...";
            Invoke-WebRequest -Uri "$downloadPath" -OutFile "$outputFilePath";

            # Unzip and install.
            Write-Host "Unzipping local PowerShell to '$PWSH_LOCAL_DIR'...";
            Expand-Archive -Path "$outputFilePath" -DestinationPath "$PWSH_LOCAL_DIR" -Force;
        }
        else
        {
            throw "Could not determine platform for local PowerShell Core installation.";
        }
    }
    finally
    {
        Remove-Item -Path "$outputFilePath" -Force -ErrorAction SilentlyContinue;
    }
    
    # Ensure installation completed successfully.
    if (-Not (Test-LocalPwsh))
    {
        throw "Installation of local PowerShell Core failed."
    }
    
    # Report success in installation.
    Write-Host "Installed local PowerShell Core at '$PWSH_LOCAL_DIR'.";
}

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Ensure the current location is the location of the script.
if (((Resolve-Path "$PSScriptRoot").Path) -ne ((Resolve-Path "$PWD").Path))
{
    throw "The script must run from the root directory, where this script is located."
}

# Ensure main management script is available.
if (-Not (Test-Path -Path "$PWSH_MANAGE_MAIN_SCRIPT"))
{
    throw "No main management script available at '$PWSH_MANAGE_MAIN_SCRIPT'.";
}

# Ensure the management environment directory exists.
New-Item -Path "$PWSH_MANAGE_ENV_DIR" -ItemType Directory -Force | Out-Null;

# Determine if using system PowerShell Core or local PowerShell core.
if (Test-SystemPwsh)
{
    $pwshPath = "$PWSH_SYSTEM_EXE";
}
else
{
    # Ensure local PowerShell Core is installed.
    Install-LocalPwsh;

    $pwshPath = "$PWSH_LOCAL_EXE";
}

# Determine if arguments were passed or not.
if ($args.Length -eq 0)
{
    # Start an interactive PowerShell Core shell without calling the main management script.
    & "$pwshPath" -NoExit -NoLogo -Interactive -File "$PWSH_MANAGE_MAIN_SCRIPT" -Command "pwsh-load";
}
else
{
    # Delegate execution of main management script to PowerShell Core and exit with its error code.
    & "$pwshPath" -File "$PWSH_MANAGE_MAIN_SCRIPT" @args;
}
