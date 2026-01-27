<#
.SYNOPSIS
    Application management script based on PowerShell Core. This script must be executed from the main script.
#>

# [Initializations] ####################################################################################################
[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter(Mandatory = $false)]
    [Alias("c")]
    [String]
    $Command,

    # Collection of unbound parameters passed.
    [Parameter(ValueFromRemainingArguments = $true)]
    $PSUnboundParameters
)

# Make non-zero exit codes of applications behave with respect to 'ErrorActionPreference'.
$PSNativeCommandUseErrorActionPreference = $true;
# Stop on first error found.
$ErrorActionPreference = "Stop";

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################

# [Execution] ##########################################################################################################
if ($Command -eq "vscode-settings-update")
{
    # Set additional selectors for configurations.
    $ENV:VSCODE_SETTINGS_FILE_SELECTORS=@(
        "ms-vscode.powershell",
        "github.vscode-github-actions",
        "phil294.git-log--graph"
    ) -join ',';
    # Update settings.
    & "$($ENV:PWSH_EXE)" -File "$($ENV:PWSH_MANAGE_MAIN_SCRIPT)" -Command "vscode-settings-update";
}
else
{
    throw "Invalid combination of CLI arguments provided."
}
