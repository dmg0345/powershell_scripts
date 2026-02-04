<#
.SYNOPSIS
    Main management script based on PowerShell Core. This script must be executed from the respective bootstrap script.

    Do not edit manually — changes will be overwritten.
#>

# [Initializations] ####################################################################################################
[CmdletBinding(PositionalBinding = $false)]
param (
    # Main command to execute, one of:
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
    $Command = "",

    # TODO: A config parameter that loads details from the YAML file per command, uses 'default'.
    # TODO: A config parameter that loads environment from the YAML file for al commands, uses 'default'.

    # Target for 'docker-bake-*' related commands.
    [Parameter(Mandatory = $false)]
    [Alias("t")]
    [String]
    $BakeTarget = "default",

    # Service for 'docker-compose-*' related commands.
    [Parameter(Mandatory = $false)]
    [Alias("s")]
    [String]
    $ComposeService = "default",

    # The module script identifier for which to redirect the logic.
    [Parameter(Mandatory = $false)]
    [String]
    $Module = "",

    # Mandatory parameter with the PowerShell Core executable as resolved by the bootstrap script.
    [Parameter(Mandatory = $true)]
    [String]
    $ManagementEnvironmentPwsh,

    # Mandatory parameter with the manage environment version as resolved by the bootstrap script.
    [Parameter(Mandatory = $true)]
    [String]
    $ManagementEnvironmentVersion,

    # Mandatory parameter with the platform executing the scripts as resolved by the bootstrap script.
    [Parameter(Mandatory = $true)]
    [ValidateSet("win-x64", "darwin-x64", "linux-x64")]
    [String]
    $ManagementEnvironmentPlatform,

    # Collection of remaining unbound parameters passed.
    [Parameter(ValueFromRemainingArguments = $true)]
    $PSUnboundParameters = @()
)

# Make non-zero exit codes of applications behave with respect to 'ErrorActionPreference'.
$PSNativeCommandUseErrorActionPreference = $true;
# Stop on first error found.
$ErrorActionPreference = "Stop";
# Do not show progress bars.
$ProgressPreference = 'SilentlyContinue';

# [Declarations] #######################################################################################################
# The platform running the management environment, as resolved by the bootstrap script.
$PLATFORM = $ManageEnvironmentPlatform;
# Path to the root directory where the bootstrap scripts are located, must match the bootstrap scripts.
$ROOT_DIR = Resolve-Path -Path (Join-Path -Path "$PSScriptRoot" -ChildPath "..").Path;
# Path to '.devcontainer' directory, can be overriden via '/vscode/<config>/devcontainer'.
$DEVCONTAINER_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".devcontainer";
# Path to '.vscode' directory, can be overriden via '/vscode/<config>/settings'.
$VSCODE_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".vscode";

# Path to the PowerShell Core executable.
$PWSH_EXE = $ManageEnvironmentPwsh;
# Path to the Git executable, must exist in PATH.
$GIT_EXE = (Get-Command -Name "git" -ErrorAction "SilentlyContinue").Source ?? "git";
# Path to the Docker executable, must exist in PATH.
$DOCKER_EXE = (Get-Command -Name "docker" -ErrorAction "SilentlyContinue").Source ?? "docker";
# Path to the Visual Studio Code CLI executable, must exist in PATH.
$VSCODE_EXE = (Get-Command -Name "code" -ErrorAction "SilentlyContinue").Source ?? "code";
# Path to the Visual Studio Code DevContainer CLI executable, must exist in PATH.
$VSCODE_DEVCONTAINER_EXE = (Get-Command -Name "devcontainer" -ErrorAction "SilentlyContinue").Source ?? "devcontainer";

# Path to the PowerShell Core management environment directory, must match the bootstrap scripts.
$PWSH_MANAGE_ENV_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".manage-env";
# Path to a temporary directory within the management environment directory.
$PWSH_MANAGE_ENV_TMP_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "tmp-dir";
# Path to a directory with the local dependencies.
$PWSH_MANAGE_ENV_DEP_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "local-deps";
# Path to the PowerShell Core main management script file (this script), must match the bootstrap scripts.
$PWSH_MANAGE_ENV_MAIN_SCRIPT_FILE = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "manage.main.ps1";
# Path to the locked management environment configuration YAML file, must match the bootstrap scripts.
$PWSH_MANAGE_ENV_LOCK_FILE = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "manage-env.lock.yml";

# PowerShell Core scripts local dependency pinned version.
$PWSH_SCRIPTS_VERSION = $ManageEnvironmentVersion;
# Path to the PowerShell Core scripts local dependency directory.
$PWSH_SCRIPTS_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ChildPath "pwsh-scripts";
# 'yq' CLI utility local dependency pinned version.
$YQ_VERSION = "4.50.1";
# Path to the 'yq' CLI utility local dependency installation directory.
$YQ_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ChildPath "yq";
# Path to the 'yq' CLI utility local dependency, resolved when installed.
$YQ_EXE = $null;
# 'hjson' CLI utility local dependency pinned version.
$HJSON_VERSION = "4.6.0";
# Path to the 'hjson' CLI utility local dependency installation directory.
$HJSON_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ChildPath "hjson";
# Path to the 'hjson' CLI utility local dependency, resolved when installed.
$HJSON_EXE = $null;

# The hash table equivalent of the locked management configuration YAML file, resolved at runtime.
$MANAGE_ENV_CFG = $null;

# Docker Bake project name, can be overriden via 'ENV:BAKE_PROJECT_NAME'.
$DOCKER_BAKE_PROJECT_NAME = (Split-Path -Path "$ROOT_DIR" -Leaf).ToLower().Replace(" ", "-").Replace("_", "-");
# Docker Bake local images registry, can be overriden via 'ENV:BAKE_IMAGE_LOCAL_REGISTRY'.
$DOCKER_BAKE_IMAGE_LOCAL_REGISTRY = "localhost/localuser";

# Docker Compose Project name, can be overriden via 'ENV:COMPOSE_PROJECT_NAME'.
$DOCKER_COMPOSE_PROJECT_NAME = $DOCKER_BAKE_PROJECT_NAME;

# [Internal Functions] #################################################################################################
function Test-LocalDependency
{
    <#
    .DESCRIPTION
        Determines if the PowerShell Core scripts and other local dependencies are available.

    .PARAMETER Dependency
        The local dependency to test. Defaults to all dependencies.

    .OUTPUTS
        True if the system PowerShell Core scripts and the other local dependencies are available and ready for use.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("all", "pwsh-scripts", "yq", "hjson")]
        [String]
        $Dependency = "all"
    )

    # Test for PowerShell Core scripts dependency.
    if ($Dependency -in @("all", "pwsh-scripts"))
    {
        try
        {
            # Get the tag of the PowerShell Core scripts if possible, and ensure it matches expected one.
            $gitTag = & "$GIT_EXE" -C "$PWSH_SCRIPTS_DIR" describe --exact-match --tags HEAD 2>$null;
            if ($gitTag -ne "$PWSH_SCRIPTS_VERSION")
            {
                return $false;
            }
        }
        catch { return $false; }
    }

    # Test for 'yq' CLI utility dependency.
    if ($Dependency -in @("all", "yq"))
    {
        try
        {
            # Get the 'yq' CLI utility version if possible and do a check for expected version.
            $yqVersion = & "$YQ_EXE" --version 2>$null;
            if (-not ($yqVersion -match ".*v$YQ_VERSION`$"))
            {
                return $false;
            }
        }
        catch { return $false; }
    }

    # Test for 'hjson' CLI utility dependency.
    if ($Dependency -in @("all", "hjson"))
    {
        try
        {
            # Get the 'hjson' CLI utility version if possible and do a check for expected version.
            $hjsonVersion = & "$HJSON_EXE" -v 2>$null;
            if (-not ($hjsonVersion -match "^v$HJSON_VERSION`$"))
            {
                return $false;
            }
        }
        catch { return $false; }
    }

    # Dependency installed.
    return $true;
}

function Install-LocalDependency
{
    <#
    .DESCRIPTION
        Installs the PowerShell Core Scripts and other local dependencies if not already installed.

    .PARAMETER Dependency
        The local dependency to install. Defaults to all dependencies.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("all", "pwsh-scripts", "yq", "hjson")]
        [String]
        $Dependency = "all"
    )

    # Check if local dependencies are already installed, and in that case do nothing.
    if (Test-LocalDependency -Dependency "$Dependency")
    {
        return;
    }

    # If the path to the local dependency folder does not exist, ensure it is created.
    New-Item -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ItemType Directory -Force | Out-Null;

    # Create folder specific for downloads in the temporary folder.
    $tmpDlsDir = Join-Path -Path "$PWSH_MANAGE_ENV_TMP_DIR" -ChildPath "$(New-Guid)";
    New-Item -Path "$tmpDlsDir" -ItemType Directory -Force | Out-Null;

    # Install PowerShell Core scripts dependency.
    if ($Dependency -in @("all", "pwsh-scripts"))
    {
        # Remove current PowerShell Core scripts, if any.
        Remove-Item -Path "$PWSH_SCRIPTS_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';

        # Configure the repository for download and installation of the PowerShell Core scripts.
        Write-Output "Installing PowerShell Core scripts '$PWSH_SCRIPTS_VERSION' in local environment...";
        & "$GIT_EXE" clone --quiet --branch "$PWSH_SCRIPTS_VERSION" --depth 1 `
            --shallow-submodules --recurse-submodules `
            "https://github.com/dmg0345/powershell_scripts" "$PWSH_SCRIPTS_DIR";
    }

    # Install 'yq' CLI preprocessor dependency.
    if ($Dependency -in @("all", "yq"))
    {
        # Remove current 'yq' scripts, if any, and create it anew.
        Remove-Item -Path "$YQ_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
        New-Item -Path "$YQ_DIR" -ItemType "Directory" -Force | Out-Null;

        # Configure the repository for download and installation of the PowerShell Core scripts.
        Write-Output "Installing yq CLI tool '$YQ_VERSION' in local environment...";
        switch ($PLATFORM)
        {
            "linux-x64"
            {
                # Download file.
                $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "yq.tar.gz";
                Invoke-WebRequest -OutFile "$outFile" `
                    -Uri "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz";
                # Extract to temporary folder with downloads.
                tar -xzf "$outFile" -C "$tmpDlsDir";
                # Resolve binary filenames from source to destination, and deploy it.
                $srcBinary = Join-Path -Path "$tmpDlsDir" -ChildPath "yq_linux_amd64";
                $destBinary = Join-Path -Path "$YQ_DIR" -ChildPath "yq_linux_amd64";
                Move-Item -Path "$srcBinary" -Destination "$destBinary" -Force;
                # Ensure files have proper permissions.
                chmod +x "$destBinary";
                # Resolve final directory for 'yq' executable.
                $YQ_EXE = $destBinary;
            }
            "darwin-64"
            {
                # Download file.
                $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "yq.tar.gz";
                Invoke-WebRequest -OutFile "$outFile" `
                    -Uri "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_darwin_amd64.tar.gz";
                # Extract to temporary folder with downloads.
                tar -xzf "$outFile" -C "$tmpDlsDir";
                # Resolve binary filenames from source to destination, and deploy it.
                $srcBinary = Join-Path -Path "$tmpDlsDir" -ChildPath "yq_darwin_amd64";
                $destBinary = Join-Path -Path "$YQ_DIR" -ChildPath "yq_darwin_amd64";
                Move-Item -Path "$srcBinary" -Destination "$destBinary" -Force;
                # Ensure files have proper permissions.
                chmod +x "$destBinary";
                # Resolve final directory for 'yq' executable.
                $YQ_EXE = $destBinary;
            }
            "win-x64"
            {
                # Download file.
                $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "yq.zip";
                Invoke-WebRequest -OutFile "$outFile" `
                    -Uri "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_windows_amd64.zip";
                # Extract to temporary folder with downloads.
                Expand-Archive -Path "$outFile" -DestinationPath "$tmpDlsDir";
                # Resolve binary filenames from source to destination, and deploy it.
                $srcBinary = Join-Path -Path "$tmpDlsDir" -ChildPath "yq_windows_amd64.exe";
                $destBinary = Join-Path -Path "$YQ_DIR" -ChildPath "yq_windows_amd64.exe";
                Move-Item -Path "$srcBinary" -Destination "$destBinary" -Force;
                # Resolve final directory for 'yq' executable.
                $YQ_EXE = $destBinary;
            }
            default { throw "Unable to install 'yq' for platform '$PLATFORM'."; }
        }
    }

    # Install 'hjson' CLI preprocessor dependency.
    if ($Dependency -in @("all", "hjson"))
    {
        # Remove current 'hjson' scripts, if any, and create it anew.
        Remove-Item -Path "$HJSON_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
        New-Item -Path "$HJSON_DIR" -ItemType "Directory" -Force | Out-Null;

        # Configure the repository for download and installation of the PowerShell Core scripts.
        Write-Output "Installing hjson CLI tool '$HJSON_VERSION' in local environment...";
        switch ($PLATFORM)
        {
            "linux-x64"
            {
                # Download file.
                $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "hjson.tar.gz";
                Invoke-WebRequest -OutFile "$outFile" `
                    -Uri "https://github.com/hjson/hjson-go/releases/download/v${HJSON_VERSION}/hjson_v${HJSON_VERSION}_linux_amd64.tar.gz";
                # Extract to temporary folder with downloads.
                tar -xzf "$outFile" -C "$tmpDlsDir";
                # Resolve binary filenames from source to destination, and deploy it.
                $srcBinary = Join-Path -Path "$tmpDlsDir" -ChildPath "hjson";
                $destBinary = Join-Path -Path "$HJSON_DIR" -ChildPath "hjson";
                Move-Item -Path "$srcBinary" -Destination "$destBinary" -Force;
                # Ensure files have proper permissions.
                chmod +x "$destBinary";
                # Resolve final directory for 'hjson' executable.
                $HJSON_EXE = $destBinary;
            }
            "darwin-64"
            {
                # Download file.
                $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "hjson.tar.gz";
                Invoke-WebRequest -OutFile "$outFile" `
                    -Uri "https://github.com/hjson/hjson-go/releases/download/v${HJSON_VERSION}/hjson_v${HJSON_VERSION}_linux_amd64.tar.gz";
                # Extract to temporary folder with downloads.
                tar -xzf "$outFile" -C "$tmpDlsDir";
                # Resolve binary filenames from source to destination, and deploy it.
                $srcBinary = Join-Path -Path "$tmpDlsDir" -ChildPath "hjson";
                $destBinary = Join-Path -Path "$HJSON_DIR" -ChildPath "hjson";
                Move-Item -Path "$srcBinary" -Destination "$destBinary" -Force;
                # Ensure files have proper permissions.
                chmod +x "$destBinary";
                # Resolve final directory for 'hjson' executable.
                $HJSON_EXE = $destBinary;
            }
            "win-x64"
            {
                # Download file.
                $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "hjson.zip";
                Invoke-WebRequest -OutFile "$outFile" `
                    -Uri "https://github.com/hjson/hjson-go/releases/download/v${HJSON_VERSION}/hjson_v${HJSON_VERSION}_windows_amd64.zip";
                # Extract to temporary folder with downloads.
                Expand-Archive -Path "$outFile" -DestinationPath "$tmpDlsDir";
                # Resolve binary filenames from source to destination, and deploy it.
                $srcBinary = Join-Path -Path "$tmpDlsDir" -ChildPath "hjson.exe";
                $destBinary = Join-Path -Path "$HJSON_DIR" -ChildPath "hjson.exe";
                Move-Item -Path "$srcBinary" -Destination "$destBinary" -Force;
                # Resolve final directory for 'hjson' executable.
                $HJSON_EXE = $destBinary;
            }
            default { throw "Unable to install 'hjson' for platform '$PLATFORM'."; }
        }
    }

    # Ensure installation completed successfully.
    if (-not (Test-LocalDependencies -Dependency "$Dependency"))
    {
        throw "Installation of local dependency '$Dependency' in local environment failed."
    }

    # Report success in installation.
    Write-Output "Installed local dependency '$Dependency' in local environment.";
}

function Resolve-EnvironmentVariable
{
    <#
    .DESCRIPTION
        Resolves environment variables.

    .OUTPUTS
        A hashtable with the items resolved from the YAML management environment file.
    #>
}

function Resolve-ManagementEnvironment
{
    <#
    .DESCRIPTION
        Resolves the management environment.

    .OUTPUTS
        A hashtable with the items resolved from the YAML management environment file.
    #>

    # Parse the management YAML file to a hash table.
    $manageEnv = Get-Content -Path "$PWSH_MANAGE_ENV_LOCK_FILE" -Encoding "utf8" -Raw |
        & "./.manage-env/local-deps/yq" --output-format json |
        ConvertFrom-Json;

    # Resolve from environment.

    # Resolve from

    return $manageEnv;
}






# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
try
{
    # Ensure the local dependencies are installed.
    Install-LocalDependencies;

    # Ensure the minimal modules are imported.
    Import-Module -Name "$PWSH_SCRIPTS_DIR/modules/commons.psm1" -Force `
        -Function Get-EnvironmentSnapshot `
        -Function Restore-EnvironmentSnapshot `
        -Function Get-OrderedFileSet `
        -Function Write-Log;

    # Get a snapshot of the environment to restore it later.
    $envSnapshot = Get-EnvironmentSnapshot;

    # Resolve the locked management environment configuration YAML file.
    $MANAGE_ENV_CFG = Resolve-ManagementEnvironment;

    # Create environment variables under which to run commands for script execution.
    # $ENV:ROOT_DIR = $ROOT_DIR;
    # $ENV:DEVCONTAINER_DIR = $DEVCONTAINER_DIR;
    # $ENV:VSCODE_DIR = $VSCODE_DIR;
    # $ENV:GIT_EXE = $GIT_EXE;
    # $ENV:DOCKER_EXE = $DOCKER_EXE;
    # $ENV:VSCODE_CLI_EXE = $VSCODE_CLI_EXE;
    # $ENV:VSCODE_DEV_CONTAINER_CLI_EXE = $VSCODE_DEV_CONTAINER_CLI_EXE;
    # $ENV:PWSH_EXE = $PWSH_EXE;
    # $ENV:PWSH_MANAGE_ENV_DIR = $PWSH_MANAGE_ENV_DIR;
    # $ENV:PWSH_MANAGE_TMP_DIR = $PWSH_MANAGE_TMP_DIR;
    # $ENV:PWSH_MANAGE_DEP_DIR = $PWSH_MANAGE_DEP_DIR;
    # $ENV:PWSH_MANAGE_MAIN_SCRIPT = $PWSH_MANAGE_MAIN_SCRIPT;
    # $ENV:PWSH_SCRIPTS_VERSION = $PWSH_SCRIPTS_VERSION;
    # $ENV:PWSH_SCRIPTS_DIR = $PWSH_SCRIPTS_DIR;
    # $ENV:YQ_EXE = $YQ_EXE;
    # $ENV:YQ_VERSION = $YQ_VERSION;
    # $ENV:HJSON_EXE = $HJSON_EXE;
    # $ENV:HJSON_VERSION = $HJSON_VERSION;
    # $ENV:BAKE_PROJECT_NAME = $DOCKER_BAKE_PROJECT_NAME;
    # $ENV:BAKE_IMAGE_LOCAL_REGISTRY = $DOCKER_BAKE_IMAGE_LOCAL_REGISTRY;
    # $ENV:COMPOSE_PROJECT_NAME = $DOCKER_COMPOSE_PROJECT_NAME;

    # Ensure temporary directory is removed and created anew.
    Remove-Item -Path "$PWSH_MANAGE_ENV_TMP_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
    New-Item "$PWSH_MANAGE_ENV_TMP_DIR" -ItemType Directory -Force | Out-Null;

    # Check if running logic per application commands.
    if ($PSBoundParameters.ContainsKey("Module"))
    {
        # TODO: Do this with modules, rather than files.
    }
    # Check if running logic per main commands.
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
        $bakeHclFiles = New-SortedFileSet "$($ENV:DEVCONTAINER_DIR)" "docker-bake" "hcl" "$($ENV:BAKE_FILE_SELECTORS)";
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
        $extContents = (New-SortedFileSet "$($ENV:DEVCONTAINER_DIR)" "docker-compose-ext" "yml" "$($ENV:COMPOSE_EXT_FILE_SELECTORS)" |
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
        $composeYamlFiles = New-SortedFileSet "$($ENV:DEVCONTAINER_DIR)" "docker-compose" "yml" "$($ENV:COMPOSE_FILE_SELECTORS)";
        # Create temporary files for all the compose files, with the extension contents prepended.
        $tmpFiles = $composeYamlFiles | ForEach-Object {
            # Print file found for informational purposes.
            Write-Host "Found: '$([System.IO.Path]::GetRelativePath("$($ENV:DEVCONTAINER_DIR)", "$_"))'...";
            # Set contents of file, with the deep merged extensions prepended, and the contents of compose YAML next.
            $tmpFile = Join-Path -Path "$($ENV:PWSH_MANAGE_TMP_DIR)" -ChildPath "$(New-Guid)";
            $tmpContents = Get-Content -Path "$extConcatenatedFile" -Encoding "utf8" -Raw;
            $tmpContents += "`n";
            $tmpContents += Get-Content -Path "$_" -Encoding "utf8" -Raw;
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
        $tmpFiles = (New-SortedFileSet "$($ENV:VSCODE_DIR)" "vscode-settings" "jsonc" "$($ENV:VSCODE_SETTINGS_FILE_SELECTORS)") |
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
        $settingsContents | & "$($ENV:HJSON_EXE)" -j -preserveKeyOrder -quoteAlways -indentBy "    ";
        # Set contents of settings file, ensuring the output is formatted.
        $settingsContents | & "$($ENV:HJSON_EXE)" -j -preserveKeyOrder -quoteAlways -indentBy "    " |
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
    # Ensure temporary directory is removed.
    Remove-Item -Path "$PWSH_MANAGE_ENV_TMP_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';

    # Restore environment to original, if it did not fail before importing the functions.
    if (Get-Command Restore-EnvironmentSnapshot -ErrorAction "SilentlyContinue")
    {
        Restore-EnvironmentSnapshot -Snapshot $envSnapshot;
    }
}
