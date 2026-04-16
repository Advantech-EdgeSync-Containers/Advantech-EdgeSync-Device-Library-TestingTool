using System.Text;
using Advantech.Edge.Platform;
using Advantech.Edge.Platform.BoardInfo;
using Advantech.Edge.Test.TestTool;

//-------------------------------------------------------------
// Helper methods
//-------------------------------------------------------------

/// <summary>
/// Gets the local report directory path
/// </summary>
static string GetLocalReportDirectory()
{
    string reportDir = Path.Combine(AppContext.BaseDirectory, "reports", "CSharp", "log");
    
    // Ensure directory exists
    Directory.CreateDirectory(reportDir);
    
    return reportDir;
}

/// <summary>
/// Gets the global report directory path from command-line arguments.
/// </summary>
static string? GetGlobalReportDirectoryFromArgs(string[] args)
{
    if (args.Length == 0 || string.IsNullOrWhiteSpace(args[0]))
    {
        return null;
    }

    string globalReportDir = args[0];
    if (!Path.IsPathRooted(globalReportDir))
    {
        globalReportDir = Path.Combine(AppContext.BaseDirectory, globalReportDir);
    }

    Directory.CreateDirectory(globalReportDir);
    return globalReportDir;
}

/// <summary>
/// Gets the bypass advanced test flag from command-line arguments.
/// </summary>
static bool GetBypassAdvancedTestFromArgs(string[] args)
{
    if (args.Length < 2 || string.IsNullOrWhiteSpace(args[1]))
    {
        return false;
    }

    return bool.TryParse(args[1], out var result) ? result : false;
}

/// <summary>
/// Clears previous CSV reports from local and optional global report directories.
/// </summary>
static void ClearPreviousReports(string localReportDir, string? globalReportDir)
{
    // Clear local report directory first to ensure it's clean before test run, and also to prevent potential permission issues when the test container
    try
    {
        if (Directory.Exists(localReportDir))
        {
            Directory.Delete(localReportDir, true);

            var deleteDeadline = DateTime.UtcNow.AddSeconds(5);
            while (Directory.Exists(localReportDir) && DateTime.UtcNow < deleteDeadline)
            {
                Thread.Sleep(100);
            }

            if (Directory.Exists(localReportDir))
            {
                throw new IOException($"Timed out waiting for local report directory deletion: {localReportDir}");
            }
        }

        Directory.CreateDirectory(localReportDir);

        var createDeadline = DateTime.UtcNow.AddSeconds(5);
        while (!Directory.Exists(localReportDir) && DateTime.UtcNow < createDeadline)
        {
            Thread.Sleep(100);
        }

        if (!Directory.Exists(localReportDir))
        {
            throw new IOException($"Timed out waiting for local report directory creation: {localReportDir}");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error: Failed to prepare local report directory: {ex.Message}");
        throw new IOException($"Failed to prepare local report directory: {localReportDir}", ex);
    }

    // Clear global report directory if provided - do this after local directory is ready to avoid potential permission issues when test container writes to global directory
    if (!string.IsNullOrEmpty(globalReportDir))
    {
        try
        {
            if (Directory.Exists(globalReportDir))
            {
                Directory.Delete(globalReportDir, true);

                var deleteDeadline = DateTime.UtcNow.AddSeconds(5);
                while (Directory.Exists(globalReportDir) && DateTime.UtcNow < deleteDeadline)
                {
                    Thread.Sleep(100);
                }

                if (Directory.Exists(globalReportDir))
                {
                    throw new IOException($"Timed out waiting for global report directory deletion: {globalReportDir}");
                }
            }

            Directory.CreateDirectory(globalReportDir);

            var createDeadline = DateTime.UtcNow.AddSeconds(5);
            while (!Directory.Exists(globalReportDir) && DateTime.UtcNow < createDeadline)
            {
                Thread.Sleep(100);
            }

            if (!Directory.Exists(globalReportDir))
            {
                throw new IOException($"Timed out waiting for global report directory creation: {globalReportDir}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to prepare global report directory: {ex.Message}");
        }
    }
}

/// <summary>
/// Runs test cases sequentially and prints summary.
/// </summary>
static (List<(string TestName, List<string[]> Rows, bool IsPassed)> AllResults, int PassedCount)
    RunTestsAndPrintSummary(string localReportDir, bool bypassAdvancedTest)
{
    Console.WriteLine("=== Advantech Edge Verification Suite ===");
    Console.WriteLine($"Timestamp: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
    Console.WriteLine("");

    // Create a list to hold all test results
    var allResults = new List<(string TestName, List<string[]> Rows, bool IsPassed)>();

    Console.WriteLine("=== Running Test Tool Cases ===");

    // Run all tests sequentially - pass localReportDir to each test
    allResults.Add(new BoardInfoTest().ExecuteTest(localReportDir));
    allResults.Add(new OnboardSensorsTest().ExecuteTest(localReportDir));
    allResults.Add(new GpioTest().ExecuteTest(localReportDir));
    allResults.Add(new WatchdogTest().ExecuteTest(localReportDir));
    allResults.Add(new ThermalProtectionTest().ExecuteTest(localReportDir));

    // Run advanced tests - if bypassed, convert results to N/A
    allResults.Add(new DaqAnalogTest().ExecuteTest(localReportDir, bypassAdvancedTest));
    allResults.Add(new DaqDigitalTest().ExecuteTest(localReportDir, bypassAdvancedTest));

    Console.WriteLine("Test Tool Cases Completed");

    // Summarize results
    Console.WriteLine("=== Verification Summary ===");
    int passedCount = 0;
    foreach (var (testName, _, isPassed) in allResults)
    {
        Console.WriteLine($"{testName}: {(isPassed ? "PASS" : "FAIL")}");
        if (isPassed) passedCount++;
    }

    Console.WriteLine($"Total: {allResults.Count} | Passed: {passedCount} | Failed: {allResults.Count - passedCount}");
    return (allResults, passedCount);
}

/// <summary>
/// Writes all test reports to local directory first, then copies them to global directory if provided.
/// </summary>
static void WriteReportsToLocalAndCopyToGlobal(
    List<(string TestName, List<string[]> Rows, bool IsPassed)> allResults,
    string localReportDir,
    string? globalReportDir)
{
    Console.WriteLine("Writing test reports to local directory...");

    // Write CSV reports for each test to local directory
    foreach (var (testName, rows, _) in allResults)
    {
        var csv = new StringBuilder();
        foreach (var row in rows)
        {
            csv.AppendLine(string.Join(",", row.Select(f => $"\"{f}\"")));
        }

        string csvPath = "";
        try
        {
            csvPath = Path.Combine(localReportDir, $"{testName}.csv");
            File.WriteAllText(csvPath, csv.ToString());
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: Failed to write report for test '{testName}' to local directory: {ex.Message}");
            continue;
        }

        var writeDeadline = DateTime.UtcNow.AddSeconds(5);
        while (!File.Exists(csvPath) && DateTime.UtcNow < writeDeadline)
        {
            Thread.Sleep(100);
        }

        if (!File.Exists(csvPath))
        {
            throw new TimeoutException($"Timed out waiting for report file to be created: {csvPath}");
        }
    }

    // Copy local reports to global directory after all local reports are written
    if (!string.IsNullOrEmpty(globalReportDir))
    {
        string[] localCsvPaths;
        try
        {
            localCsvPaths = Directory.GetFiles(localReportDir, "*.csv");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to enumerate local report files: {ex.Message}");
            localCsvPaths = Array.Empty<string>();
        }

        foreach (var localCsvPath in localCsvPaths)
        {
            if (!File.Exists(localCsvPath))
            {
                Console.WriteLine($"Warning: Source report file not found, skip copy: {localCsvPath}");
                continue;
            }

            var fileName = Path.GetFileName(localCsvPath);
            var globalCsvPath = Path.Combine(globalReportDir, fileName);
            try
            {
                File.Copy(localCsvPath, globalCsvPath, true);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: Failed to copy report file '{localCsvPath}' to '{globalCsvPath}': {ex.Message}");
            }
        }
    }

    Console.WriteLine("Test reports written successfully.");
}

//-------------------------------------------------------------
// Main execution starts here
//-------------------------------------------------------------

// Get local report directory
string localReportDir = GetLocalReportDirectory();

// Get global report directory from command-line argument (optional)
string? globalReportDir = GetGlobalReportDirectoryFromArgs(args);

// Get bypass advanced test flag from command-line argument (optional)
bool bypassAdvancedTest = GetBypassAdvancedTestFromArgs(args);

// Clear previous reports from local/global output directories
ClearPreviousReports(localReportDir, globalReportDir);

// Run tests and print summary
var (allResults, passedCount) = RunTestsAndPrintSummary(localReportDir, bypassAdvancedTest);

Console.WriteLine("========================================");
Console.WriteLine("");

// Write reports to local directory and copy to global directory if provided
WriteReportsToLocalAndCopyToGlobal(allResults, localReportDir, globalReportDir);

Console.WriteLine("========================================");
Console.WriteLine("");

// Set exit code based on test results (0 if all passed, 1 if any failed)
int exitCode = passedCount == allResults.Count ? 0 : 1;

// Print final exit code for CI/CD pipelines to capture
Console.WriteLine($"Exit Code: {exitCode}");
return exitCode;
