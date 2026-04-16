using System.Text;

using Advantech.Edge.Platform;
using Advantech.Edge.Platform.OnboardSensors;
using Advantech.Edge.Platform.ThermalProtection;

namespace Advantech.Edge.Test.TestTool;

public class ThermalProtectionTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir, bool bypassAdvancedTest = false)
    {
        string testName = "ThermalProtection_Should_GetZoneCapAndConfig_NotThrowException";
        
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
            testItemRows.Add(["Read zone IDs", "N/A", "Feature not supported"]);
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
            testDetails = $"Exception : {e.Message}";
        }
        testItemRows.Add(["Create main board instance", testResult, testDetails]);

        // Test : Get cap by zone id and zone index.
        List<string> getResults = [];
        if (mainBoard is null)
        {
            isTestPass = false;
            testItemRows.Add(["Check supported", "Fail", "Thermal protection is not supported"]);
            testItemRows.Add(["Read zone IDs", "Fail", "Thermal protection is not supported"]);
        }
        else if (mainBoard.ThermalProtection is null)
        {
            isTestPass = true;
            testItemRows.Add(["Check supported", "N/A", "Thermal protection is not supported"]);
            testItemRows.Add(["Read zone IDs", "N/A", "Thermal protection is not supported"]);
        }
        else
        {
            // Get : Zone IDs
            string[] zoneIds = [];
            try
            {
                zoneIds = mainBoard.ThermalProtection.ZoneIds;
                if (zoneIds.Length <= 0)
                {
                    testResult = "N/A";
                    testDetails = "Count : 0";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Count : {zoneIds.Length}";
                }
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read zone IDs", testResult, testDetails]);

            // Get capabilities for each thermal protection zone.
            for (int zoneIndex = 0; zoneIndex < zoneIds.Length; zoneIndex++)
            {
                // Current zone ID
                var zoneId = zoneIds[zoneIndex];

                // Get capabilities by index
                bool resultGetCapByIndex = false;
                ThermalProtectionZoneCap? capByIndex = null;
                try { resultGetCapByIndex = mainBoard.ThermalProtection.TryGetZoneCap(zoneIndex, out capByIndex); }
                catch (Exception) { }

                // Get capabilities by ID
                bool resultGetCapById = false;
                ThermalProtectionZoneCap? capById = null;
                try { resultGetCapById = mainBoard.ThermalProtection.TryGetZoneCap(zoneId, out capById); }
                catch (Exception) { }

                // Get config by index
                bool resultGetConfigByIndex = false;
                ThermalProtectionZoneConfig? configByIndex = null;
                try { resultGetConfigByIndex = mainBoard.ThermalProtection.TryGetZoneConfig(zoneIndex, out configByIndex); }
                catch (Exception) { }

                // Get config by ID
                bool resultGetConfigById = false;
                ThermalProtectionZoneConfig? configById = null;
                try { resultGetConfigById = mainBoard.ThermalProtection.TryGetZoneConfig(zoneId, out configById); }
                catch (Exception) { }

                // Compare results of capabilities
                if (!resultGetCapByIndex || !resultGetCapById)
                {
                    // Store results.
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] Test failed. Fail to get capabilities by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = "Get capability failed";
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Get capability", testResult, testDetails]);
                }
                else if (capByIndex is null || capById is null)
                {
                    // Store results.
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] Test failed. Get null capability by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = "Capability is null";
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Get capability", testResult, testDetails]);
                }
                else
                {
                    isTestPass = capByIndex == capById;
                    testResult = isTestPass ? "Pass" : "Fail";
                    testDetails = isTestPass ? "Index and ID get the same capability" : "Index and ID get different capabilities";

                    var supportEventFlags = new List<string>();
                    if (capByIndex.SupportFlags.HasFlag(ThermalProtectionEventSupportFlags.Shutdown))
                        supportEventFlags.Add("Shutdown");
                    if (capByIndex.SupportFlags.HasFlag(ThermalProtectionEventSupportFlags.Throttle))
                        supportEventFlags.Add("Throttle");
                    if (capByIndex.SupportFlags.HasFlag(ThermalProtectionEventSupportFlags.PowerOff))
                        supportEventFlags.Add("PowerOff");
                    var supportEventFlagsStr = string.Join(", ", supportEventFlags);

                    var supportSources = capByIndex.SupportSources.Select(src => $"{src}");
                    var supportSourceStr = string.Join(", ", supportSources);

                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Get capability", testResult, testDetails]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Capability : SupportFlags", testResult, $"Value : {supportEventFlagsStr}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Capability : SupportSources", testResult, $"Value : {supportSourceStr}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Capability : SendEventTemperatureMaximum", testResult, $"Value : {capByIndex.SendEventTemperatureMaximum}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Capability : SendEventTemperatureMinimum", testResult, $"Value : {capByIndex.SendEventTemperatureMinimum}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Capability : ClearEventTemperatureMaximum", testResult, $"Value : {capByIndex.ClearEventTemperatureMaximum}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Capability : ClearEventTemperatureMinimum", testResult, $"Value : {capByIndex.ClearEventTemperatureMinimum}"]);

                    // Store results.
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] Get Capability");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t SupportFlags : {supportEventFlagsStr}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t SupportSources : {supportSourceStr}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t SendEventTemperatureMaximum : {capByIndex.SendEventTemperatureMaximum}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t SendEventTemperatureMinimum : {capByIndex.SendEventTemperatureMinimum}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t ClearEventTemperatureMaximum : {capByIndex.ClearEventTemperatureMaximum}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t ClearEventTemperatureMinimum : {capByIndex.ClearEventTemperatureMinimum}");

                    var message = isTestPass ?
                        "Test passed : The capability getting by name and index are the same." :
                        "Test failed : The capability getting by name and index are different.";
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] {message}");
                }

                // Compare results of configurations
                if (!resultGetConfigByIndex || !resultGetConfigById)
                {
                    // Store results.
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] Test failed. Fail to get config by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = "Get configuration failed";
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Get configuration", testResult, testDetails]);
                }
                else if (configByIndex is null || configById is null)
                {
                    // Store results.
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] Test failed. Get null config by name or index.");

                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = "Configuration is null";
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Get configuration", testResult, testDetails]);
                }
                else
                {
                    isTestPass = configByIndex == configById;
                    testResult = isTestPass ? "Pass" : "Fail";
                    testDetails = isTestPass ? "Index and ID get the same configuration" : "Index and ID get different configurations";

                    var eventTypeStr = $"{configByIndex.EventType}";

                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Get configuration", testResult, testDetails]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Configuration : EventType", testResult, $"Value : {eventTypeStr}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Configuration : Source", testResult, $"Value : {configByIndex.Source}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Configuration : SendEventTemperature", testResult, $"Value : {configByIndex.SendEventTemperature}"]);
                    testItemRows.Add([$"[Index {zoneIndex}][ID {zoneId}] Configuration : ClearEventTemperature", testResult, $"Value : {configByIndex.ClearEventTemperature}"]);

                    // Store results.
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] Get Configuration");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t EventType : {eventTypeStr}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t Source : {configByIndex.Source}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t SendEventTemperature : {configByIndex.SendEventTemperature}");
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] \t ClearEventTemperature : {configByIndex.ClearEventTemperature}");
                    var message = isTestPass ?
                        "Test passed : The configuration getting by name and index are the same." :
                        "Test failed : The configuration getting by name and index are different.";
                    getResults.Add($"[Index {zoneIndex}][ID {zoneId}] {message}");
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
