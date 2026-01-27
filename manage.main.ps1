<#
.SYNOPSIS
    Main management script based on PowerShell Core. This script must be executed from the respective bootstrap script.
    
    Do not edit manually — changes will be overwritten.
#>

# [Initializations] ####################################################################################################
[CmdletBinding(PositionalBinding=$false)]
param (
    # Main command to execute, one of:
    #   - 'pwsh-load': Host/Container command, loads the Powershell modules in the terminal for more granular access.
    #   - 'git': Host/Container command, forwards the script arguments to Git along with other relevant arguments.
    #   - 'git-clean': Host/Container command, recursively cleans the repository and submodules with Git.
    #   - 'docker': Host command, forwards the script arguments to Docker along with other relevant arguments.
    #   - 'docker-print': Host command, prints details about networks, images, volumes, containers...
    #   - 'docker-clean': Host command, cleans stopped containers, unused images and networks, anonymous volumes and builder cache.
    #   - 'docker-bake': Host command, forwards the script arguments to Docker Bake along with other relevant arguments.
    #   - 'docker-bake-print <target|dev-container>': Host command, provides details of all the Docker Bake files.
    #   - 'docker-bake-lint <target|dev-container>': Host command, lints all the DockerFiles in the Docker Bake files.
    #   - 'docker-bake-build <target|dev-container>': Host command, builds all the images with cache and keeps them local.
    #   - 'docker-bake-rebuild <target|dev-container>': Host command, rebuilds all the images with no cache and keeps them local.
    #   - 'docker-bake-push <target|dev-container>': Host command, like 'docker-bake-build' and also pushes the images to the image registry.
    #   - 'docker-compose': Host command, forwards the script arguments to Docker Compose along with other relevant arguments.
    #   - 'docker-compose-print <service|dev-container>': Host command, provides details of all the Docker Compose files. Also lints the files.
    #   - 'docker-compose-create <service|dev-container>': Host command, creates the containers but does not start them.
    #   - 'docker-compose-start <service|dev-container>': Host command, starts the created containers if they were stopped.
    #   - 'docker-compose-stop <service|dev-container>': Host command, stops the started containers if they were started.
    #   - 'docker-compose-destroy <service|dev-container>': Host command, stops and removes the Docker Compose resources, except volumes.
    #   - 'vscode': Host command, forwards the script arguments to Visual Studio Code CLI along with other relevant arguments.
    #   - 'vscode-devcontainer': Host command, forwards the script arguments to Visual Studio Code Dev Container CLI along with other relevant arguments.
    #   - 'vscode-devcontainer-open': Host command, forwards the script arguments to Visual Studio Code Dev Container CLI along with other relevant arguments.
    # Any other command line argument combination is redirected towards the management application script.
    [Parameter(Mandatory = $false)]
    [Alias("c")]
    [String]
    $Command,

    # Target for 'docker-bake-*' related commands.
    [Parameter(Mandatory = $false)]
    [Alias("t")]
    [String]
    $BakeTarget,

    # Service for 'docker-compose-*' related commands.
    [Parameter(Mandatory = $false)]
    [Alias("s")]
    [String]
    $ComposeService,
    
    # The application script identifier where to redirect the arguments.
    [Parameter(Mandatory = $false)]
    [String]
    $Script,

    # Collection of remaining unbound parameters passed.
    [Parameter(ValueFromRemainingArguments = $true)]
    $PSUnboundParameters
)

# Make non-zero exit codes of applications behave with respect to 'ErrorActionPreference'.
$PSNativeCommandUseErrorActionPreference = $true;
# Stop on first error found.
$ErrorActionPreference = "Stop";
# Do not show progress bars.
$ProgressPreference = 'SilentlyContinue';

# [Declarations] #######################################################################################################
# Path to the root directory where the bootstrap and management scripts are located.
$ROOT_DIR = if ($ENV:ROOT_DIR) { $ENV:ROOT_DIR; } else { Resolve-Path -Path "$PSScriptRoot"; };
# Path to '.devcontainer' directory.
$DEVCONTAINER_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".devcontainer";
# Path to '.vscode' directory.
$VSCODE_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".vscode";

# Path to the Git executable.
$GIT_EXE = if ($ENV:GIT_EXE) { $ENV:GIT_EXE; } else { "git"; };
# Path to the Docker executable.
$DOCKER_EXE = if ($ENV:DOCKER_EXE) { $ENV:DOCKER_EXE; } else { "docker"; };
# Path to the Visual Studio Code CLI executable.
$VSCODE_CLI_EXE = if ($ENV:VSCODE_CLI_EXE) { $ENV:VSCODE_CLI_EXE; } else { "code"; };
# Path to the Visual Studio Code DevContainer CLI executable.
$VSCODE_DEV_CONTAINER_CLI_EXE = if ($ENV:VSCODE_DEV_CONTAINER_CLI_EXE) { $ENV:VSCODE_DEV_CONTAINER_CLI_EXE; } else { "devcontainer"; };

# Path to the PowerShell Core executable executing the script, must match the bootstrap scripts.
$PWSH_EXE = if (Test-Path (Join-Path -Path "$PSHOME" -ChildPath "pwsh.exe")) {
    (Resolve-Path -Path (Join-Path -Path "$PSHOME" -ChildPath "pwsh.exe")).Path;
} else {
    (Resolve-Path -Path (Join-Path -Path "$PSHOME" -ChildPath "pwsh")).Path;
};
# Path to the PowerShell Core management environment directory, must match the bootstrap scripts.
$PWSH_MANAGE_ENV_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".manage_env";
# Path to a temporary directory within the management environment directory.
$PWSH_MANAGE_TMP_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "tmp-dir";
# Path to a directory with the local dependencies.
$PWSH_MANAGE_DEP_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "local-deps";
# Path to the PowerShell Core main management script (this script), must match the bootstrap scripts.
$PWSH_MANAGE_MAIN_SCRIPT = Join-Path -Path "$ROOT_DIR" -ChildPath "manage.main.ps1";

# PowerShell Core scripts local dependency pinned version.
$PWSH_SCRIPTS_VERSION = "1.3.10";
# Path to the PowerShell Core scripts local dependency directory.
$PWSH_SCRIPTS_DIR = Join-Path -Path "$PWSH_MANAGE_DEP_DIR" -ChildPath "pwsh-scripts";
# 'yq' CLI utility local dependency pinned version.
$YQ_VERSION = "4.50.1";
# Path to the 'yq' CLI utility local dependency.
$YQ_EXE = Join-Path -Path "$PWSH_MANAGE_DEP_DIR" -ChildPath "yq";
# 'hjson' CLI utility local dependency pinned version.
$HJSON_VERSION = "4.6.0";
# Path to the 'hjson' CLI utility local dependency.
$HJSON_EXE = Join-Path -Path "$PWSH_MANAGE_DEP_DIR" -ChildPath "hjson";

# Target for 'docker-bake-*' commands.
$DOCKER_BAKE_TARGET = if ($BakeTarget -ne "") { $BakeTarget; } else { "dev-container"; };
# Docker Bake Project name.
$DOCKER_BAKE_PROJECT_NAME = if ($ENV:BAKE_PROJECT_NAME) { $ENV:BAKE_PROJECT_NAME; } else {
    (Split-Path -Path "." -Leaf).ToLower().Replace(" ", "-").Replace("_", "-")
};
# Docker Bake Images local registry.
$DOCKER_BAKE_IMAGE_LOCAL_REGISTRY = if ($ENV:BAKE_IMAGE_LOCAL_REGISTRY) { $ENV:BAKE_IMAGE_LOCAL_REGISTRY; } else {
    "localhost/localuser";
};

# Service for 'docker-compose-*' commands.
$DOCKER_COMPOSE_SERVICE = if ($ComposeService -ne "") { $ComposeService; } else { "dev-container"; };
# Docker Compose Project name.
$DOCKER_COMPOSE_PROJECT_NAME = if ($ENV:COMPOSE_PROJECT_NAME) { $ENV:COMPOSE_PROJECT_NAME; } else {
    (Split-Path -Path "." -Leaf).ToLower().Replace(" ", "-").Replace("_", "-")
};

# [Internal Functions] #################################################################################################
function Test-LocalDependencies
{
    <#
    .DESCRIPTION
        Determines if the PowerShell Core scripts and other local dependencies are available.

    .OUTPUTS
        True if the system PowerShell Core scripts and the other local dependencies are available and ready for use.
    #>
    param()
    
    
    try
    {
        # Get the tag of the PowerShell Core scripts if possible, and ensure it matches expected one.
        $gitTag = & "$($ENV:GIT_EXE)" -C "$($ENV:PWSH_SCRIPTS_DIR)" describe --exact-match --tags HEAD 2>$null;
        if ($gitTag -ne "$($ENV:PWSH_SCRIPTS_VERSION)")
        {
            return $false;
        }
    } catch { return $false; }

    try
    {
        # Get the 'yq' CLI utility version if possible and do a check for expected version.
        $yqVersion = & "$($ENV:YQ_EXE)" --version 2>$null;
        if (-not ($yqVersion -match ".*v$($ENV:YQ_VERSION)`$"))
        {
            return $false;
        }
    } catch { return $false; }
    
    try
    {
        # Get the 'hjson' CLI utility version if possible and do a check for expected version.
        $hjsonVersion = & "$($ENV:HJSON_EXE)" -v 2>$null;
        if (-not ($hjsonVersion -match "^v$($ENV:HJSON_VERSION)`$"))
        {
            return $false;
        }
    } catch { return $false; }

    # All dependencies installed.
    return $true;
}

function Install-LocalDependencies
{
    <#
    .DESCRIPTION
        Installs the PowerShell Core Scripts and other local dependencies if not already installed.
    #>
    param()

    # Check if local dependencies are already installed, and in that case do nothing.
    if (Test-LocalDependencies)
    {
        return;
    }
    
    # Remove directory with local dependencies and create anew.
    Remove-Item -Path "$($ENV:PWSH_MANAGE_DEP_DIR)" -Force -Recurse -ErrorAction 'SilentlyContinue';
    New-Item -Path "$($ENV:PWSH_MANAGE_DEP_DIR)" -ItemType Directory -Force | Out-Null;
    
    # Fetch links to OS / architecture specific dependencies.
    if ($IsLinux)
    {
        $yqOutFile = "$($ENV:YQ_EXE)";
        $yqUrl = "https://github.com/mikefarah/yq/releases/download/v$($ENV:YQ_VERSION)/yq_linux_amd64";
        $hjsonOutFile = "$($ENV:HJSON_EXE).tar.gz";
        $hjsonUrl = "https://github.com/hjson/hjson-go/releases/download/v$($ENV:HJSON_VERSION)/hjson_v$($ENV:HJSON_VERSION)_linux_amd64.tar.gz";
    }
    elseif ($IsMacOS)
    {
        $yqOutFile = "$($ENV:YQ_EXE)";
        $yqUrl = "https://github.com/mikefarah/yq/releases/download/v$($ENV:YQ_VERSION)/yq_darwin_amd64";
        $hjsonOutFile = "$($ENV:HJSON_EXE).tar.gz";
        $hjsonUrl = "https://github.com/hjson/hjson-go/releases/download/v$($ENV:HJSON_VERSION)/hjson_v$($ENV:HJSON_VERSION)_darwin_amd64.tar.gz";
    }
    else
    {
        $yqOutFile = "$($ENV:YQ_EXE).exe";
        $yqUrl = "https://github.com/mikefarah/yq/releases/download/v$($ENV:YQ_VERSION)/yq_windows_amd64.exe";
        $hjsonOutFile = "$($ENV:HJSON_EXE).zip";
        $hjsonUrl = "https://github.com/hjson/hjson-go/releases/download/v$($ENV:HJSON_VERSION)/hjson_v$($ENV:HJSON_VERSION)_windows_amd64.zip";
    }

    # Configure the repository for download and installation of the PowerShell Core scripts.
    Write-Host "Installing PowerShell Core scripts '$($ENV:PWSH_SCRIPTS_VERSION)' in local environment...";
    & "$($ENV:GIT_EXE)" clone --quiet --branch "$($ENV:PWSH_SCRIPTS_VERSION)" --depth 1 `
        --shallow-submodules --recurse-submodules `
        "https://github.com/dmg0345/powershell_scripts" "$($ENV:PWSH_SCRIPTS_DIR)";

    # Fetch 'yq' CLI preprocessor for YAML / JSON files.
    Write-Host "Installing yq '$($ENV:YQ_VERSION)' in local environment...";
    Invoke-WebRequest -Uri "$yqUrl" -OutFile "$yqOutFile";
    
    # Fetch 'hjson' CLI preprocessor for JSONC files.
    Write-Host "Installing hjson '$($ENV:HJSON_VERSION)' in local environment...";
    Invoke-WebRequest -Uri "$hjsonUrl" -OutFile "$hjsonOutFile";
    if ($hjsonOutFile.EndsWith(".zip")) {
        Expand-Archive -Path "$hjsonOutFile" -DestinationPath "$($ENV:PWSH_MANAGE_DEP_DIR)";
    } else {
        tar -xzf "$hjsonOutFile" -C "$($ENV:PWSH_MANAGE_DEP_DIR)";
    }
    Remove-Item -Path "$hjsonOutFile" -Force;
    
    # Ensure installation completed successfully.
    if (-Not (Test-LocalDependencies))
    {
        throw "Installation of local dependencies failed."
    }
    
    # Report success in installation.
    Write-Host "Installed local dependencies in local environment.";
}

function Get-EnvironmentSnapshot
{
    <#
    .DESCRIPTION
        Gets a snapshot of the current environment.

    .OUTPUTS
        A snapshot of the current environment.
    #>
    param()
    
    # Create blank hash table.
    $snapshot = @{};
    # Fill with items of current environment.
    Get-ChildItem ENV: | ForEach-Object { $snapshot[$_.Name] = $_.Value; }
    # Return snapshot.
    return $snapshot;
}

function Restore-EnvironmentSnapshot
{
    <#
    .DESCRIPTION
        Restores the current environment from a given snapshot.

    .PARAMETER Snapshot
        The snapshot to fill the environment with.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]
        $Snapshot
    )
    
    # Wipe the current environment.
    Get-ChildItem ENV: | Remove-Item -Force;
    # Fill the wiped environment from the snapshot.
    foreach ($key in $Snapshot.Keys) { Set-Item "ENV:${key}" $Snapshot[$key]; }
}

function New-SortedFileSet
{
    <#
    .DESCRIPTION
        Returns a sorted file set per the following rules:

    .PARAMETER Dir
        The directory where to look for relevant files.
    
    .PARAMETER FileSuffix
        File suffix to capture, e.g. 'compose' for '000-.*-compose.yml'.

    .PARAMETER FileExtension
        File extension to capture, e.g. 'json' for '000-.*-settings.json'.
    
    .PARAMETER FileSelectors
        Comma delimited selectors to capture, e.g. 'dev,enc' for '000-.*-compose.dev.yml' and '000-.*-compose.enc.yml'.
        
    .OUTPUTS
        An array with sorted paths to the relevant files found.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $Dir,
        
        [Parameter(Mandatory = $true)]
        [String]
        $FileSuffix,
        
        [Parameter(Mandatory = $true)]
        [String]
        $FileExtension,
        
        [Parameter(Mandatory = $false)]
        [String]
        $FileSelectors = ""
    )

    # If the destination directory does not exist, do not return any files.
    if (-not (Test-Path -Path "$Dir" -PathType Container))
    {
        return @();
    }
    
    # Find sub-directories in the destination directory that meet the search criteria, and sort them.
    $sortedSubDirs = Get-ChildItem -Path "$Dir" -Directory -Depth 0 |
        Where-Object { $_.Name -match "^[0-9]{3}-.*" } |
        Sort-Object -Property "Name" |
        ForEach-Object { $_.FullName; };
    
    # Find duplicate ordering in subdirectories.
    $sortedSubDirs |
        Split-Path -Leaf |
        ForEach-Object { $_.Substring(0, 3); } |
        Group-Object |
        Where-Object { $_.Count -gt 1; } |
        ForEach-Object { throw "Found sub-directory ordering duplicate numbering at '$Dir'."; }

    # Loop the sorted sub-directories first, and then the main directory last, and fetch relevant files.
    $allSortedFiles = @();
    $escFileSuffix = [regex]::Escape($FileSuffix);
    $escFileExtension = [regex]::Escape($FileExtension);
    foreach ($scanDir in (@($sortedSubDirs) + @($Dir)))
    {
        # Find common files in the destination directory that meet the search criteria.
        $sortedCommonFiles = Get-ChildItem -Path "$scanDir" -File -Depth 0 | 
            Where-Object { $_.Name -match "^[0-9]{3}-.*-$escFileSuffix\.$escFileExtension`$"; } |
            ForEach-Object { $_.Name; };

        # Find selected files in the destination directory that meet the search criteria.
        $sortedSelectedFiles = $FileSelectors -Split ',' |
            ForEach-Object { $_.Trim(); } |
            Where-Object { $_.Length -gt 0; } |
            ForEach-Object {
                $escFileSelector = [regex]::Escape($_);
                Get-ChildItem -Path "$scanDir" -File -Depth 0 |
                    Where-Object { $_.Name -match "^[0-9]{3}-.*-$escFileSuffix\.$escFileSelector\.$escFileExtension`$"; } |
                    ForEach-Object { $_.Name; }
            };
            
        # Concatenate the common files and the sorted selected files for the folder, they will be sorted later.
        $sortedFiles = @($sortedCommonFiles) + @($sortedSelectedFiles);

        # Check if any relevant files were found.
        if ($sortedFiles.Length -gt 0)
        {
            # Find duplicates within the same scan directory, if any.
            $sortedFiles |
                ForEach-Object { $_.Substring(0, 3); } |
                Group-Object |
                Where-Object { $_.Count -gt 1; } |
                ForEach-Object { throw "Found file ordering duplicate numbering at '$scanDir'."; }

            # Sort found files.
            $sortedFiles = $sortedFiles | 
                Sort-Object | 
                ForEach-Object { Join-Path -Path "$scanDir" -ChildPath "$_"; };

            # Add to all files.
            $allSortedFiles += $sortedFiles;
        }
    };

    return $allSortedFiles;
}

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
# Determine if first call to the script based on the existence of the ROOT_DIR environment variable.
$initialCall = -not (Test-Path ENV:ROOT_DIR);

# If first call to the script, ensure manage environment and environment variables are provisioned.
if ($initialCall)
{
    # Get a snapshot of the environment to restore it later.
    $envSnapshot = Get-EnvironmentSnapshot;
    
    # Create environment variables under which to run commands for script execution.
    $ENV:ROOT_DIR = $ROOT_DIR;
    $ENV:DEVCONTAINER_DIR = $DEVCONTAINER_DIR;
    $ENV:VSCODE_DIR = $VSCODE_DIR;
    $ENV:GIT_EXE = $GIT_EXE;
    $ENV:DOCKER_EXE = $DOCKER_EXE;
    $ENV:VSCODE_CLI_EXE = $VSCODE_CLI_EXE;
    $ENV:VSCODE_DEV_CONTAINER_CLI_EXE = $VSCODE_DEV_CONTAINER_CLI_EXE;
    $ENV:PWSH_EXE = $PWSH_EXE;
    $ENV:PWSH_MANAGE_ENV_DIR = $PWSH_MANAGE_ENV_DIR;
    $ENV:PWSH_MANAGE_TMP_DIR = $PWSH_MANAGE_TMP_DIR;
    $ENV:PWSH_MANAGE_DEP_DIR = $PWSH_MANAGE_DEP_DIR;
    $ENV:PWSH_MANAGE_MAIN_SCRIPT = $PWSH_MANAGE_MAIN_SCRIPT;
    $ENV:PWSH_SCRIPTS_VERSION = $PWSH_SCRIPTS_VERSION;
    $ENV:PWSH_SCRIPTS_DIR = $PWSH_SCRIPTS_DIR;
    $ENV:YQ_EXE = $YQ_EXE;
    $ENV:YQ_VERSION = $YQ_VERSION;
    $ENV:HJSON_EXE = $HJSON_EXE;
    $ENV:HJSON_VERSION = $HJSON_VERSION;
    $ENV:BAKE_PROJECT_NAME = $DOCKER_BAKE_PROJECT_NAME;
    $ENV:BAKE_IMAGE_LOCAL_REGISTRY = $DOCKER_BAKE_IMAGE_LOCAL_REGISTRY;
    $ENV:COMPOSE_PROJECT_NAME = $DOCKER_COMPOSE_PROJECT_NAME;
    
    # Ensure temporary directory is removed and created anew.
    Remove-Item -Path "$PWSH_MANAGE_TMP_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
    New-Item "$PWSH_MANAGE_TMP_DIR" -ItemType Directory -Force | Out-Null;
}

try
{
    # Ensure the local dependencies are installed.
    Install-LocalDependencies;
    
    # Ensure the minimal modules are imported.
    Import-Module -Name "$($ENV:PWSH_SCRIPTS_DIR)/modules/commons.psm1" -Force -Function Write-Log;
    
    # Check if running logic per application commands.
    if ($PSBoundParameters.ContainsKey("Script"))
    {
        # Check that application management script exists.
        $appScriptPath = Join-Path -Path "$ROOT_DIR" -ChildPath "manage.$Script.ps1";
        if (-not (Test-Path -Path "$appScriptPath"))
        {
            throw "No application management script 'manage.$Script.ps1' found.";
        }
        
        # Remove the unbound collection of parameters from the bound parameters if it exists.
        $PSBoundParameters.Remove("PSUnboundParameters") | Out-Null;
        # Remove the bound application management script ID from the bound parameters if it exists.
        $PSBoundParameters.Remove("Script") | Out-Null;
        
        # Execute each of application scripts found, forwarding the bound and unbound parameters.
        & "$($ENV:PWSH_EXE)" -File "$appScriptPath" @PSBoundParameters @PSUnboundParameters;
    }
    # Check if running logic per main commands.
    elseif ($Command -eq "pwsh-load")
    {
        Write-Log "Importing PowerShell modules...";
        
        # Import only the modules in the first level directory, considered the main ones.
        Get-ChildItem -Path "$($ENV:PWSH_SCRIPTS_DIR)/modules" -Filter "*.psm1" -File | ForEach-Object {
            Import-Module -Name "$($_.FullName)" -Force;
        };
        
        Write-Log "PowerShell modules imported." "Success";
    }
    elseif ($Command -eq "git")
    {
        Write-Log "Executing Git...";

        # Execute Git forwarding arguments.
        & "$($ENV:GIT_EXE)" @PSUnboundParameters;

        Write-Log "Git executed with success." "Success";
    }
    elseif ($Command -eq "git-clean")
    {
        Write-Log "Cleaning main Git repository...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "git" clean -dfx;

        Write-Log "Cleaning submodules recursively in main Git repository...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "git" submodule foreach --recursive "`"$($ENV:GIT_EXE)`"" clean -dfx;
    }
    elseif ($Command -eq "docker")
    {
        Write-Log "Executing Docker...";

        # Execute Docker forwarding arguments.
        & "$($ENV:DOCKER_EXE)" @PSUnboundParameters;

        Write-Log "Docker executed with success." "Success";
    }
    elseif ($Command -eq "docker-print")
    {
        Write-Log "Printing Docker version...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" --version;

        Write-Log "Printing Docker Compose version...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" compose version;
        
        Write-Log "Printing containers...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" container list --all --size;

        Write-Log "Printing images...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" image list --all --digests --no-trunc;

        Write-Log "Printing volumes...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" volume list;
        
        Write-Log "Printing networks...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" network list --no-trunc;
        
        Write-Log "Printing compose projects...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" compose ls --all;
    }
    elseif ($Command -eq "docker-clean")
    {
        Write-Log "Cleaning stopped containers...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" container prune --force;

        Write-Log "Cleaning dangling and unused images...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" image prune --all --force;
        
        Write-Log "Cleaning anonymous volumes...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" volume prune --force;
        
        Write-Log "Cleaning unused networks...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" network prune --force;
        
        Write-Log "Cleaning builder cache...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" builder prune --all --force;
    }
    elseif ($Command -eq "docker-bake")
    {
        # Collect all the bake files.
        $bakeHclFiles = New-SortedFileSet "$($ENV:DEVCONTAINER_DIR)" "bake" "hcl" "$($ENV:BAKE_FILE_SELECTORS)";
        # Build parameters.
        $filesParam = ($bakeHclFiles | ForEach-Object { "--file"; "$_"; });
        # Execute Docker Bake.
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" bake --progress=plain @filesParam @PSUnboundParameters;
    }
    elseif ($Command -eq "docker-bake-print")
    {
        Write-Log "Printing Docker Bake files...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" --print "${DOCKER_BAKE_TARGET}";

        Write-Log "Printing Docker Bake targets...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" --list targets "${DOCKER_BAKE_TARGET}";

        Write-Log "Printing Docker Bake variables...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" --list variables "${DOCKER_BAKE_TARGET}";
    }
    elseif ($Command -eq "docker-bake-lint")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" --check "${DOCKER_BAKE_TARGET}";
    }
    elseif ($Command -eq "docker-bake-build")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" "${DOCKER_BAKE_TARGET}";
    }
    elseif ($Command -eq "docker-bake-rebuild")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" --no-cache "${DOCKER_BAKE_TARGET}";
    }
    elseif ($Command -eq "docker-bake-push")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-bake" --push "${DOCKER_BAKE_TARGET}";
    }
    elseif ($Command -eq "docker-compose")
    {
        # Collect all the compose extension files, and concatenate their contents.
        $extContents = (New-SortedFileSet "$($ENV:DEVCONTAINER_DIR)" "compose-ext" "yml" "$($ENV:COMPOSE_EXT_FILE_SELECTORS)" |
            ForEach-Object {
                # Print file found for informational purposes.
                Write-Host "Found: '$([System.IO.Path]::GetRelativePath("$($ENV:DEVCONTAINER_DIR)", "$_"))'...";
                # Read content and append it to array for concatenation.
                Get-Content -Path "$_" -Encoding "utf8" -Raw;
            }) -join "`n";
        # Perform a YAML deep merge (arrays replaced, map keys replaced recursively) of the concatenated extension contents.
        $extContents = $extContents | & "$($ENV:YQ_EXE)" eval-all --output-format yaml '. as $item ireduce ({}; . * $item)';
        # Strip all comments from the output to reduce size.
        $extContents = $extContents | & "$($ENV:YQ_EXE)" eval --output-format yaml '... comments=""';
        # Save the deep merged contents to file.
        $extConcatenatedFile = Join-Path -Path "$($ENV:PWSH_MANAGE_TMP_DIR)" -ChildPath "$(New-Guid)";
        Set-Content -Path "$extConcatenatedFile" -Value $extContents -Encoding "utf8" -Force;

        # Collect all the compose files.
        $composeYamlFiles = New-SortedFileSet "$($ENV:DEVCONTAINER_DIR)" "compose" "yml" "$($ENV:COMPOSE_FILE_SELECTORS)";
        # Create temporary files for all the compose files, with the extension contents prepended.
        $tmpFiles = $composeYamlFiles | ForEach-Object {
            # Print file found for informational purposes.
            Write-Host "Found: '$([System.IO.Path]::GetRelativePath("$($ENV:DEVCONTAINER_DIR)", "$_"))'...";
            # Set contents of file, with the deep merged extensions prepended, and the contents of compose YAML next.
            $tmpFile = Join-Path -Path "$($ENV:PWSH_MANAGE_TMP_DIR)" -ChildPath "$(New-Guid)";
            $tmpContents = (Get-Content -Path "$extConcatenatedFile" -Encoding "utf8" -Raw) +
                           "`n" +
                           (Get-Content -Path "$_" -Encoding "utf8" -Raw);
            Set-Content -Path "$tmpFile" -Value "$tmpContents" -Encoding "utf8" -Force;
            # Return the path to the file created to pass it to Docker Compose.
            $tmpFile;
        };
        
        # Build parameters.
        $filesParam = ($tmpFiles | ForEach-Object { "--file"; "$_"; });
        # Execute Docker Compose.
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker" compose --progress=plain --project-name "$DOCKER_COMPOSE_PROJECT_NAME" @filesParam @PSUnboundParameters;
    }
    elseif ($Command -eq "docker-compose-print")
    {
        # Do not attempt to resolve anything, provide the Compose files as they will be parsed.
        $noResolveOpts = @("--no-path-resolution", "--no-env-resolution", "--no-interpolate");
        
        Write-Log "Printing Docker Compose files...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" config @noResolveOpts "${DOCKER_COMPOSE_SERVICE}";

        Write-Log "Printing Docker Compose variables...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" config @noResolveOpts --variables "${DOCKER_COMPOSE_SERVICE}";

        Write-Log "Printing Docker Compose images...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" config @noResolveOpts --images "${DOCKER_COMPOSE_SERVICE}";

        Write-Log "Printing Docker Compose services...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" config @noResolveOpts --services "${DOCKER_COMPOSE_SERVICE}";

        Write-Log "Printing Docker Compose volumes...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" config @noResolveOpts --volumes "${DOCKER_COMPOSE_SERVICE}";

        Write-Log "Printing Docker Compose networks...";
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" config @noResolveOpts --networks "${DOCKER_COMPOSE_SERVICE}";
    }
    elseif ($Command -eq "docker-compose-create")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" create --no-recreate --no-build --yes "${DOCKER_COMPOSE_SERVICE}";
    }
    elseif ($Command -eq "docker-compose-start")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" start "${DOCKER_COMPOSE_SERVICE}";
    }
    elseif ($Command -eq "docker-compose-stop")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" stop "${DOCKER_COMPOSE_SERVICE}";
    }
    elseif ($Command -eq "docker-compose-destroy")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "docker-compose" down "${DOCKER_COMPOSE_SERVICE}";
    }
    elseif ($Command -eq "vscode")
    {
        Write-Log "Executing Visual Studio Code CLI...";

        # Execute Visual Studio Code CLI.
        & "$($ENV:VSCODE_CLI_EXE)" @PSUnboundParameters;

        Write-Log "Visual Studio Code CLI executed with success." "Success";
    }
    elseif ($Command -eq "vscode-settings-update")
    {
        Write-Log "Executing Visual Studio Code Settings update...";

        # Collect all the Visual Studio Code JSONC setting files, strip comments from them, convert them from JSONC to JSON.
        $tmpFiles = (New-SortedFileSet "$($ENV:VSCODE_DIR)" "vscode-settings" "json" "$($ENV:VSCODE_SETTINGS_FILE_SELECTORS)") |
            ForEach-Object {
                # Print file found for informational purposes.
                Write-Host "Found: '$([System.IO.Path]::GetRelativePath("$($ENV:VSCODE_DIR)", "$_"))'...";
                # Set contents of file, with the JSON contents.
                $tmpFile = Join-Path -Path "$($ENV:PWSH_MANAGE_TMP_DIR)" -ChildPath "$(New-Guid)";
                $tmpContents = (Get-Content -Path "$_" -Encoding "utf8" -Raw) | & "$($ENV:HJSON_EXE)" -c;
                Set-Content -Path "$tmpFile" -Value "$tmpContents" -Encoding "utf8" -Force;
                # Return the path to the JSON files created to deep merge it.
                $tmpFile;
            };
        # Perform a JSON deep merge (arrays replaced, map keys replaced recursively) of all the extension files to a single file.
        $settingsContents = & "$($ENV:YQ_EXE)" eval-all --output-format json --prettyPrint '. as $item ireduce ({}; . * $item)' @($tmpFiles);
        # Print contents as formatted JSON to output.
        $settingsContents | & "$($ENV:HJSON_EXE)" -j -preserveKeyOrder -quoteAlways;
        # Set contents of settings file, ensuring the output is formatted.
        $settingsContents | & "$($ENV:HJSON_EXE)" -j -preserveKeyOrder -quoteAlways | 
            Set-Content -Path (Join-Path -Path "$($ENV:VSCODE_DIR)" -ChildPath "settings.json") -Encoding "utf8" -Force;

        Write-Log "Visual Studio Code Settings update executed with success." "Success";
    }
    elseif ($Command -eq "vscode-devcontainer")
    {
        Write-Log "Executing Visual Studio Code Dev Container CLI...";

        # Execute Visual Studio Code Dev Container CLI.
        & "$($ENV:VSCODE_DEV_CONTAINER_CLI_EXE)" @PSUnboundParameters;

        Write-Log "Visual Studio Code Dev Container CLI executed with success." "Success";
    }
    elseif ($Command -eq "vscode-devcontainer-open")
    {
        & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "vscode-devcontainer" open ".";
    }
    else
    {
        throw "Invalid combination of CLI arguments provided."
    }
}
finally
{
    if ($initialCall)
    {
        # Ensure temporary directory is removed.
        Remove-Item -Path "$PWSH_MANAGE_TMP_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
        
        # Restore environment to original.
        Restore-EnvironmentSnapshot -Snapshot $envSnapshot;
    }
}
