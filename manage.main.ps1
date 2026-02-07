<#
.SYNOPSIS
    Main management script based on PowerShell Core. This script must be executed from the respective bootstrap script.

    Do not edit manually — changes will be overwritten.
#>

# [Initializations] ####################################################################################################
[CmdletBinding(PositionalBinding = $false)]
param (
    # The profile to use for the management environment.
    [Parameter(Mandatory = $false)]
    [Alias("p")]
    [String]
    $Profile = "default",

    # Main command to execute, one of:
    #   - 'version': Prints the version of the management environment to the standard output.
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
    #   - 'vscode-sync': Host command, forwards the script arguments to Visual Studio Code Dev Container CLI along with other relevant arguments.
    #   - 'vscode-launch': Host command, forwards the script arguments to Visual Studio Code Dev Container CLI along with other relevant arguments.
    # Any other command line argument combination is redirected towards the management application script.
    [Parameter(Mandatory = $false)]
    [Alias("c")]
    [String]
    $Command = "",

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

    # Mandatory parameter with the management environment version as resolved by the bootstrap script.
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
# Path to the PowerShell Core executable, as resolved by the bootstrap script.
$PWSH_EXE = $ManagementEnvironmentPwsh;
# The platform running the management environment, as resolved by the bootstrap script.
$PLATFORM = $ManagementEnvironmentPlatform;
# Path to the root directory where the bootstrap scripts are located, must match the bootstrap scripts.
$ROOT_DIR = Resolve-Path -Path (Join-Path -Path "$PSScriptRoot" -ChildPath "..");

# Path to the PowerShell Core management environment directory, must match the bootstrap scripts.
$PWSH_MANAGE_ENV_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".manage-env";
# Path to a temporary directory within the management environment directory.
$PWSH_MANAGE_ENV_TMP_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "tmp-dir";
# Path to a directory with the local dependencies.
$PWSH_MANAGE_ENV_DEP_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "local-deps";
# Path to the locked management environment configuration YAML file, must match the bootstrap scripts.
$PWSH_MANAGE_ENV_LOCK_FILE = Join-Path -Path "$PWSH_MANAGE_ENV_DIR" -ChildPath "manage-env.lock.yml";

# PowerShell Core scripts local dependency pinned version,as resolved by the bootstrap scripts.
$PWSH_SCRIPTS_VERSION = $ManagementEnvironmentVersion;
# Path to the PowerShell Core scripts local dependency directory.
$PWSH_SCRIPTS_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ChildPath "pwsh-scripts";
# Path to the PowerShell Core scripts PowerShell modules directory.
$PWSH_SCRIPTS_MODULES_DIR = Join-Path -Path "$PWSH_SCRIPTS_DIR" -ChildPath "modules";
# Path to the PowerShell Core scripts common configurations directory.
$PWSH_SCRIPTS_COMMON_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_DIR" -ChildPath "configs";
# Path to the PowerShell Core scripts user configurations directory.
$PWSH_SCRIPTS_USER_CONFIGS_DIR = Join-Path -Path "$ROOT_DIR" -ChildPath ".manage-env-configs";
# Path to the PowerShell Core scripts local dependency lock file.
$PWSH_SCRIPTS_LOCK_FILE = Join-Path -Path "$PWSH_SCRIPTS_DIR" -ChildPath ".lock";

# Path to the 'yq' CLI utility local dependency installation directory.
$YQ_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ChildPath "yq";
# Path to the 'yq' CLI utility local dependency, resolved at runtime.
$YQ_EXE = $null;
# 'yq' CLI utility local dependency pinned version.
$YQ_VERSION = "4.50.1";
# Path to the 'yq' CLI utility local dependency lock file.
$YQ_LOCK_FILE = Join-Path -Path "$YQ_DIR" -ChildPath ".lock";

# Path to the 'hjson' CLI utility local dependency installation directory.
$HJSON_DIR = Join-Path -Path "$PWSH_MANAGE_ENV_DEP_DIR" -ChildPath "hjson";
# Path to the 'hjson' CLI utility local dependency, resolved at runtime.
$HJSON_EXE = $null;
# 'hjson' CLI utility local dependency pinned version.
$HJSON_VERSION = "4.6.0";
# Path to the 'hjson' CLI utility local dependency lock file.
$HJSON_LOCK_FILE = Join-Path -Path "$HJSON_DIR" -ChildPath ".lock";

# Path to the host Docker executable, resolved at runtime.
$DOCKER_EXE = "docker";
# Docker project name, resolved at runtime.
$DOCKER_PROJECT_NAME = (Split-Path -Path "$ROOT_DIR" -Leaf).ToLower().Replace(" ", "-").Replace("_", "-");
# Path to the Docker Bake common configurations directory.
$DOCKER_BAKE_COMMON_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_COMMON_CONFIGS_DIR" -ChildPath "docker-bake";
# Path to the Docker Bake user configurations directory, resolved at runtime.
$DOCKER_BAKE_USER_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_USER_CONFIGS_DIR" -ChildPath "docker-bake";
# Docker Bake configuration scopes, resolved at runtime.
$DOCKER_BAKE_CONFIG_SCOPES = @();
# Docker Bake local image registry for images not meant to leave the local environment, resolved at runtime.
$DOCKER_BAKE_IMAGE_LOCAL_REGISTRY = "localhost/localuser";
# Docker Bake image registry where to push relevant images, resolved at runtime.
$DOCKER_BAKE_IMAGE_REGISTRY = $DOCKER_BAKE_IMAGE_LOCAL_REGISTRY;
# Path to the Docker Compose common configurations directory.
$DOCKER_COMPOSE_COMMON_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_COMMON_CONFIGS_DIR" -ChildPath "docker-compose";
# Path to the Docker Compose user configurations directory, resolved at runtime.
$DOCKER_COMPOSE_USER_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_USER_CONFIGS_DIR" -ChildPath "docker-compose";
# Docker Compose configuration scopes, resolved at runtime.
$DOCKER_COMPOSE_CONFIG_SCOPES = @();

# Path to the host Visual Studio Code CLI executable, resolved at runtime.
$VSCODE_EXE = "code"
# Path to the Visual Studio Code settings common configurations directory.
$VSCODE_SETTINGS_COMMON_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_COMMON_CONFIGS_DIR" -ChildPath "vscode-settings";
# Path to the Visual Studio Code settings user configurations directory, resolved at runtime.
$VSCODE_SETTINGS_USER_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_USER_CONFIGS_DIR" -ChildPath "vscode-settings";
# Visual Studio Code settings configuration scopes, resolved at runtime.
$VSCODE_SETTINGS_CONFIG_SCOPES = @();
# Visual Studio Code settings deployment file, resolved at runtime.
$VSCODE_SETTINGS_DEPLOYMENT_FILE = Join-Path -Path "$ROOT_DIR" -ChildPath ".vscode" "settings.json";
# Path to the host Visual Studio Code Dev Container CLI executable, resolved at runtime.
$VSCODE_DEV_CONTAINER_EXE = "devcontainer";
# Path to the Visual Studio Code Dev Container settings common configurations directory.
$VSCODE_DEV_CONTAINER_SETTINGS_COMMON_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_COMMON_CONFIGS_DIR" -ChildPath "vscode-dev-container-settings";
# Path to the Visual Studio Code Dev Container settings user configurations directory, resolved at runtime.
$VSCODE_DEV_CONTAINER_SETTINGS_USER_CONFIGS_DIR = Join-Path -Path "$PWSH_SCRIPTS_USER_CONFIGS_DIR" -ChildPath "vscode-dev-container-settings";
# Visual Studio Code Dev Container settings configuration scopes, resolved at runtime.
$VSCODE_DEV_CONTAINER_SETTINGS_CONFIG_SCOPES = @();
# Visual Studio Code Dev Container settings deployment file, resolved at runtime.
$VSCODE_DEV_CONTAINER_SETTINGS_DEPLOYMENT_FILE = Join-Path -Path "$ROOT_DIR" -ChildPath ".devcontainer" "devcontainer.json";

# Git username to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_GIT_USERNAME = $null;
# Git email to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_GIT_EMAIL = $null;
# Path in the host to Git SSH signing key to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_GIT_SSH_SIGN_KEY_FILE = $null;
# GitHub username to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_GITHUB_USERNAME = $null;
# Path in the host to GitHub SSH authentication key to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_GITHUB_SSH_AUTH_KEY_FILE = $null;
# VNC server plain text  password to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_VNC_SERVER_PASSWORD = $null;
# VNC server geometry to use in Dev Container, resolved at runtime.
$DEV_CONTAINER_VNC_SERVER_GEOMETRY = $null;

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
            # Attempt to read the contents of the lock file, and check if there is a version match.
            $lockContents = Get-Content -Path "$PWSH_SCRIPTS_LOCK_FILE" -Raw -Encoding "utf8";
            ($lockVersion, $lockPlatform) = $lockContents -split ":";
            if (($lockVersion -ne "$PWSH_SCRIPTS_VERSION") -or ($lockPlatform -ne "$PLATFORM"))
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
            # Attempt to read the contents of the lock file, and check if there is a version match.
            $lockVersion = Get-Content -Path "$YQ_LOCK_FILE" -Raw -Encoding "utf8";
            ($lockVersion, $lockPlatform, $lockPathExe) = $lockContents -split ":";
            if (($lockVersion -ne "$YQ_VERSION") -or ($lockPlatform -ne "$PLATFORM"))
            {
                return $false;
            }
            # Resolve executable path from locked file.
            $YQ_EXE = $lockPathExe;
        }
        catch { return $false; }
    }

    # Test for 'hjson' CLI utility dependency.
    if ($Dependency -in @("all", "hjson"))
    {
        try
        {
            # Attempt to read the contents of the lock file, and check if there is a version match.
            $lockVersion = Get-Content -Path "$HJSON_LOCK_FILE" -Raw -Encoding "utf8";
            ($lockVersion, $lockPlatform, $lockPathExe) = $lockContents -split ":";
            if (($lockVersion -ne "$HJSON_VERSION") -or ($lockPlatform -ne "$PLATFORM"))
            {
                return $false;
            }
            # Resolve executable path from locked file.
            $HJSON_EXE = $lockPathExe;
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
        # Remove current PowerShell Core scripts, if any, and create it anew.
        Remove-Item -Path "$PWSH_SCRIPTS_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
        New-Item -Path "$PWSH_SCRIPTS_DIR" -ItemType "Directory" -Force | Out-Null;

        # Download from Git Archive API exposed in GitHub, so that a Git dependency is not needed.
        Write-Output "Installing PowerShell Core scripts '$PWSH_SCRIPTS_VERSION' in local environment...";

        # Select correct namespace in Git archive URL scheme by inferring tag versioning format.
        if ($PWSH_SCRIPTS_VERSION -match "^[0-9]*\.[0-9]*\.[0-9]*$") { $dlPath = "tags/$PWSH_SCRIPTS_VERSION"; }
        else { $dlPath = "heads/$PWSH_SCRIPTS_VERSION"; }

        # Download file.
        $outFile = Join-Path -Path "$tmpDlsDir" -ChildPath "pwsh-scripts.tar.gz";
        Invoke-WebRequest -OutFile "$outFile" `
            -Uri "https://github.com/dmg0345/powershell_scripts/archive/refs/${dlPath}.tar.gz";
        # Extract to destination folder.
        tar -xzf "$outFile" --strip-components 1 -C "$PWSH_SCRIPTS_DIR";

        # Ensure the lock file is created after success.
        Set-Content -Path "$PWSH_SCRIPTS_LOCK_FILE" -Value "${PWSH_SCRIPTS_VERSION}:${PLATFORM}" -NoNewline -Encoding "utf8";
    }

    # Install 'yq' CLI preprocessor dependency.
    if ($Dependency -in @("all", "yq"))
    {
        # Remove current 'yq' scripts, if any, and create it anew.
        Remove-Item -Path "$YQ_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
        New-Item -Path "$YQ_DIR" -ItemType "Directory" -Force | Out-Null;

        # Perform download and installation depending on platform.
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

        # Ensure the lock file is created after success.
        Set-Content -Path "$YQ_LOCK_FILE" -Value "${YQ_VERSION}:${PLATFORM}:${YQ_EXE}" -NoNewline -Encoding "utf8";
    }

    # Install 'hjson' CLI preprocessor dependency.
    if ($Dependency -in @("all", "hjson"))
    {
        # Remove current 'hjson' scripts, if any, and create it anew.
        Remove-Item -Path "$HJSON_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
        New-Item -Path "$HJSON_DIR" -ItemType "Directory" -Force | Out-Null;

        # Perform download and installation depending on platform.
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

        # Ensure the lock file is created after success.
        Set-Content -Path "$HJSON_LOCK_FILE" -Value "${HJSON_VERSION}:${PLATFORM}:${HJSON_EXE}" -NoNewline -Encoding "utf8";
    }

    # Ensure installation completed successfully.
    if (-not (Test-LocalDependency -Dependency "$Dependency"))
    {
        throw "Installation of local dependency '$Dependency' in local environment failed."
    }

    # Report success in installation.
    Write-Output "Installed local dependency '$Dependency' in local environment.";
}

function Resolve-ManagementEnvironment
{
    <#
    .DESCRIPTION
        Resolves a profile definition in a management environment.

    .PARAMETER Profile
        The profile in the management environment configuration file to resolve.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $ProfileIdentifier
    )

    # Parse and resolve the management YAML file to a hash table.
    $manageEnv = Get-Content -Path "$PWSH_MANAGE_ENV_LOCK_FILE" -Encoding "utf8" -Raw |
        & "$YQ_EXE" --output-format json |
        ConvertFrom-Json;

    # Ensure the profiles top level key exists, and also the profile identifier within it.
    if ((-not $manageEnv.ContainsKey("profiles")) -or
        (-not $manageEnv["profiles"].ContainsKey($ProfileIdentifier)))
    {
        throw "Could not find profile '$ProfileIdentifier' in management environment configuration YAML file."
    }
    $p = $manageEnv["profiles"][$ProfileIdentifier];

    # Resolve 'docker' section.
    $pDocker = $p["docker"] ?? @{};
    $DOCKER_EXE ??= $pDocker["cli"];
    $DOCKER_PROJECT_NAME ??= $pDocker["project-name"];
    ## Resolve 'docker:bake' section.
    $pDockerBake = $pDocker["bake"] ?? @{};
    $DOCKER_BAKE_USER_CONFIGS_DIR ??= $pDockerBake["user-configs-dir"];
    $DOCKER_BAKE_CONFIG_SCOPES ??= $pDockerBake["config-scopes"];
    $DOCKER_BAKE_IMAGE_LOCAL_REGISTRY = $pDockerBake["image-local-registry"];
    $DOCKER_BAKE_IMAGE_REGISTRY = $pDockerBake["image-registry"] ?? $DOCKER_BAKE_IMAGE_LOCAL_REGISTRY;
    ## Resolve 'docker:compose' section.
    $pDockerCompose = $pDocker["compose"] ?? @{};
    $DOCKER_COMPOSE_USER_CONFIGS_DIR ??= $pDockerCompose["user-configs-dir"];
    $DOCKER_COMPOSE_CONFIG_SCOPES ??= $pDockerCompose["config-scopes"];

    # Resolve 'vscode' section.
    $pVscode = $p["vscode"] ?? @{};
    $VSCODE_EXE ??= $pVscode["cli"];
    ## Resolve 'vscode:settings' section.
    $pVscodeSettings = $pVscode["settings"] ?? @{};
    $VSCODE_SETTINGS_USER_CONFIGS_DIR ??= $pVscodeSettings["user-configs-dir"];
    $VSCODE_SETTINGS_CONFIG_SCOPES ??= $pVscodeSettings["config-scopes"];
    $VSCODE_SETTINGS_DEPLOYMENT_FILE ??= $pVscodeSettings["deployment-file"];
    ## Resolve 'vscode:dev-container-settings' section.
    $pVsCodeDevContainer = $pVscode["dev-container-settings"] ?? @{};
    $VSCODE_DEV_CONTAINER_EXE ??= $pVsCodeDevContainer["cli"];
    $VSCODE_DEV_CONTAINER_SETTINGS_USER_CONFIGS_DIR ??= $pVsCodeDevContainer["user-configs-dir"];
    $VSCODE_DEV_CONTAINER_SETTINGS_CONFIG_SCOPES ??= $pVsCodeDevContainer["config-scopes"];
    $VSCODE_DEV_CONTAINER_SETTINGS_DEPLOYMENT_FILE ??= $pVsCodeDevContainer["deployment-file"];

    # Resolve 'dev-container' section.
    $pDevContainer = $p["dev-container"] ?? @{};
    ## Resolve 'dev-container:git' section.
    $pDevContainerGit = $pDevContainer["git"] ?? @{};
    $DEV_CONTAINER_GIT_USERNAME ??= $pDevContainerGit["username"];
    $DEV_CONTAINER_GIT_EMAIL ??= $pDevContainerGit["email"];
    $DEV_CONTAINER_GIT_SSH_SIGN_KEY_FILE ??= $pDevContainerGit["ssh-sign-key-file"];
    ## Resolve 'dev-container:github' section.
    $pDevContainerGitHub = $pDevContainer["github"] ?? @{};
    $DEV_CONTAINER_GITHUB_USERNAME ??= $pDevContainerGitHub["username"];
    $DEV_CONTAINER_GITHUB_SSH_AUTH_KEY_FILE ??= $pDevContainerGitHub["ssh-auth-key-file"];
    ## Resolve 'dev-container:vnc-server' section.
    $pDevContainerVncServer = $pDevContainer["vnc-server"] ?? @{};
    $DEV_CONTAINER_VNC_SERVER_PASSWORD ??= $pDevContainerVncServer["password"];
    $DEV_CONTAINER_VNC_SERVER_GEOMETRY ??= $pDevContainerVncServer["geometry"];
}

function Invoke-Docker
{
    <#
    .DESCRIPTION
        Invokes 'docker' with specified arguments.
    #>
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        $Args = @()
    )
    # Execute Docker forwarding arguments.
    & "$DOCKER_EXE" @Args;
}

function Invoke-DockerBake
{
    <#
    .DESCRIPTION
        Invokes 'docker-bake' with specified arguments.

    .PARAMETER NoFiles
        If specified, the Docker Bake configuration files are not resolved nor added to the command.
        Docker Bake configuration Files are added by default.
    #>
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $NoBakeFiles = $false,
        [Parameter(ValueFromRemainingArguments = $true)]
        $Args = @()
    )

    # Check if configuration files have to be added.
    $filesParam = @();
    if (-not $NoFiles)
    {
        # Collect all the common configuration files.
        $commonBakeHclFiles = Get-OrderedFileSet -Path "$DOCKER_BAKE_COMMON_CONFIGS_DIR" `
            -FileSuffix "docker-bake" `
            -FileExtension "hcl" `
            -FileScopes $DOCKER_BAKE_CONFIG_SCOPES;
        # Collect all the user configuration files, don't require them to be ordered.
        $userBakeHclFiles = Get-OrderedFileSet -Path "$DOCKER_BAKE_USER_CONFIGS_DIR" `
            -FileSuffix "docker-bake" `
            -FileExtension "hcl" `
            -FileScopes $DOCKER_BAKE_CONFIG_SCOPES `
            -DisableNumbering;
        # Collect all configuration files, common first and user second.
        $allBakeHclFiles = $commonBakeHclFiles + $userBakeHclFiles;
        # Build parameters for Docker Bake.
        $filesParam = ($allBakeHclFiles | ForEach-Object { "--file"; "$_"; });
    }

    # Execute Docker Bake forwarding arguments.
    Invoke-Docker "bake" --progress=plain @filesParam @Args;
}

function Invoke-DockerCompose
{
    <#
    .DESCRIPTION
        Invokes 'docker-compose' with specified arguments.

    .PARAMETER NoFiles
        If specified, the Docker Compose configuration files are not resolved nor added to the command.
        Docker Compose configuration Files are added by default.
    #>
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $NoComposeFiles = $false,
        [Parameter(ValueFromRemainingArguments = $true)]
        $Args = @()
    )

    # Check if configuration files have to be added.
    $filesParam = @();
    if (-not $NoComposeFiles)
    {
        # Collect all the common Compose extension files.
        $commonComposeExtYmlFiles = Get-OrderedFileSet -Path "$DOCKER_COMPOSE_COMMON_CONFIGS_DIR" `
            -FileSuffix "docker-compose-ext" `
            -FileExtension "yml" `
            -FileScopes $DOCKER_COMPOSE_CONFIG_SCOPES;
        # Collect all the user Compose extension files, don't require them to be ordered.
        $userComposeExtYmlFiles = Get-OrderedFileSet -Path "$DOCKER_BAKE_USER_CONFIGS_DIR" `
            -FileSuffix "docker-compose-ext" `
            -FileExtension "yml" `
            -FileScopes $DOCKER_COMPOSE_CONFIG_SCOPES `
            -DisableNumbering;
        # Collect all the Compose extension files, common first and user second.
        $allComposeExtYmlFiles = $commonComposeExtYmlFiles + $userComposeExtYmlFiles;
        # Get all the Compose extension file contents and join them in a single Compose extension file.
        $extContents = $allComposeExtYmlFiles | ForEach-Object { Get-Content -Path "$_" -Encoding "utf8" -Raw; }
        $extContents = $extContents -join [Environment]::NewLine;
        # Perform a YAML deep merge (arrays replaced, map keys replaced recursively) of the Compose extension file.
        $extContents = $extContents | & "$YQ_EXE" eval-all --output-format yaml '. as $item ireduce ({}; . * $item)';
        # Strip all comments of the Compose extension file from the output to reduce the total size.
        $extContents = $extContents | & "$YQ_EXE" eval --output-format yaml '... comments=""';
        # Save the single Compose extension file contents to file, this file will be prepended to all configurations.
        $extConcatenatedFile = Join-Path -Path "$PWSH_MANAGE_ENV_TMP_DIR" -ChildPath "$(New-Guid)";
        Set-Content -Path "$extConcatenatedFile" -Value "$extContents" -Encoding "utf8" -Force;

        # Collect all the common Compose configuration files.
        $commonComposeYmlFiles = Get-OrderedFileSet -Path "$DOCKER_COMPOSE_COMMON_CONFIGS_DIR" `
            -FileSuffix "docker-compose" `
            -FileExtension "yml" `
            -FileScopes $DOCKER_COMPOSE_CONFIG_SCOPES;
        # Collect all the user Compose configuration files, don't require them to be ordered.
        $userComposeYmlFiles = Get-OrderedFileSet -Path "$DOCKER_BAKE_USER_CONFIGS_DIR" `
            -FileSuffix "docker-compose" `
            -FileExtension "yml" `
            -FileScopes $DOCKER_COMPOSE_CONFIG_SCOPES `
            -DisableNumbering;
        # Collect all the Compose configuration files, common first and user second.
        $allComposeYmlFiles = $commonComposeYmlFiles + $userComposeYmlFiles;
        # Create temporary files for all the compose files, with the extension contents prepended.
        $allComposeYmlProcessed = $allComposeYmlFiles | ForEach-Object {
            # Generate file where to store the contents in the temporary directory.
            $tmpComposeYmlFile = Join-Path -Path "$PWSH_MANAGE_ENV_TMP_DIR" -ChildPath "$(New-Guid)";
            # Generate contents with the concatenated extension contents prepended.
            $tmpComposeYmlContents = Get-Content -Path "$extConcatenatedFile" -Encoding "utf8" -Raw + `
                [Environment]::NewLine + `
                Get-Content -Path "$_" -Encoding "utf8" -Raw;
            Set-Content -Path "$tmpComposeYmlFile" -Value "$tmpComposeYmlContents" -Encoding "utf8" -Force;
            # Return the path to the file created to pass it to Docker Compose.
            $tmpComposeYmlFile;
        };

        # Build parameters for Docker Compose.
        $filesParam = ($allComposeYmlProcessed | ForEach-Object { "--file"; "$_"; });
    }

    # Execute Docker Bake forwarding arguments.
    Invoke-Docker "compose" --progress=plain --project-name "$DOCKER_PROJECT_NAME" @filesParam @Args;
}

function Sync-VisualStudioCodeSettings
{
    <#
    .DESCRIPTION
        Synchronizes Visual Studio Code Settings and Visual Studio Code Dev Container Settings.
    #>
    param ()

    # Collect all the common Visual Studio Code Settings files.
    $commonSettingsJsoncFiles = Get-OrderedFileSet -Path "$VSCODE_SETTINGS_COMMON_CONFIGS_DIR" `
        -FileSuffix "vscode-settings" `
        -FileExtension "jsonc" `
        -FileScopes $VSCODE_SETTINGS_CONFIG_SCOPES;
    # Collect all the user Visual Studio Code Settings files, don't require them to be ordered.
    $userSettingsJsoncFiles = Get-OrderedFileSet -Path "$VSCODE_SETTINGS_USER_CONFIGS_DIR" `
        -FileSuffix "vscode-settings" `
        -FileExtension "jsonc" `
        -FileScopes $VSCODE_SETTINGS_CONFIG_SCOPES `
        -DisableNumbering;
    # Collect all the Visual Studio Code Settings files, common first and user second.
    $allSettingsJsoncFiles = $commonSettingsJsoncFiles + $userSettingsJsoncFiles;
    # Convert all the files from JSONC to JSON, stripping comments from them.
    $allSettingsJsonFiles = $allSettingsJsoncFiles | ForEach-Object {
        # Generate file where to store the contents in the temporary directory.
        $tmpSettingsJsonFile = Join-Path -Path "$PWSH_MANAGE_ENV_TMP_DIR" -ChildPath "$(New-Guid)";
        # Perform the JSONC to JSON conversion and store to file.
        $tmpSettingsJsonContents = (Get-Content -Path "$_" -Encoding "utf8" -Raw) | & "$HJSON_EXE" -c;
        Set-Content -Path "$tmpSettingsJsonFile" -Value "$tmpSettingsJsonContents" -Encoding "utf8" -Force;
        # Return the path to the temporary file.
        $tmpSettingsJsonFile;
    };
    # Perform a JSON deep merge (arrays replaced, map keys replaced recursively) of all the files to a single file.
    $allSettingsJsonContents = & "$YQ_EXE" eval-all --output-format json '. as $item ireduce ({}; . * $item)' @allSettingsJsonFiles;
    # Perform formatting to pretty printed JSON.
    $allSettingsJsonContents = $allSettingsJsonContents | & "$HJSON_EXE" -j -preserveKeyOrder -quoteAlways -indentBy "    ";
    # Store in destination deployment file.
    Set-Content -Path "$VSCODE_SETTINGS_DEPLOYMENT_FILE" -Value $allSettingsJsonContents -Encoding "utf8" -Force;

    # Collect all the common Visual Studio Code Dev Container Settings files.
    $commonDevContainerSettingsJsoncFiles = Get-OrderedFileSet -Path "$VSCODE_DEV_CONTAINER_SETTINGS_COMMON_CONFIGS_DIR" `
        -FileSuffix "vscode-dev-container-settings" `
        -FileExtension "jsonc" `
        -FileScopes $VSCODE_DEV_CONTAINER_SETTINGS_CONFIG_SCOPES;
    # Collect all the user Visual Studio Code Dev Container Settings files, don't require them to be ordered.
    $userDevContainerSettingsJsoncFiles = Get-OrderedFileSet -Path "$VSCODE_DEV_CONTAINER_SETTINGS_USER_CONFIGS_DIR" `
        -FileSuffix "vscode-dev-container-settings" `
        -FileExtension "jsonc" `
        -FileScopes $VSCODE_DEV_CONTAINER_SETTINGS_CONFIG_SCOPES `
        -DisableNumbering;
    # Collect all the Visual Studio Code Dev Container Settings files, common first and user second.
    $allDevContainerSettingsJsoncFiles = $commonDevContainerSettingsJsoncFiles + $userDevContainerSettingsJsoncFiles;
    # Convert all the files from JSONC to JSON, stripping comments from them.
    $allDevContainerSettingsJsonFiles = $allDevContainerSettingsJsoncFiles | ForEach-Object {
        # Generate file where to store the contents in the temporary directory.
        $tmpDevContainerSettingsJsonFile = Join-Path -Path "$PWSH_MANAGE_ENV_TMP_DIR" -ChildPath "$(New-Guid)";
        # Perform the JSONC to JSON conversion and store to file.
        $tmpDevContainerSettingsJsonContents = (Get-Content -Path "$_" -Encoding "utf8" -Raw) | & "$HJSON_EXE" -c;
        Set-Content -Path "$tmpDevContainerSettingsJsonFile" -Value "$tmpDevContainerSettingsJsonContents" -Encoding "utf8" -Force;
        # Return the path to the temporary file.
        $tmpDevContainerSettingsJsonFile;
    };
    # Perform a JSON deep merge (arrays replaced, map keys replaced recursively) of all the files to a single file.
    $allDevContainerSettingsJsonContents = & "$YQ_EXE" eval-all --output-format json '. as $item ireduce ({}; . * $item)' @allDevContainerSettingsJsonFiles;
    # Perform formatting to pretty printed JSON.
    $allDevContainerSettingsJsonContents = $allDevContainerSettingsJsonContents | & "$HJSON_EXE" -j -preserveKeyOrder -quoteAlways -indentBy "    ";
    # Store in destination deployment file.
    Set-Content -Path "$VSCODE_DEV_CONTAINER_SETTINGS_DEPLOYMENT_FILE" -Value $allDevContainerSettingsJsonContents -Encoding "utf8" -Force;
}

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
try
{
    # Ensure temporary directory is removed and created anew.
    Remove-Item -Path "$PWSH_MANAGE_ENV_TMP_DIR" -Force -Recurse -ErrorAction 'SilentlyContinue';
    New-Item "$PWSH_MANAGE_ENV_TMP_DIR" -ItemType Directory -Force | Out-Null;

    # Install all the local dependencies first.
    Install-LocalDependency -Dependency 'all';

    # Ensure the minimal modules are imported.
    Import-Module -Name "$PWSH_SCRIPTS_MODULES_DIR/commons.psm1" -Force -Function `
        Get-EnvironmentSnapshot, `
        Restore-EnvironmentSnapshot, `
        Get-OrderedFileSet, `
        Write-Log;

    # Get a snapshot of the environment to restore it later.
    $envSnapshot = Get-EnvironmentSnapshot;

    # Resolve the locked management environment configuration YAML file.
    Resolve-ManagementEnvironment -ProfileIdentifier "$Profile";

    # Create relevant environment variables for processes.
    $ENV:BAKE_PROJECT_NAME = $DOCKER_PROJECT_NAME;
    $ENV:BAKE_IMAGE_LOCAL_REGISTRY = $DOCKER_BAKE_IMAGE_LOCAL_REGISTRY;
    $ENV:BAKE_IMAGE_REGISTRY = $DOCKER_BAKE_IMAGE_REGISTRY;
    $ENV:COMPOSE_PROJECT_NAME = $DOCKER_PROJECT_NAME;
    $ENV:GIT_USERNAME = $DEV_CONTAINER_GIT_USERNAME;
    $ENV:GIT_EMAIL = $DEV_CONTAINER_GIT_EMAIL;
    $ENV:GIT_SSH_SIGN_KEY_FILE = $DEV_CONTAINER_GIT_SSH_SIGN_KEY_FILE;
    $ENV:GITHUB_USERNAME = $DEV_CONTAINER_GITHUB_USERNAME;
    $ENV:GITHUB_SSH_AUTH_KEY_FILE = $DEV_CONTAINER_GITHUB_SSH_AUTH_KEY_FILE;
    $ENV:VNC_SERVER_PASSWORD = $DEV_CONTAINER_VNC_SERVER_PASSWORD;
    $ENV:VNC_SERVER_GEOMETRY = $DEV_CONTAINER_VNC_SERVER_GEOMETRY;

    # Check if running logic per application commands.
    if ($PSBoundParameters.ContainsKey("Module"))
    {
        # TODO: Do this with modules, rather than files.
    }
    # Check if running logic per main commands.
    elseif ($Command -eq "version")
    {
        Write-Output "$ManagementEnvironmentVersion - $ManagementEnvironmentPlatform";
    }
    elseif ($Command -eq "docker")
    {
        Invoke-Docker @PSUnboundParameters;
    }
    elseif ($Command -eq "docker-print")
    {
        Write-Log "Printing Docker version...";
        Invoke-Docker --version;

        Write-Log "Printing Docker Compose version...";
        Invoke-DockerCompose -NoFiles version;

        Write-Log "Printing containers...";
        Invoke-Docker container list --all --size;

        Write-Log "Printing images...";
        Invoke-Docker image list --all --digests --no-trunc;

        Write-Log "Printing volumes...";
        Invoke-Docker volume list;

        Write-Log "Printing networks...";
        Invoke-Docker network list --no-trunc;

        Write-Log "Printing compose projects...";
        Invoke-DockerCompose -NoFiles ls --all;
    }
    elseif ($Command -eq "docker-clean")
    {
        Write-Log "Cleaning stopped containers...";
        Invoke-Docker container prune --force;

        Write-Log "Cleaning dangling and unused images...";
        Invoke-Docker image prune --all --force;

        Write-Log "Cleaning anonymous volumes...";
        Invoke-Docker volume prune --force;

        Write-Log "Cleaning unused networks...";
        Invoke-Docker network prune --force;

        Write-Log "Cleaning builder cache...";
        Invoke-Docker builder prune --all --force;
    }
    elseif ($Command -eq "docker-bake")
    {
        Invoke-DockerBake @PSUnboundParameters;
    }
    elseif ($Command -eq "docker-bake-print")
    {
        Write-Log "Printing Docker Bake files...";
        Invoke-DockerBake --print "$BakeTarget";

        Write-Log "Printing Docker Bake targets...";
        Invoke-DockerBake --list targets "$BakeTarget";

        Write-Log "Printing Docker Bake variables...";
        Invoke-DockerBake --list variables "$BakeTarget";
    }
    elseif ($Command -eq "docker-bake-lint")
    {
        Invoke-DockerBake --check "$BakeTarget";
    }
    elseif ($Command -eq "docker-bake-build")
    {
        Invoke-DockerBake "$BakeTarget";
    }
    elseif ($Command -eq "docker-bake-rebuild")
    {
        Invoke-DockerBake --no-cache "$BakeTarget";
    }
    elseif ($Command -eq "docker-bake-push")
    {
        Invoke-DockerBake --push "$BakeTarget";
    }
    elseif ($Command -eq "docker-compose")
    {
        Invoke-DockerCompose @PSUnboundParameters;
    }
    elseif ($Command -eq "docker-compose-print")
    {
        # Do not attempt to resolve anything, provide the Compose files as they will be parsed.
        $noResolveOpts = @("--no-path-resolution", "--no-env-resolution", "--no-interpolate");

        Write-Log "Printing Docker Compose files...";
        Invoke-DockerCompose config @noResolveOpts "$ComposeService";

        Write-Log "Printing Docker Compose variables...";
        Invoke-DockerCompose config @noResolveOpts --variables "$ComposeService";

        Write-Log "Printing Docker Compose images...";
        Invoke-DockerCompose config @noResolveOpts --images "$ComposeService";

        Write-Log "Printing Docker Compose services...";
        Invoke-DockerCompose config @noResolveOpts --services "$ComposeService";

        Write-Log "Printing Docker Compose volumes...";
        Invoke-DockerCompose config @noResolveOpts --volumes "$ComposeService";

        Write-Log "Printing Docker Compose networks...";
        Invoke-DockerCompose config @noResolveOpts --networks "$ComposeService";
    }
    elseif ($Command -eq "docker-compose-create")
    {
        Invoke-DockerCompose create --no-recreate --no-build --yes "$ComposeService";
    }
    elseif ($Command -eq "docker-compose-start")
    {
        Invoke-DockerCompose start "$ComposeService";
    }
    elseif ($Command -eq "docker-compose-stop")
    {
        Invoke-DockerCompose stop "$ComposeService";
    }
    elseif ($Command -eq "docker-compose-destroy")
    {
        Invoke-DockerCompose down "$ComposeService";
    }
    elseif ($Command -eq "vscode-sync")
    {
        Sync-VisualStudioCodeSettings;
    }
    elseif ($Command -eq "vscode-start")
    {
        & "$VSCODE_DEV_CONTAINER_EXE" open ".";
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
