using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace Advantech.Edge.Test;

internal static class PrivilegeChecker
{
    /// <summary>
    /// Returns true if the current process has elevated privileges 
    /// (Administrator on Windows, root on Linux/macOS).
    /// </summary>
    public static bool IsElevated()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return IsAdministratorWindows();
        }
        else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux) ||
                    RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            return IsRootUnix();
        }
        else
        {
            throw new PlatformNotSupportedException("Unsupported OS");
        }
    }

    #region Windows
    private static bool IsAdministratorWindows()
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            throw new PlatformNotSupportedException("IsAdministratorWindows can only be called on Windows.");
        }

        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }
    #endregion

    #region Unix
    private static bool IsRootUnix()
    {
        // First, try to use libc's geteuid() if available
        if (IsLibcAvailable())
        {
            // Return true if effective user ID is 0 (root)
            return UnixNativeMethods.geteuid() == 0;
        }
        else
        {
            // libc not available, log a warning
            Trace.TraceWarning("libc not found. Falling back to 'id -u' command to check root privileges.");
        }

        // Fallback: use `id -u` command to check the effective user ID
        try
        {
            using var process = new Process();
            process.StartInfo.FileName = "/usr/bin/id";    // Command to get user ID
            process.StartInfo.Arguments = "-u";            // Print only the UID
            process.StartInfo.RedirectStandardOutput = true;
            process.StartInfo.UseShellExecute = false;
            process.StartInfo.CreateNoWindow = true;

            if (!process.Start())
            {
                Trace.TraceWarning("Failed to start 'id -u' process");
                return false;
            }

            string? output = null;
            try
            {
                output = process.StandardOutput.ReadLine();
                // Wait for process to exit, with timeout to prevent hanging
                if (!process.WaitForExit(5000))
                {
                    // Process timed out, kill it
                    try
                    {
                        process.Kill();
                        process.WaitForExit(1000);
                    }
                    catch (Exception ex)
                    {
                        Trace.TraceWarning($"Failed to kill timed-out 'id -u' process: {ex.Message}");
                    }
                    Trace.TraceWarning("'id -u' process timed out after 5 seconds");
                    return false;
                }
            }
            finally
            {
                // Ensure StandardOutput stream is properly disposed
                try
                {
                    process.StandardOutput?.Dispose();
                }
                catch { }
            }

            if (output != null && uint.TryParse(output.Trim(), out uint uid))
            {
                // Return true if UID is 0 (root)
                return uid == 0;
            }
            else
            {
                // Unable to parse UID, log a warning
                Trace.TraceWarning($"Failed to parse UID from 'id -u' output: '{output}'");
            }
        }
        catch (Exception ex)
        {
            // Failed to run 'id -u', log exception as warning
            Trace.TraceWarning($"Exception occurred while checking root privileges via 'id -u': {ex.Message}");
        }

        // If all methods fail, assume not running as root
        return false;
    }

    private static bool IsLibcAvailable()
    {
        return NativeLibrary.TryLoad("libc", out nint handle);
    }

    private static class UnixNativeMethods
    {
        [DllImport("libc")]
        internal static extern uint geteuid();
    }
    #endregion
}