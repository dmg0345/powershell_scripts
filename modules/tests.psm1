<#
.DESCRIPTION
    Functions related to tests such as test reports or coverage reports for different languages.
#>

# [Initializations] ####################################################################################################

# Stop script on first error found.
$ErrorActionPreference = "Stop";

# Imports.
Import-Module "$PSScriptRoot/commons.psm1";

# [Declarations] #######################################################################################################

# [Internal Functions] #################################################################################################

# [Functions] ##########################################################################################################
function Start-CMockaHTML
{
    <#
    .DESCRIPTION
        From an output log file generated by 'ctest' when running tests with 'CMocka' with CMOCKA_JUNIT_XML_OUTPUT
        enabled, generates a HTML report with 'junit2html'.
        
        Note that tests in CMocka must be executed with 'cmocka_run_group_tests_name' runner, with a valid name.

    .PARAMETER JUnit2HTMLExe
        Path to the 'junit2html' Python module executable.

    .PARAMETER OutputFolder
        Path to the folder with the file 'output.log' with the 'CMocka' output as generated by 'ctest'.

        In this folder, the file 'test_report.html' will be created, along with multiple XML files parsed.

    .OUTPUTS
        This function does not return a value.

    .EXAMPLE
        ctest -VV -O "./tests/.test_results/output.log" --no-tests=error --test-dir "./.cmake_build";
        Start-CMockaHTML -JUnit2HTMLExe "junit2html" -OutputFolder "./tests/.test_results";
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $JUnit2HTMLExe,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $OutputFolder
    )

    # Create path to the log file in the output folder and check it exists.
    $logFile = Join-Path -Path "$OutputFolder" -ChildPath "output.log";
    if (-not (Test-Path $logFile))
    {
        throw "Could not find 'ctest' log file at '$logFile'."
    }
    $logLines = Get-Content -Path "$logFile";

    # Delete every item not the log file in the output folder.
    Get-ChildItem -Path "$OutputFolder" -Exclude "output.log" -Recurse | Remove-Item -Force -Recurse;

    # Loop each line in the log and find XMLs output by CMocka.
    # Note we handle malformed XMLs by skipping them and incomplete XMLs by ignoring them.
    $status = "out_xml"; $xmlCount = 0;
    $xmlLines = New-Object Collections.Generic.List[String]; $xmlPaths = @();
    $activeTestSuiteName = "";
    Write-Log "Parsing output file for XMLs..";
    foreach ($logLine in $logLines)
    {
        if ($status -eq "out_xml")
        {
            # Not in a XML, thus find for the starting line.
            if ($logLine -match "^[0-9]*:.*(<\?xml .*>)") 
            {
                # Found start of XML, so switch state and save start line.
                $xmlLines.Add($matches[1]);
                $status = "in_xml";
                Write-Log "Found start of XML in output log...";
            }
        }
        else
        {
            # Inside a XML, so keep adding lines, it is expected the criteria is matched.
            if ($logLine -match "^[0-9]*: (.*)")
            {
                $xmlLines.Add($matches[1]);
                # Look for beginning of test suite.
                if ($xmlLines[-1] -match "<testsuite[ ]*name=""{1}([^""]*)""{1}")
                {
                    # Grab test suite name.
                    $activeTestSuiteName = $matches[1];
                    Write-Log "Found test suite of name '$activeTestSuiteName'...";
                }
                # Look for beginning of test case.
                elseif ($xmlLines[-1] -match "<testcase[ ]*name=""{1}([^""]*)""{1}")
                {
                    # Add test suite name to test case.
                    $activeTestName = $matches[1];
                    $xmlLines[-1] = $xmlLines[-1] -replace "<testcase", "<testcase classname=`"$activeTestSuiteName`"";
                    Write-Log "Found test case of name '$activeTestName'...";
                }
                # Look for end of testsuites.
                elseif ($xmlLines[-1].StartsWith("</testsuites>"))
                {
                    # Save XML to file.
                    $xmlPath = Join-Path -Path $OutputFolder -ChildPath "xml_$xmlCount.xml";
                    $xmlPaths += $xmlPath;
                    Set-Content -Path "$xmlPath" -Value $xmlLines;
                    Write-Log "Created XML file with test results at '$xmlPath'..." "Success";
                    # Switch status.
                    $xmlCount += 1;
                    $activeTestSuiteName = ""; $xmlLines.Clear(); $status = "out_xml";
                }
            }
            else 
            {
                Write-Log "Malformed XML found in output... skipping to the next XML..." "Error";
                $activeTestSuiteName = ""; $xmlLines.Clear(); $status = "out_xml";
            }
        }
    }

    # If no XMLs collected, then raise error.
    if ($xmlCount -eq 0)
    {
        throw "No XML collected from output file at '$logFile', no report to generate.";
    }
    Write-Log "Obtained $xmlCount from output log file.." "Success";

    # Merge reports into one.
    Write-Log "Merging all XML files and generating HTML report...";
    $xmlAllPath = Join-Path -Path "$OutputFolder" -ChildPath "xml_all.xml";
    $htmlPath = Join-Path -Path "$OutputFolder" -ChildPath "test_report.html";
    & "$JUnit2HTMLExe" --merge "$xmlAllPath" $xmlPaths;
    # Generate report.
    & "$JUnit2HTMLExe" "$xmlAllPath" "$htmlPath"
    if ($LASTEXITCODE -ne 0)
    {
        throw "HTML report could not be generated with junit2html with error '$LASTEXITCODE'.";
    }
    Write-Log "Generated HTML report from output log file." "Success";
}

########################################################################################################################
function Start-FastCov
{
    <#
    .DESCRIPTION
        Runs fastcov to collect coverage files and generates a HTML report afterwards.
        
        All existing coverage files are deleted as a result of this call.

    .PARAMETER FastCovExe
        Path to the 'fastcov' executable.

    .PARAMETER LCovGenHTMLExe
        Path to the lcov 'genhtml' executable.

    .PARAMETER Include
        Filters for the files to include in the HTML report.

    .PARAMETER CoverageDir
        Folder where to store the coverage data and reports.

    .PARAMETER CMakeBuildDir
        Folder with the CMake build distributables.

    .OUTPUTS
        This function does not return a value.

    .EXAMPLE
        Start-FastCov -FastCovExe "fastcov" -LCovGenHTMLExe "genhtml" -Include @("src", "tests") `
            -CoverageDir ".coverage" -CMakeBuildDir ".cmake_build"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FastCovExe,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $LCovGenHTMLExe,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Include,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $CoverageDir,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $CMakeBuildDir
    )

    # Delete coverage directory and create anew.
    if (Test-Path $CoverageDir)
    {
        Remove-Item -Path "$CoverageDir" -Recurse -Force;
    }
    New-Item -Path "$CoverageDir" -ItemType "Directory" -Force | Out-Null;

    # Set the number of cores.
    $numCores = $([System.Environment]::ProcessorCount - 1);

    # Run fastcov and generate coverage files with the results.
    Write-Log "Running fastcov with '$numCores' cores...";
    & "$FastCovExe" `
        --branch-coverage `
        --skip-exclusion-markers `
        --process-gcno `
        --include @Include `
        --dump-statistic `
        --validate-sources `
        --search-directory "$CMakeBuildDir" `
        --jobs $numCores `
        --lcov `
        --output "$(Join-Path -Path "$CoverageDir" -ChildPath "!coverage.info")";
    if ($LASTEXITCODE -ne 0)
    {
        throw "fastcov collection of files finished with error '$LASTEXITCODE'.";
    }
    Write-Log "Finished running fastcov." "Success";

    # Run fastcov again to delete all coverage files.
    Write-Log "Deleting existing coverage files...";
    & "$FastCovExe" --zerocounters --search-directory "$CMakeBuildDir";
    if ($LASTEXITCODE -ne 0)
    {
        throw "fastcov deletion of existing files finished with error '$LASTEXITCODE'.";
    }
    Write-Log "Deleted existing coverage files." "Success";

    # Generate HTML report, this also prints the location of the HTML report when finished.
    Write-Log "Generating coverage HTML report...";
    & "$LCovGenHTMLExe" `
        --output-directory "$CoverageDir" `
        --prefix "$PWD" `
        --show-details `
        --function-coverage `
        --branch-coverage `
        --num-spaces 4 `
        --dark-mode `
        --legend `
        --highlight `
        --header-title "Coverage Report" `
        --footer "" `
        --no-sort `
        "$(Join-Path -Path "$CoverageDir" -ChildPath "!coverage.info")";
    if ($LASTEXITCODE -ne 0)
    {
        throw "Generation of coverage HTML report finished with error '$LASTEXITCODE'.";
    }
    Write-Log "Finished generating coverage HTML report." "Success";
}

# [Execution] ##########################################################################################################
Export-ModuleMember Start-FastCov;
Export-ModuleMember Start-CMockaHTML;
