using System.Text;

using Advantech.Edge.Platform;
using Advantech.Edge.Platform.BoardInfo;

namespace Advantech.Edge.Test.TestTool;

public class BoardInfoTest
{
    public (string TestName, List<string[]> Rows, bool IsPassed) ExecuteTest(string reportDir)
    {
        string testName = "BoardInfo_Should_ReadAll_NotThrowException";

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
        catch (Exception e)
        {
            isTestPass = false;
            testResult = "Fail";
            testDetails = $"Exception : {e.Message}";
        }
        testItemRows.Add(["Create main board instance", testResult, testDetails]);

        // Get fields of board information.
        string manufacturer = string.Empty;
        string name = string.Empty;
        string? biosVersion = null;
        DmiInfo? dmiInfo = null;
        string? dmiBiosVendor = null;
        string? dmiBiosVersion = null;
        string? dmiBiosReleaseDate = null;
        string? dmiSysUuid = null;
        string? dmiSysVendor = null;
        string? dmiSysProduct = null;
        string? dmiSysVersion = null;
        string? dmiSysSerial = null;
        string? dmiBoardVendor = null;
        string? dmiBoardName = null;
        string? dmiBoardVersion = null;
        string? dmiBoardSerial = null;
        string? dmiBoardAssetTag = null;
        if (mainBoard is null)
        {
            isTestPass = false;

            string[] labels = [
                "Manufacturer",
                "Name",
                "BIOS Version",
                "DMI Information",
                "DMI Information (BIOS vendor)",
                "DMI Information (BIOS version)",
                "DMI Information (BIOS release date)",
                "DMI Information (BIOS system UUID)",
                "DMI Information (System vendor)",
                "DMI Information (System product)",
                "DMI Information (System version)",
                "DMI Information (System serial)",
                "DMI Information (Board vendor)",
                "DMI Information (Board name)",
                "DMI Information (Board version)",
                "DMI Information (Board serial)",
                "DMI Information (Board asset tag)"
            ];
            foreach (var label in labels)
            {
                testItemRows.Add([$"Read {label}", "Fail", "Main board instance not created"]);
            }
        }
        else if (mainBoard.BoardInfo is null)
        {
            isTestPass = false;

            string[] labels = [
                "Manufacturer",
                "Name",
                "BIOS Version",
                "DMI Information",
                "DMI Information (BIOS vendor)",
                "DMI Information (BIOS version)",
                "DMI Information (BIOS release date)",
                "DMI Information (BIOS system UUID)",
                "DMI Information (System vendor)",
                "DMI Information (System product)",
                "DMI Information (System version)",
                "DMI Information (System serial)",
                "DMI Information (Board vendor)",
                "DMI Information (Board name)",
                "DMI Information (Board version)",
                "DMI Information (Board serial)",
                "DMI Information (Board asset tag)"
            ];
            foreach (var label in labels)
            {
                testItemRows.Add([$"Read {label}", "Fail", "Main board instance not created"]);
            }
        }
        else
        {
            System.Diagnostics.Stopwatch sw = new System.Diagnostics.Stopwatch();
            sw.Start();

            // Manufacturer
            try
            {
                manufacturer = mainBoard.BoardInfo.Manufacturer;
                testResult = !string.IsNullOrEmpty(manufacturer) ? "Pass" : "N/A";
                testDetails = !string.IsNullOrEmpty(manufacturer) ? $"Value : {manufacturer}" : "Not exists";
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read manufacturer", testResult, testDetails]);

            // Name
            try
            {
                name = mainBoard.BoardInfo.Name;
                testResult = !string.IsNullOrEmpty(name) ? "Pass" : "N/A";
                testDetails = !string.IsNullOrEmpty(name) ? $"Value : {name}" : "Not exists";
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read name", testResult, testDetails]);

            // BIOS version
            try
            {
                biosVersion = mainBoard.BoardInfo.BiosVersion;
                testResult = !string.IsNullOrEmpty(biosVersion) ? "Pass" : "N/A";
                testDetails = !string.IsNullOrEmpty(biosVersion) ? $"Value : {biosVersion}" : "Not exists";
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read BIOS version", testResult, testDetails]);

            testItemRows.Add(["", "", ""]);

            // DMI Information
            try
            {
                dmiInfo = mainBoard.BoardInfo.DmiInfo;
                testResult = dmiInfo is not null ? "Pass" : "N/A";
                testDetails = dmiInfo is not null ? "Read success" : "Not exists";
            }
            catch (Exception e)
            {
                isTestPass = false;
                testResult = "Fail";
                testDetails = $"Exception : {e.Message}";
            }
            testItemRows.Add(["Read DMI Information", testResult, testDetails]);

            if (dmiInfo != null)
            {
                // DMI BIOS vendor
                try
                {
                    dmiBiosVendor = dmiInfo.BiosVendor;
                    testResult = !string.IsNullOrEmpty(dmiBiosVendor) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBiosVendor) ? $"Value : {dmiBiosVendor}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (BIOS vendor)", testResult, testDetails]);

                // DMI BIOS version
                try
                {
                    dmiBiosVersion = dmiInfo.BiosVersion;
                    testResult = !string.IsNullOrEmpty(dmiBiosVersion) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBiosVersion) ? $"Value : {dmiBiosVersion}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (BIOS version)", testResult, testDetails]);

                // DMI BIOS release date
                try
                {
                    dmiBiosReleaseDate = dmiInfo.BiosReleaseDate;
                    testResult = !string.IsNullOrEmpty(dmiBiosReleaseDate) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBiosReleaseDate) ? $"Value : {dmiBiosReleaseDate}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (BIOS release date)", testResult, testDetails]);

                // DMI system information
                try
                {
                    dmiSysUuid = dmiInfo.SysUuid;
                    testResult = !string.IsNullOrEmpty(dmiSysUuid) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiSysUuid) ? $"Value : {dmiSysUuid}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (BIOS system UUID)", testResult, testDetails]);

                // DMI system vendor
                try
                {
                    dmiSysVendor = dmiInfo.SysVendor;
                    testResult = !string.IsNullOrEmpty(dmiSysVendor) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiSysVendor) ? $"Value : {dmiSysVendor}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (System vendor)", testResult, testDetails]);

                // DMI system product
                try
                {
                    dmiSysProduct = dmiInfo.SysProduct;
                    testResult = !string.IsNullOrEmpty(dmiSysProduct) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiSysProduct) ? $"Value : {dmiSysProduct}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (System product)", testResult, testDetails]);

                // DMI system version
                try
                {
                    dmiSysVersion = dmiInfo.SysVersion;
                    testResult = !string.IsNullOrEmpty(dmiSysVersion) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiSysVersion) ? $"Value : {dmiSysVersion}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (System version)", testResult, testDetails]);

                // DMI system serial
                try
                {
                    dmiSysSerial = dmiInfo.SysSerial;
                    testResult = !string.IsNullOrEmpty(dmiSysSerial) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiSysSerial) ? $"Value : {dmiSysSerial}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (System serial)", testResult, testDetails]);

                // DMI board vendor
                try
                {
                    dmiBoardVendor = dmiInfo.BoardVendor;
                    testResult = !string.IsNullOrEmpty(dmiBoardVendor) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBoardVendor) ? $"Value : {dmiBoardVendor}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (Board vendor)", testResult, testDetails]);

                // DMI board name
                try
                {
                    dmiBoardName = dmiInfo.BoardName;
                    testResult = !string.IsNullOrEmpty(dmiBoardName) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBoardName) ? $"Value : {dmiBoardName}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (Board name)", testResult, testDetails]);

                // DMI board version
                try
                {
                    dmiBoardVersion = dmiInfo.BoardVersion;
                    testResult = !string.IsNullOrEmpty(dmiBoardVersion) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBoardVersion) ? $"Value : {dmiBoardVersion}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (Board version)", testResult, testDetails]);

                // DMI board serial
                try
                {
                    dmiBoardSerial = dmiInfo.BoardSerial;
                    testResult = !string.IsNullOrEmpty(dmiBoardSerial) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBoardSerial) ? $"Value : {dmiBoardSerial}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (Board serial)", testResult, testDetails]);

                // DMI board asset tag
                try
                {
                    dmiBoardAssetTag = dmiInfo.BoardAssetTag;
                    testResult = !string.IsNullOrEmpty(dmiBoardAssetTag) ? "Pass" : "N/A";
                    testDetails = !string.IsNullOrEmpty(dmiBoardAssetTag) ? $"Value : {dmiBoardAssetTag}" : "Not exists";
                }
                catch (Exception e)
                {
                    isTestPass = false;
                    testResult = "Fail";
                    testDetails = $"Exception : {e.Message}";
                }
                testItemRows.Add(["Read DMI Information (Board asset tag)", testResult, testDetails]);
            }
            else
            {
                // If DMI does not exist, write 13 N/A items
                string[] labels = [
                    "BIOS vendor",
                    "BIOS version",
                    "BIOS release date",
                    "BIOS system UUID",
                    "System vendor",
                    "System product",
                    "System version",
                    "System serial",
                    "Board vendor",
                    "Board name",
                    "Board version",
                    "Board serial",
                    "Board asset tag"
                ];

                foreach (var label in labels)
                {
                    testItemRows.Add([$"Read DMI Information ({label})", "N/A", "DMI not exists"]);
                }
            }
        
            sw.Stop();
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
