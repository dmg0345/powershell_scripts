# PSScriptAnalyzer Linter tool, for details refer to:
#   - https://github.com/PowerShell/PSScriptAnalyzer
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/rules/readme?view=ps-modules
#   - https://learn.microsoft.com/en-gb/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules
#   - https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules#-settings
# Do not edit manually — changes will be overwritten.

@{
    Rules = @{
        PSAvoidLongLines = @{
            Enable = $true
            MaximumLineLength = 120
        }
    }
}
