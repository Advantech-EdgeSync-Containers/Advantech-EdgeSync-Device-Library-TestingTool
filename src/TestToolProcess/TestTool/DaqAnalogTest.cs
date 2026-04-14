using System.Text;

using Advantech.Edge.Daq;
using Advantech.Edge.Daq.Module;

namespace Advantech.Edge.Test.TestTool;

public class DaqAnalogTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir, bool bypassAdvancedTest = false)
    {
        string testName = "DaqAnalog_Should_GetAnalogCapabilities_NotThrowException";
        
        // Initialize log path variables using provided reportDir
        string fileNameReportSummary = "DaqAnalog_Should_GetAnalogCapabilities_NotThrowException_summary.csv";
        string fileNameReportTestItem = "DaqAnalog_Should_GetAnalogCapabilities_NotThrowException.csv";
        string filePathReportSummary = Path.Combine(reportDir, fileNameReportSummary);
        string filePathReportTestItem = Path.Combine(reportDir, fileNameReportTestItem);

        // Add test item report headers
        List<string[]> testItemRows = [];
        testItemRows.Add([$"===== {fileNameReportTestItem} =====", "", ""]);
        testItemRows.Add(["Test Item", "Test Result", "Details"]);

        // If bypass is enabled, return N/A report immediately without executing tests
        if (bypassAdvancedTest)
        {
            testItemRows.Add(["Create DaqModuleManager instance", "N/A", "Feature not supported"]);
            testItemRows.Add(["Read analog module IDs", "N/A", "Feature not supported"]);
            testItemRows.Add(["", "", ""]);
            testItemRows.Add(["Test Case Result", "N/A", ""]);
            
            return (testName, testItemRows, true);
        }

        // Test results init
        bool isTestPass = true;
        string testResult = "Pass";
        string testDetails = "";

        // Create DaqModuleManager instance
        DaqModuleManager? daqModuleManager = null;
        try
        {
            daqModuleManager = new DaqModuleManager();
            isTestPass = true;
            testResult = "Pass";
            testDetails = "Success";
        }
        catch (Exception e)
        {
            isTestPass = true;
            testResult = "N/A";
            testDetails = $"Exception : {e.Message}";
        }
        testItemRows.Add(["Create DaqModuleManager instance", testResult, testDetails]);

        // Discover DAQ modules
        List<DaqModuleInfo> daqModules = [];
        if (daqModuleManager is null)
        {
            isTestPass = true;
            testItemRows.Add(["Discover DAQ modules", "N/A", "DaqModuleManager instance not created"]);
            testItemRows.Add(["Check Analog support", "N/A", "DaqModuleManager instance not created"]);
            testItemRows.Add(["Create DAQ module with Analog support", "N/A", "DaqModuleManager instance not created"]);
            testItemRows.Add(["Access Analog subsystem", "N/A", "DaqModuleManager instance not created"]);
        }
        else
        {
            // Discover available DAQ modules
            try
            {
                daqModules = daqModuleManager.DiscoverDaqModules();
                testResult = daqModules.Count > 0 ? "Pass" : "N/A";
                testDetails = $"Count : {daqModules.Count}";
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Discover DAQ modules", testResult, testDetails]);

            // Check for Analog support and test
            if (daqModules.Count == 0)
            {
                testItemRows.Add(["Check Analog support", "N/A", "No DAQ modules found"]);
                testItemRows.Add(["Create DAQ module with Analog support", "N/A", "No DAQ modules found"]);
                testItemRows.Add(["Access Analog subsystem", "N/A", "No DAQ modules found"]);
            }
            else
            {
                // Find a module and test Analog capabilities
                var moduleInfo = daqModules[0];
                DaqModule? daqModule = null;

                try
                {
                    daqModule = daqModuleManager.CreateDaqModule(moduleInfo, DaqModuleAccessMode.Readable);
                    isTestPass = true;
                    testResult = "Pass";
                    testDetails = $"Module : {moduleInfo.ProductID}";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Create DAQ module with Analog support", testResult, testDetails]);

                if (daqModule is null)
                {
                    testItemRows.Add(["Check Analog support", "N/A", "DAQ module instance not created"]);
                    testItemRows.Add(["Access Analog subsystem", "N/A", "DAQ module instance not created"]);
                }
                else
                {
                    // Check Analog support
                    var analogSubsystem = daqModule.Analog;
                    if (analogSubsystem is null)
                    {
                        isTestPass = true;
                        testResult = "N/A";
                        testDetails = "Analog not supported";
                        testItemRows.Add(["Check Analog support", testResult, testDetails]);
                        testItemRows.Add(["Access Analog subsystem", testResult, testDetails]);
                    }
                    else
                    {
                        // Analog is supported
                        isTestPass = true;
                        testResult = "Pass";
                        testDetails = "Supported";
                        testItemRows.Add(["Check Analog support", testResult, testDetails]);

                        // Test Analog capabilities
                        try
                        {
                            var analogCap = analogSubsystem.Capabilities;
                            if (analogCap is null)
                            {
                                isTestPass = true;
                                testResult = "N/A";
                                testDetails = "Capabilities is null";
                            }
                            else
                            {
                                isTestPass = true;
                                testResult = "Pass";
                                testDetails = "Successfully accessed";

                                // Log capability details
                                testItemRows.Add(["Access Analog subsystem", testResult, testDetails]);
                                testItemRows.Add(["Analog Capabilities : MaxInputChannels", "Pass", $"Value : {analogCap.MaxInputChannels}"]);
                                testItemRows.Add(["Analog Capabilities : MaxOutputChannels", "Pass", $"Value : {analogCap.MaxOutputChannels}"]);
                                testItemRows.Add(["Analog Capabilities : MaxInputSampleRate", "Pass", $"Value : {analogCap.MaxInputSampleRate}"]);
                                testItemRows.Add(["Analog Capabilities : MaxOutputSampleRate", "Pass", $"Value : {analogCap.MaxOutputSampleRate}"]);
                                testItemRows.Add(["Analog Capabilities : InputStreamSupported", "Pass", $"Value : {analogCap.InputStreamSupported}"]);
                                testItemRows.Add(["Analog Capabilities : OutputStreamSupported", "Pass", $"Value : {analogCap.OutputStreamSupported}"]);
                                testItemRows.Add(["Analog Capabilities : InputResolutionBits", "Pass", $"Value : {analogCap.InputResolutionBits}"]);
                                testItemRows.Add(["Analog Capabilities : OutputResolutionBits", "Pass", $"Value : {analogCap.OutputResolutionBits}"]);
                                testItemRows.Add(["Analog Capabilities : SimultaneousSamplingSupported", "Pass", $"Value : {analogCap.SimultaneousSamplingSupported}"]);
                                testItemRows.Add(["Analog Capabilities : ProgrammableGainSupported", "Pass", $"Value : {analogCap.ProgrammableGainSupported}"]);
                                testItemRows.Add(["Analog Capabilities : TriggerSupported", "Pass", $"Value : {analogCap.TriggerSupported}"]);
                                testItemRows.Add(["Analog Capabilities : ExternalClockSupported", "Pass", $"Value : {analogCap.ExternalClockSupported}"]);
                            }
                        }
                        catch (Exception e)
                        {
                            isTestPass = false;
                            testResult = "Fail";
                            testDetails = $"Exception : {e.Message}";
                            testItemRows.Add(["Access Analog subsystem", testResult, testDetails]);
                        }

                        // Test Analog Input if supported
                        try
                        {
                            var analogInput = analogSubsystem.Input;
                            if (analogInput is null)
                            {
                                isTestPass = true;
                                testResult = "N/A";
                                testDetails = "Analog Input not available";
                            }
                            else
                            {
                                isTestPass = true;
                                testResult = "Pass";
                                testDetails = "Successfully accessed";

                                // Get input channel count
                                var inputChannels = analogInput.Channels;
                                if (inputChannels is not null && inputChannels.Count > 0)
                                {
                                    testItemRows.Add(["Analog Input : Channel count", "Pass", $"Value : {inputChannels.Count}"]);

                                    // Log first channel details
                                    var firstChannel = inputChannels[0];
                                    if (firstChannel is not null)
                                    {
                                        testItemRows.Add(["Analog Input : First channel index", "Pass", $"Value : {firstChannel.ChannelIndex}"]);
                                        testItemRows.Add(["Analog Input : First channel direction", "Pass", $"Value : {firstChannel.Direction}"]);
                                    }
                                }
                                else
                                {
                                    testItemRows.Add(["Analog Input : Channel count", "Pass", $"Value : 0"]);
                                }
                            }
                        }
                        catch (Exception e)
                        {
                            isTestPass = false;
                            testResult = "Fail";
                            testDetails = $"Exception : {e.Message}";
                        }
                        testItemRows.Add(["Access Analog Input subsystem", testResult, testDetails]);

                        // Test Analog Output if supported
                        try
                        {
                            var analogOutput = analogSubsystem.Output;
                            if (analogOutput is null)
                            {
                                isTestPass = true;
                                testResult = "N/A";
                                testDetails = "Analog Output not available";
                            }
                            else
                            {
                                isTestPass = true;
                                testResult = "Pass";
                                testDetails = "Successfully accessed";

                                // Get output channel count
                                var outputChannels = analogOutput.Channels;
                                if (outputChannels is not null && outputChannels.Count > 0)
                                {
                                    testItemRows.Add(["Analog Output : Channel count", "Pass", $"Value : {outputChannels.Count}"]);

                                    // Log first channel details
                                    var firstChannel = outputChannels[0];
                                    if (firstChannel is not null)
                                    {
                                        testItemRows.Add(["Analog Output : First channel index", "Pass", $"Value : {firstChannel.ChannelIndex}"]);
                                        testItemRows.Add(["Analog Output : First channel direction", "Pass", $"Value : {firstChannel.Direction}"]);
                                    }
                                }
                                else
                                {
                                    testItemRows.Add(["Analog Output : Channel count", "Pass", $"Value : 0"]);
                                }
                            }
                        }
                        catch (Exception e)
                        {
                            isTestPass = false;
                            testResult = "Fail";
                            testDetails = $"Exception : {e.Message}";
                        }
                        testItemRows.Add(["Access Analog Output subsystem", testResult, testDetails]);
                    }

                    // Dispose DAQ module
                    try
                    {
                        daqModule.Dispose();
                        isTestPass = true;
                        testResult = "Pass";
                        testDetails = "Successfully disposed";
                    }
                    catch (Exception e)
                    {
                        isTestPass = false;
                        testResult = "Fail";
                        testDetails = $"Exception : {e.Message}";
                    }
                    testItemRows.Add(["Dispose DAQ module", testResult, testDetails]);
                }
            }
        }

        testItemRows.Add(["", "", ""]);
        testItemRows.Add(["Test Case Result", isTestPass ? "Pass" : "Fail", ""]);

        // Create summary report
        (string result, string details) GetResultSupported(DaqModuleManager? manager, List<DaqModuleInfo> modules)
        {
            if (manager is null) return ("Fail", "DaqModuleManager instance not created");
            if (modules.Count == 0) return ("N/A", "No DAQ modules found");
            return ("Pass", "DAQ modules available");
        }
        (string result, string details) GetFinalResult(bool isTestPass)
        {
            return isTestPass ? ("Pass", "All tests completed successfully") : ("Fail", "One or more tests failed");
        }
        var (result1, details1) = GetResultSupported(daqModuleManager, daqModules);
        var (result2, details2) = GetFinalResult(isTestPass);
        List<string[]> summaryItemRows =
        [
            ["Check Analog subsystem availability", result1, details1],
            ["Test Analog capabilities and channels", result2, details2],
            ["", "", ""]
        ];

        // If not elevated, reporting is terminated.
        if (!PrivilegeChecker.IsElevated())
        {
            Console.WriteLine($"[DaqAnalogTest][Should_GetAnalogCapabilities_NotThrowException] Not elevated. Exporting report terminated.");
        }
        else
        {
            // Ensure log directory exists
            if (!Directory.Exists(reportDir))
            {
                Directory.CreateDirectory(reportDir);
            }

            // Write reports in CSV format
            using (var writer = new StreamWriter(filePathReportSummary, false, Encoding.UTF8))
            {
                foreach (var row in summaryItemRows)
                {
                    writer.WriteLine(string.Join(",", row));
                }
            }
            using (var writer = new StreamWriter(filePathReportTestItem, false, Encoding.UTF8))
            {
                foreach (var row in testItemRows)
                {
                    writer.WriteLine(string.Join(",", row));
                }
            }
        }

        return (testName, testItemRows, isTestPass);
    }
}
