# PSScriptAnalyzer Linter tool, for details refer to:
#   - https://github.com/PowerShell/PSScriptAnalyzer
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/rules/readme?view=ps-modules
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules
#   - https://github.com/PowerShell/vscode-powershell/issues/4653
#   - https://github.com/PowerShell/vscode-powershell/issues/3168
#   - https://github.com/PowerShell/vscode-powershell/issues/3024
# Do not edit manually — changes will be overwritten.

# Use configuration settings defaults, do not provide any specific settings, do not enforce line length on scripts.
@{
    Rules = @{
        PSAvoidLongLines = @{
            Enable = $false
            MaximumLineLength = 120
        }
    }
}
