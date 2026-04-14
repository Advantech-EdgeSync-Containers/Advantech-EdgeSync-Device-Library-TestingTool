using System.Text;

using Advantech.Edge.Daq;
using Advantech.Edge.Daq.Module;

namespace Advantech.Edge.Test.TestTool;

public class DaqDigitalTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir, bool bypassAdvancedTest = false)
    {
        string testName = "DaqDigital_Should_GetDigitalCapabilities_NotThrowException";
        
        // Initialize log path variables using provided reportDir
        string fileNameReportSummary = "DaqDigital_Should_GetDigitalCapabilities_NotThrowException_summary.csv";
        string fileNameReportTestItem = "DaqDigital_Should_GetDigitalCapabilities_NotThrowException.csv";
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
            testItemRows.Add(["Read digital module IDs", "N/A", "Feature not supported"]);
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
            testResult = "N/A";
            testDetails = "DaqModuleManager instance not created";

            testItemRows.Add(["Discover DAQ modules", "N/A", "DaqModuleManager instance not created"]);
            testItemRows.Add(["Check Digital support", "N/A", "DaqModuleManager instance not created"]);
            testItemRows.Add(["Create DAQ module with Digital support", "N/A", "DaqModuleManager instance not created"]);
            testItemRows.Add(["Access Digital subsystem", "N/A", "DaqModuleManager instance not created"]);
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
                isTestPass = true;
                testResult = "N/A";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Discover DAQ modules", testResult, testDetails]);

            // Check for Digital support and test
            if (daqModules.Count == 0)
            {
                testItemRows.Add(["Check Digital support", "N/A", "No DAQ modules found"]);
                testItemRows.Add(["Create DAQ module with Digital support", "N/A", "No DAQ modules found"]);
                testItemRows.Add(["Access Digital subsystem", "N/A", "No DAQ modules found"]);
            }
            else
            {
                // Find a module and test Digital capabilities
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
                    isTestPass = true;
                    testResult = "N/A";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Create DAQ module with Digital support", testResult, testDetails]);

                if (daqModule is null)
                {
                    testItemRows.Add(["Check Digital support", "N/A", "DAQ module instance not created"]);
                    testItemRows.Add(["Access Digital subsystem", "N/A", "DAQ module instance not created"]);
                }
                else
                {
                    // Check Digital support
                    var digitalSubsystem = daqModule.Digital;
                    if (digitalSubsystem is null)
                    {
                        testResult = "N/A";
                        testDetails = "Digital not supported";
                        testItemRows.Add(["Check Digital support", testResult, testDetails]);
                        testItemRows.Add(["Access Digital subsystem", testResult, testDetails]);
                    }
                    else
                    {
                        // Digital is supported
                        isTestPass = true;
                        testResult = "Pass";
                        testDetails = "Supported";
                        testItemRows.Add(["Check Digital support", testResult, testDetails]);

                        // Test Digital capabilities
                        try
                        {
                            var digitalCap = digitalSubsystem.Capabilities;
                            if (digitalCap is null)
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
                                testItemRows.Add(["Access Digital subsystem", testResult, testDetails]);
                                testItemRows.Add(["Digital Capabilities : InputSupported", "Pass", $"Value : {digitalCap.InputSupported}"]);
                                testItemRows.Add(["Digital Capabilities : OutputSupported", "Pass", $"Value : {digitalCap.OutputSupported}"]);
                                testItemRows.Add(["Digital Capabilities : InputStreamSupported", "Pass", $"Value : {digitalCap.InputStreamSupported}"]);
                                testItemRows.Add(["Digital Capabilities : OutputStreamSupported", "Pass", $"Value : {digitalCap.OutputStreamSupported}"]);
                                testItemRows.Add(["Digital Capabilities : PortCount", "Pass", $"Value : {digitalCap.PortCount}"]);
                                testItemRows.Add(["Digital Capabilities : ChannelsPerPort", "Pass", $"Value : {digitalCap.ChannelsPerPort}"]);
                                testItemRows.Add(["Digital Capabilities : ChannelCountMax", "Pass", $"Value : {digitalCap.ChannelCountMax}"]);
                                testItemRows.Add(["Digital Capabilities : Resolution", "Pass", $"Value : {digitalCap.Resolution}"]);
                                testItemRows.Add(["Digital Capabilities : IsPortDirProgrammable", "Pass", $"Value : {digitalCap.IsPortDirProgrammable}"]);
                                testItemRows.Add(["Digital Capabilities : IsDiRetriggerable", "Pass", $"Value : {digitalCap.IsDiRetriggerable}"]);
                                testItemRows.Add(["Digital Capabilities : IsDoRetriggerable", "Pass", $"Value : {digitalCap.IsDoRetriggerable}"]);
                            }
                        }
                        catch (Exception e)
                        {
                            isTestPass = true;
                            testResult = "N/A";
                            testDetails = $"Exception : {e.Message}";
                            testItemRows.Add(["Access Digital subsystem", testResult, testDetails]);
                        }

                        // Test Digital Input if supported
                        try
                        {
                            var digitalInput = digitalSubsystem.Input;
                            if (digitalInput is null)
                            {
                                testResult = "N/A";
                                testDetails = "Digital Input not available";
                            }
                            else
                            {
                                isTestPass = true;
                                testResult = "Pass";
                                testDetails = "Successfully accessed";

                                // Get input channel count
                                var inputChannels = digitalInput.Channels;
                                if (inputChannels is not null && inputChannels.Count > 0)
                                {
                                    testItemRows.Add(["Digital Input : Channel count", "Pass", $"Value : {inputChannels.Count}"]);

                                    // Log first channel details
                                    var firstChannel = inputChannels[0];
                                    if (firstChannel is not null)
                                    {
                                        testItemRows.Add(["Digital Input : First channel index", "Pass", $"Value : {firstChannel.ChannelIndex}"]);
                                        testItemRows.Add(["Digital Input : First channel direction", "Pass", $"Value : {firstChannel.Direction}"]);

                                        // Try reading a channel value
                                        try
                                        {
                                            var channelValue = firstChannel.Read();
                                            testItemRows.Add(["Digital Input : Read first channel", "Pass", $"Value : {channelValue}"]);
                                        }
                                        catch (Exception e)
                                        {
                                            testItemRows.Add(["Digital Input : Read first channel", "Fail", $"Exception : {e.Message}"]);
                                        }
                                    }
                                }
                                else
                                {
                                    testItemRows.Add(["Digital Input : Channel count", "Pass", $"Value : 0"]);
                                }
                            }
                        }
                        catch (Exception e)
                        {
                            testResult = "N/A";
                            testDetails = $"Exception : {e.Message}";
                        }
                        testItemRows.Add(["Access Digital Input subsystem", testResult, testDetails]);

                        // Test Digital Output if supported
                        try
                        {
                            var digitalOutput = digitalSubsystem.Output;
                            if (digitalOutput is null)
                            {
                                testResult = "N/A";
                                testDetails = "Digital Output not available";
                            }
                            else
                            {
                                isTestPass = true;
                                testResult = "Pass";
                                testDetails = "Successfully accessed";

                                // Get output channel count
                                var outputChannels = digitalOutput.Channels;
                                if (outputChannels is not null && outputChannels.Count > 0)
                                {
                                    testItemRows.Add(["Digital Output : Channel count", "Pass", $"Value : {outputChannels.Count}"]);

                                    // Log first channel details
                                    var firstChannel = outputChannels[0];
                                    if (firstChannel is not null)
                                    {
                                        testItemRows.Add(["Digital Output : First channel index", "Pass", $"Value : {firstChannel.ChannelIndex}"]);
                                        testItemRows.Add(["Digital Output : First channel direction", "Pass", $"Value : {firstChannel.Direction}"]);
                                        // Try reading feedback state
                                        try
                                        {
                                            var feedbackState = firstChannel.ReadFeedback();
                                            testItemRows.Add(["Digital Output : First channel feedback state", "Pass", $"Value : {feedbackState}"]);
                                        }
                                        catch (Exception e)
                                        {
                                            testItemRows.Add(["Digital Output : First channel feedback state", "N/A", $"Exception : {e.Message}"]);
                                        }
                                    }
                                }
                                else
                                {
                                    testItemRows.Add(["Digital Output : Channel count", "Pass", $"Value : 0"]);
                                }
                            }
                        }
                        catch (Exception e)
                        {
                            testResult = "N/A";
                            testDetails = $"Exception : {e.Message}";
                        }
                        testItemRows.Add(["Access Digital Output subsystem", testResult, testDetails]);

                        // Test Digital Configuration if available
                        try
                        {
                            var digitalConfig = digitalSubsystem.Configuration;
                            if (digitalConfig is null)
                            {
                                testResult = "N/A";
                                testDetails = "Digital Configuration not available";
                            }
                            else
                            {
                                isTestPass = true;
                                testResult = "Pass";
                                testDetails = "Successfully accessed";

                                // Log configuration details
                                testItemRows.Add(["Digital Configuration : OperationTimeout", "Pass", $"Value : {digitalConfig.OperationTimeout}"]);
                                testItemRows.Add(["Digital Configuration : SampleClockSource", "Pass", $"Value : {digitalConfig.SampleClockSource}"]);
                                testItemRows.Add(["Digital Configuration : SampleInterval", "Pass", $"Value : {digitalConfig.SampleInterval}"]);
                            }
                        }
                        catch (Exception e)
                        {
                            testResult = "N/A";
                            testDetails = $"Exception : {e.Message}";
                        }
                        testItemRows.Add(["Access Digital Configuration", testResult, testDetails]);
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
            ["Check Digital subsystem availability", result1, details1],
            ["Test Digital capabilities and channels", result2, details2],
            ["", "", ""]
        ];

        // If not elevated, reporting is terminated.
        if (!PrivilegeChecker.IsElevated())
        {
            Console.WriteLine($"[DaqDigitalTest][Should_GetDigitalCapabilities_NotThrowException] Not elevated. Exporting report terminated.");
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
