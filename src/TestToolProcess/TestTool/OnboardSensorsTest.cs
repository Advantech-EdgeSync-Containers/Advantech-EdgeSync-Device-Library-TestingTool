using System.Text;

using Advantech.Edge.Platform;

namespace Advantech.Edge.Test.TestTool;

public class OnboardSensorsTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir)
    {
        string testName = "OnboardSensors_Should_ReadAll_NotThrowException";
        
        // Initialize log path variables using provided reportDir
        string fileNameReportSummary = $"{testName}_summary.csv";
        string fileNameReportTestItem = $"{testName}.csv";
        string filePathReportSummary = Path.Combine(reportDir, fileNameReportSummary);
        string filePathReportTestItem = Path.Combine(reportDir, fileNameReportTestItem);

        // Add test item report headers.
        List<string[]> testItemRows = [];
        testItemRows.Add([$"===== {fileNameReportTestItem} =====", "", ""]);
        testItemRows.Add(["Test Item", "Test Result", "Details"]);

        // Test results init
        bool isTestPass = true;
        string testResult = "Pass";
        string testDetails = "";

        // Create main board
        MainBoard? mainBoard = null;
        try
        {
            mainBoard = new MainBoard();
            testResult = "Pass";
            testDetails = "Success";
        }
        catch (Exception ex)
        {
            isTestPass = false;
            testResult = "Fail";
            testDetails = $"Exception : {ex}";
        }
        testItemRows.Add(["Create main board instance", testResult, testDetails]);

        // Get properties
        string[] temperatureSources = [];
        Dictionary<string, double?> temperatureDict = [];
        string[] voltageSources = [];
        Dictionary<string, double?> voltageDict = [];
        string[] fanSources = [];
        Dictionary<string, double?> fanSpeedDict = [];
        if (mainBoard is null)
        {
            isTestPass = false;

            testItemRows.Add(["Check supported", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Read temperature sources", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Read voltage sources", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Read fan sources", "Fail", "Main board instance not created"]);
        }
        else if (mainBoard.OnboardSensors is null)
        {
            isTestPass = true;

            testItemRows.Add(["Check supported", "N/A", "Onboard sensors not supported"]);
            testItemRows.Add(["Read temperature sources", "N/A", "Onboard sensors not supported"]);
            testItemRows.Add(["Read voltage sources", "N/A", "Onboard sensors not supported"]);
            testItemRows.Add(["Read fan sources", "N/A", "Onboard sensors not supported"]);
        }
        else
        {
            // Get: Temperature sources
            try
            {
                temperatureSources = mainBoard.OnboardSensors.TemperatureSources;
                if (temperatureSources.Length <= 0)
                {
                    testResult = "N/A";
                    testDetails = "Not supported";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Count : {temperatureSources.Length}";
                }
            }
            catch (Exception ex)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {ex}";
            }
            testItemRows.Add(["Read temperature sources", testResult, testDetails]);

            // Enumerate temperature readings
            foreach (string src in temperatureSources)
            {
                try
                {
                    var sample = mainBoard.OnboardSensors.GetTemperature(src);
                    temperatureDict[src] = sample?.Value;
                    if (sample is null)
                    {
                        testResult = "N/A";
                        testDetails = "Not available now";
                    }
                    else
                    {
                        bool isInRange = sample.Value > -40.0 && sample.Value < 100.0;
                        testResult = isInRange ? "Pass" : "Fail";
                        testDetails = isInRange ? $"Value : {sample.Value} degrees Celsius" : $"Value : {sample.Value} degrees Celsius, out of range";
                    }
                }
                catch (Exception ex)
                {
                    temperatureDict[src] = null;
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {ex}";
                }
                testItemRows.Add([$"Read temperature : {src}", testResult, testDetails]);
            }

            // Get: Voltage sources
            try
            {
                voltageSources = mainBoard.OnboardSensors.VoltageSources;
                if (voltageSources.Length <= 0)
                {
                    testResult = "N/A";
                    testDetails = "Not supported";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Count : {voltageSources.Length}";
                }
            }
            catch (Exception ex)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {ex}";
            }
            testItemRows.Add(["Read voltage sources", testResult, testDetails]);

            // Enumerate voltage readings
            foreach (string src in voltageSources)
            {
                try
                {
                    var sample = mainBoard.OnboardSensors.GetVoltage(src);
                    voltageDict[src] = sample?.Value;
                    if (sample is null)
                    {
                        testResult = "N/A";
                        testDetails = "Not available now";
                    }
                    else
                    {
                        bool isInRange = sample.Value > -250.0 && sample.Value < 250.0;
                        testResult = isInRange ? "Pass" : "Fail";
                        testDetails = isInRange ? $"Value : {sample.Value} volts" : $"Value : {sample.Value} volts, out of range";
                    }
                }
                catch (Exception ex)
                {
                    voltageDict[src] = null;
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {ex}";
                }
                testItemRows.Add([$"Read voltage : {src}", testResult, testDetails]);
            }

            // Get: Fan sources
            try
            {
                fanSources = mainBoard.OnboardSensors.FanSources;
                if (fanSources.Length <= 0)
                {
                    testResult = "N/A";
                    testDetails = "Not supported";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Count : {fanSources.Length}";
                }
            }
            catch (Exception ex)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {ex}";
            }
            testItemRows.Add(["Read fan sources", testResult, testDetails]);

            // Enumerate fan speed readings
            foreach (string src in fanSources)
            {
                try
                {
                    var sample = mainBoard.OnboardSensors.GetFanSpeed(src);
                    fanSpeedDict[src] = sample?.Value;
                    if (sample is null)
                    {
                        testResult = "N/A";
                        testDetails = "Not available now";
                    }
                    else
                    {
                        bool isInRange = sample.Value > 0 && sample.Value < 20000;
                        testResult = isInRange ? "Pass" : "Fail";
                        testDetails = isInRange ? $"Value : {sample.Value} RPM" : $"Value : {sample.Value} RPM, out of range";
                    }
                }
                catch (Exception ex)
                {
                    fanSpeedDict[src] = null;
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {ex}";
                }
                testItemRows.Add([$"Read fan speed : {src}", testResult, testDetails]);
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
