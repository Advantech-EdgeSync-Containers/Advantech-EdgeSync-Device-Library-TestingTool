using System.Text;

using Advantech.Edge.Platform;
using Advantech.Edge.Platform.Gpio;

namespace Advantech.Edge.Test.TestTool;

public class GpioTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir)
    {
        string testName = "Gpio_Should_ReturnEqualPinNumber";
        
        // Initialize log path variables using provided reportDir
        string fileNameReportTestItem = $"{testName}.csv";
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
        catch (Exception e)
        {
            isTestPass = false;
            testResult = "Fail";
            testDetails = $"Exception : {e.Message}";
        }
        testItemRows.Add(["Create main board instance", testResult, testDetails]);

        // Test : equality of number of pins
        uint? pinNumByMaxPinNum = null;
        int? pinNumByPinNames = null;
        if (mainBoard is null)
        {
            isTestPass = false;

            testItemRows.Add(["Check supported", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Read max pin number", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Read length of pin name array", "Fail", "Main board instance not created"]);
            testItemRows.Add(["Check equality of pin number", "Fail", "Main board instance not created"]);
        }
        else if (mainBoard.Gpio is null)
        {
            isTestPass = true;

            testItemRows.Add(["Check supported", "N/A", "Gpio not supported"]);
            testItemRows.Add(["Read max pin number", "N/A", "Gpio not supported"]);
            testItemRows.Add(["Read length of pin name array", "N/A", "Gpio not supported"]);
            testItemRows.Add(["Check equality of pin number", "N/A", "Gpio not supported"]);
        }
        else
        {
            // Get max pin number
            try
            {
                pinNumByMaxPinNum = mainBoard.Gpio.MaxPinNum;
                if (!pinNumByMaxPinNum.HasValue)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = "Value : None";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Value : {pinNumByMaxPinNum}";
                }
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read max pin number", testResult, testDetails]);

            // Get length of pin name array
            try
            {
                pinNumByPinNames = mainBoard.Gpio.PinNames.Length;
                if (!pinNumByPinNames.HasValue)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = "Value : None";
                }
                else
                {
                    testResult = "Pass";
                    testDetails = $"Value : {pinNumByPinNames}";
                }
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read length of pin name array", testResult, testDetails]);

            // Check equality
            isTestPass = pinNumByMaxPinNum == pinNumByPinNames;
            testResult = isTestPass ? "Pass" : "Fail";
            testDetails = isTestPass ? "Success : Equal" : "Not equal";
            testItemRows.Add(["Check equality of pin number", testResult, testDetails]);
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
