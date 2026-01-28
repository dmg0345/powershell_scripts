# PSScriptAnalyzer Linter tool, for details refer to:
#   - https://github.com/PowerShell/PSScriptAnalyzer
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/rules/readme?view=ps-modules
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules
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
