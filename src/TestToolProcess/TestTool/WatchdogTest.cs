using System.Collections.Concurrent;
using System.Text;

using Advantech.Edge.Platform;
using Advantech.Edge.Platform.Watchdog;

using Microsoft.Extensions.Logging;

namespace Advantech.Edge.Test.TestTool;

public class WatchdogTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir, bool bypassAdvancedTest = false)
    {
        string testName = "Watchdog_Should_GetCapAndConfig_NotThrowException";

        // Initialize log path variables using provided reportDir
        string fileNameReportSummary = $"{testName}_summary.csv";
        string fileNameReportTestItem = $"{testName}.csv";
        string filePathReportSummary = Path.Combine(reportDir, fileNameReportSummary);
        string filePathReportTestItem = Path.Combine(reportDir, fileNameReportTestItem);
        
        // Add test item report headers.
        List<string[]> testItemRows = [];
        testItemRows.Add([$"===== {fileNameReportTestItem} =====", "", ""]);
        testItemRows.Add(["Test Item", "Test Result", "Details"]);

        // If bypass is enabled, return N/A report immediately without executing tests
        if (bypassAdvancedTest)
        {
            testItemRows.Add(["Create main board instance", "N/A", "Feature not supported"]);
            testItemRows.Add(["Read timer IDs", "N/A", "Feature not supported"]);
            testItemRows.Add(["", "", ""]);
            testItemRows.Add(["Test Case Result", "N/A", ""]);
            
            return (testName, testItemRows, true);
        }

        // Test results init
        bool isTestPass = true;
        string testResult = "Pass";
        string testDetails = "";

        // Create main board instance
        MainBoard? mainBoard = null;
        try
        {
            mainBoard = new MainBoard();
            testResult = "Pass";
            testDetails = "Success";
        }
        catch (Exception e)
        {
            isTestPass = false;
            testResult = "Fail";
            testDetails = $"Exception : {e}";
        }
        testItemRows.Add(["Create main board instance", testResult, testDetails]);

        // Test : Get cap by timer id and timer index.
        List<string> getResults = [];
        if (mainBoard is null)
        {
            isTestPass = false;

            testItemRows.Add(["Check supported", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Read timer IDs", "Fail", "Main board instance not created"]);
        }
        else if (mainBoard.Watchdog is null)
        {
            isTestPass = true;

            testItemRows.Add(["Check supported", "N/A", "Watchdog not supported"]);
            testItemRows.Add(["Read timer IDs", "N/A", "Watchdog not supported"]);
        }
        else
        {
            // Get : Timer IDs
            string[] timerIds = [];
            try
            {
                timerIds = mainBoard.Watchdog.TimerIds;
                if (timerIds.Length <= 0)
                {
                    testResult = "N/A";
                    testDetails = "Count : 0";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Count : {timerIds.Length}";
                }
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e}";
            }
            testItemRows.Add([$"Read timer IDs", testResult, testDetails]);

            // Get capabilities for each watchdog timer.
            for (int i = 0; i < timerIds.Length; i++)
            {
                // Current timer ID
                var timerId = timerIds[i];

                // Get capabilities by index
                bool resultGetCapByIndex = false;
                WatchdogTimerCap? capByIndex = null;
                try { resultGetCapByIndex = mainBoard.Watchdog.TryGetCap(i, out capByIndex); }
                catch (Exception) { }

                // Get capabilities by ID
                bool resultGetCapById = false;
                WatchdogTimerCap? capById = null;
                try { resultGetCapById = mainBoard.Watchdog.TryGetCap(timerId, out capById); }
                catch (Exception) { }

                // Get config by index
                bool resultGetConfigByIndex = false;
                WatchdogTimerConfig? configByIndex = null;
                try { resultGetConfigByIndex = mainBoard.Watchdog.TryGetConfig(i, out configByIndex); }
                catch (Exception) { }

                // Get config by ID
                bool resultGetConfigById = false;
                WatchdogTimerConfig? configById = null;
                try { resultGetConfigById = mainBoard.Watchdog.TryGetConfig(timerId, out configById); }
                catch (Exception) { }

                // Compare results of capabilities
                if (!resultGetCapByIndex || !resultGetCapById)
                {
                    // Store results.
                    getResults.Add($"[Index {i}][ID {timerId}] Test failed. Fail to get capabilities by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Get capability failed";
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Get capability", testResult, testDetails]);
                }
                else if (capByIndex is null || capById is null)
                {
                    // Store results.
                    getResults.Add($"[Index {i}][ID {timerId}] Test failed. Get null capability by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Capability is null";
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Get capability", testResult, testDetails]);
                }
                else
                {
                    isTestPass = capByIndex == capById;
                    testResult = isTestPass ? "Pass" : "Fail";
                    testDetails = isTestPass ? $"Index and ID get the same capability" : $"Index and ID get different capabilities";

                    var flags = new List<string>();
                    if (capByIndex.SupportFlags.HasFlag(WatchdogTimerEventSupportFlags.Irq))
                        flags.Add("IRQ");
                    if (capByIndex.SupportFlags.HasFlag(WatchdogTimerEventSupportFlags.Sci))
                        flags.Add("SCI");
                    if (capByIndex.SupportFlags.HasFlag(WatchdogTimerEventSupportFlags.PowerCycle))
                        flags.Add("PowerCycle");
                    if (capByIndex.SupportFlags.HasFlag(WatchdogTimerEventSupportFlags.Pin))
                        flags.Add("Pin");
                    var flagStr = string.Join(", ", flags);

                    testItemRows.Add([$"[Index {i}][ID {timerId}] Get capability", testResult, testDetails]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : IsStoppable", testResult, $"Value : {capByIndex.IsStoppable}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : IsStoppable", testResult, $"Value : {capByIndex.IsStoppable}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : DelayMaximum", testResult, $"Value : {capByIndex.DelayMaximum}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : DelayMinimum", testResult, $"Value : {capByIndex.DelayMinimum}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : EventMaximum", testResult, $"Value : {capByIndex.EventMaximum}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : EventMinimum", testResult, $"Value : {capByIndex.EventMinimum}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : ResetMaximum", testResult, $"Value : {capByIndex.ResetMaximum}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : ResetMinimum", testResult, $"Value : {capByIndex.ResetMinimum}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : Unit", testResult, $"Value : {capByIndex.Unit}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Capability : SupportFlags", testResult, $"Value : {flagStr}"]);

                    // Store results.
                    getResults.Add($"[Index {i}][ID {timerId}] Get Capability");
                    getResults.Add($"[Index {i}][ID {timerId}] \t IsStoppable : {capByIndex.IsStoppable}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t DelayMaximum : {capByIndex.DelayMaximum}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t DelayMinimum : {capByIndex.DelayMinimum}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t EventMaximum : {capByIndex.EventMaximum}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t EventMinimum : {capByIndex.EventMinimum}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t ResetMaximum : {capByIndex.ResetMaximum}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t ResetMinimum : {capByIndex.ResetMinimum}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t Unit : {capByIndex.Unit}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t SupportFlags : {flagStr}");
                    var message = isTestPass ?
                        "Test passed : The capability getting by name and index are the same." :
                        "Test failed : The capability getting by name and index are different.";
                    getResults.Add($"[Index {i}][ID {timerId}] {message}");
                }

                // Compare results of configurations
                if (!resultGetConfigByIndex || !resultGetConfigById)
                {
                    // Store results.
                    getResults.Add($"[Index {i}][ID {timerId}] Test failed. Fail to get config by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Get configuration failed";
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Get configuration", testResult, testDetails]);
                }
                else if (configByIndex is null || configById is null)
                {
                    // Store results.
                    getResults.Add($"[Index {i}][ID {timerId}] Test failed. Get null config by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Configuration is null";
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Get configuration", testResult, testDetails]);
                }
                else
                {
                    isTestPass = configByIndex == configById;
                    testResult = isTestPass ? "Pass" : "Fail";
                    testDetails = isTestPass ? $"Index and ID get the same configuration" : $"Index and ID get different configurations";

                    var eventTypeStr = $"{configByIndex.EventType}";

                    testItemRows.Add([$"[Index {i}][ID {timerId}] Get configuration", testResult, testDetails]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Configuration : Delay", testResult, $"Value : {configByIndex.Delay}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Configuration : Event", testResult, $"Value : {configByIndex.EventTimeout}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Configuration : Reset", testResult, $"Value : {configByIndex.ResetTimeout}"]);
                    testItemRows.Add([$"[Index {i}][ID {timerId}] Configuration : EventType", testResult, $"Value : {eventTypeStr}"]);

                    // Store results.
                    getResults.Add($"[Index {i}][ID {timerId}] Get Configuration");
                    getResults.Add($"[Index {i}][ID {timerId}] \t Delay : {configByIndex.Delay}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t Event : {configByIndex.EventTimeout}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t Reset : {configByIndex.ResetTimeout}");
                    getResults.Add($"[Index {i}][ID {timerId}] \t EventType : {eventTypeStr}");
                    var message = isTestPass ?
                        "Test passed : The configuration getting by name and index are the same." :
                        "Test failed : The configuration getting by name and index are different.";
                    getResults.Add($"[Index {i}][ID {timerId}] {message}");
                }
            }
        }

        testItemRows.Add(["", "", ""]);
        testItemRows.Add(["Test Case Result", isTestPass ? "Pass" : "Fail", ""]);

        // Dispose main board
        if (mainBoard is not null)
        {
            mainBoard.Dispose();
        }

        return (testName, testItemRows, isTestPass);
    }
}
