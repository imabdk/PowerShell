<#
.SYNOPSIS
    Uninstalls all Zoom applications registered with the Windows installer. 
    Whether they are installed to the local computer or the users profile.
   
.DESCRIPTION
    Searches registry for applications registered with 'Zoom' as publisher. 
    If any found, the uninstall string is retrieved and used to uninstall the application.
    If applications are found to be installed in the users profile, the users context is invoked and the application is uninstalled coming from SYSTEM context.

.NOTES
    Filename: Uninstall-EverythingZoom.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#> 

function Execute-AsLoggedOnUser($Command,$Hidden=$true) {
    <#
    .SYNOPSIS
    Function that can execute powershell in the context of the logged-in user.
    .DESCRIPTION
    This function will use advanced API's to get the access token of the currently logged-in user, in order to execute a script in the users context.
    This is useful for scripts that are run in the local system users context.
    .REQUIREMENTS
    This script myst be run from the context of the SYSTEM account.
    Designes to be run by Intune or SCCM Agent.
    Absolute paths required.
    .EXAMPLE
    Running a powershell script visible to the user
        $userCommand = '-file c:\windows\temp\script.ps1'
        executeAsLoggedOnUser -Command $userCommand -Hidden $false
    .EXAMPLE
    Running a powershell command hidden from the user (hidden is default true)
        $userCommand = '-command &{remove-item c:\temp\secretfile.txt}'
        executeAsLoggedOnUser -Command $userCommand
    .COPYRIGHT
    MIT License, feel free to distribute and use as you like, please leave author information.
    .AUTHOR
    Michael Mardahl - @michael_mardahl on twitter - BLOG: https://www.iphase.dk
    C# borrowed from the awesome Justin Myrray (https://github.com/murrayju/CreateProcessAsUser)
    .DISCLAIMER
    This function is provided AS-IS, with no warranty - Use at own risk!
    #>

$csharpCode = @"
    using System;  
    using System.Runtime.InteropServices;

    namespace murrayju.ProcessExtensions  
    {
        public static class ProcessExtensions
        {
            #region Win32 Constants

            private const int CREATE_UNICODE_ENVIRONMENT = 0x00000400;
            private const int CREATE_NO_WINDOW = 0x08000000;

            private const int CREATE_NEW_CONSOLE = 0x00000010;

            private const uint INVALID_SESSION_ID = 0xFFFFFFFF;
            private static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;

            #endregion

            #region DllImports

            [DllImport("advapi32.dll", EntryPoint = "CreateProcessAsUser", SetLastError = true, CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
            private static extern bool CreateProcessAsUser(
                IntPtr hToken,
                String lpApplicationName,
                String lpCommandLine,
                IntPtr lpProcessAttributes,
                IntPtr lpThreadAttributes,
                bool bInheritHandle,
                uint dwCreationFlags,
                IntPtr lpEnvironment,
                String lpCurrentDirectory,
                ref STARTUPINFO lpStartupInfo,
                out PROCESS_INFORMATION lpProcessInformation);

            [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
            private static extern bool DuplicateTokenEx(
                IntPtr ExistingTokenHandle,
                uint dwDesiredAccess,
                IntPtr lpThreadAttributes,
                int TokenType,
                int ImpersonationLevel,
                ref IntPtr DuplicateTokenHandle);

            [DllImport("userenv.dll", SetLastError = true)]
            private static extern bool CreateEnvironmentBlock(ref IntPtr lpEnvironment, IntPtr hToken, bool bInherit);

            [DllImport("userenv.dll", SetLastError = true)]
            [return: MarshalAs(UnmanagedType.Bool)]
            private static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);

            [DllImport("kernel32.dll", SetLastError = true)]
            private static extern bool CloseHandle(IntPtr hSnapshot);

            [DllImport("kernel32.dll")]
            private static extern uint WTSGetActiveConsoleSessionId();

            [DllImport("Wtsapi32.dll")]
            private static extern uint WTSQueryUserToken(uint SessionId, ref IntPtr phToken);

            [DllImport("wtsapi32.dll", SetLastError = true)]
            private static extern int WTSEnumerateSessions(
                IntPtr hServer,
                int Reserved,
                int Version,
                ref IntPtr ppSessionInfo,
                ref int pCount);

            #endregion

            #region Win32 Structs

            private enum SW
            {
                SW_HIDE = 0,
                SW_SHOWNORMAL = 1,
                SW_NORMAL = 1,
                SW_SHOWMINIMIZED = 2,
                SW_SHOWMAXIMIZED = 3,
                SW_MAXIMIZE = 3,
                SW_SHOWNOACTIVATE = 4,
                SW_SHOW = 5,
                SW_MINIMIZE = 6,
                SW_SHOWMINNOACTIVE = 7,
                SW_SHOWNA = 8,
                SW_RESTORE = 9,
                SW_SHOWDEFAULT = 10,
                SW_MAX = 10
            }

            private enum WTS_CONNECTSTATE_CLASS
            {
                WTSActive,
                WTSConnected,
                WTSConnectQuery,
                WTSShadow,
                WTSDisconnected,
                WTSIdle,
                WTSListen,
                WTSReset,
                WTSDown,
                WTSInit
            }

            [StructLayout(LayoutKind.Sequential)]
            private struct PROCESS_INFORMATION
            {
                public IntPtr hProcess;
                public IntPtr hThread;
                public uint dwProcessId;
                public uint dwThreadId;
            }

            private enum SECURITY_IMPERSONATION_LEVEL
            {
                SecurityAnonymous = 0,
                SecurityIdentification = 1,
                SecurityImpersonation = 2,
                SecurityDelegation = 3,
            }

            [StructLayout(LayoutKind.Sequential)]
            private struct STARTUPINFO
            {
                public int cb;
                public String lpReserved;
                public String lpDesktop;
                public String lpTitle;
                public uint dwX;
                public uint dwY;
                public uint dwXSize;
                public uint dwYSize;
                public uint dwXCountChars;
                public uint dwYCountChars;
                public uint dwFillAttribute;
                public uint dwFlags;
                public short wShowWindow;
                public short cbReserved2;
                public IntPtr lpReserved2;
                public IntPtr hStdInput;
                public IntPtr hStdOutput;
                public IntPtr hStdError;
            }

            private enum TOKEN_TYPE
            {
                TokenPrimary = 1,
                TokenImpersonation = 2
            }

            [StructLayout(LayoutKind.Sequential)]
            private struct WTS_SESSION_INFO
            {
                public readonly UInt32 SessionID;

                [MarshalAs(UnmanagedType.LPStr)]
                public readonly String pWinStationName;

                public readonly WTS_CONNECTSTATE_CLASS State;
            }

            #endregion

            // Gets the user token from the currently active session
            private static bool GetSessionUserToken(ref IntPtr phUserToken)
            {
                var bResult = false;
                var hImpersonationToken = IntPtr.Zero;
                var activeSessionId = INVALID_SESSION_ID;
                var pSessionInfo = IntPtr.Zero;
                var sessionCount = 0;

                // Get a handle to the user access token for the current active session.
                if (WTSEnumerateSessions(WTS_CURRENT_SERVER_HANDLE, 0, 1, ref pSessionInfo, ref sessionCount) != 0)
                {
                    var arrayElementSize = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
                    var current = pSessionInfo;

                    for (var i = 0; i < sessionCount; i++)
                    {
                        var si = (WTS_SESSION_INFO)Marshal.PtrToStructure((IntPtr)current, typeof(WTS_SESSION_INFO));
                        current += arrayElementSize;

                        if (si.State == WTS_CONNECTSTATE_CLASS.WTSActive)
                        {
                            activeSessionId = si.SessionID;
                        }
                    }
                }

                // If enumerating did not work, fall back to the old method
                if (activeSessionId == INVALID_SESSION_ID)
                {
                    activeSessionId = WTSGetActiveConsoleSessionId();
                }

                if (WTSQueryUserToken(activeSessionId, ref hImpersonationToken) != 0)
                {
                    // Convert the impersonation token to a primary token
                    bResult = DuplicateTokenEx(hImpersonationToken, 0, IntPtr.Zero,
                        (int)SECURITY_IMPERSONATION_LEVEL.SecurityImpersonation, (int)TOKEN_TYPE.TokenPrimary,
                        ref phUserToken);

                    CloseHandle(hImpersonationToken);
                }

                return bResult;
            }

            public static bool StartProcessAsCurrentUser(string cmdLine, bool visible, string appPath = null, string workDir = null)
            {
                var hUserToken = IntPtr.Zero;
                var startInfo = new STARTUPINFO();
                var procInfo = new PROCESS_INFORMATION();
                var pEnv = IntPtr.Zero;
                int iResultOfCreateProcessAsUser;

                startInfo.cb = Marshal.SizeOf(typeof(STARTUPINFO));

                try
                {
                    if (!GetSessionUserToken(ref hUserToken))
                    {
                        throw new Exception("StartProcessAsCurrentUser: GetSessionUserToken failed.");
                    }

                    uint dwCreationFlags = CREATE_UNICODE_ENVIRONMENT | (uint)(visible ? CREATE_NEW_CONSOLE : CREATE_NO_WINDOW);
                    startInfo.wShowWindow = (short)(visible ? SW.SW_SHOW : SW.SW_HIDE);
                    startInfo.lpDesktop = "winsta0\\default";

                    if (!CreateEnvironmentBlock(ref pEnv, hUserToken, false))
                    {
                        throw new Exception("StartProcessAsCurrentUser: CreateEnvironmentBlock failed.");
                    }

                    if (!CreateProcessAsUser(hUserToken,
                        appPath, // Application Name
                        cmdLine, // Command Line
                        IntPtr.Zero,
                        IntPtr.Zero,
                        false,
                        dwCreationFlags,
                        pEnv,
                        workDir, // Working directory
                        ref startInfo,
                        out procInfo))
                    {
                        throw new Exception("StartProcessAsCurrentUser: CreateProcessAsUser failed.\n");
                    }

                    iResultOfCreateProcessAsUser = Marshal.GetLastWin32Error();
                }
                finally
                {
                    CloseHandle(hUserToken);
                    if (pEnv != IntPtr.Zero)
                    {
                        DestroyEnvironmentBlock(pEnv);
                    }
                    CloseHandle(procInfo.hThread);
                    CloseHandle(procInfo.hProcess);
                }
                return true;
            }
        }
    }
"@
    # Compiling the source code as csharp
    $compilerParams = [System.CodeDom.Compiler.CompilerParameters]::new()
    $compilerParams.ReferencedAssemblies.AddRange(('System.Runtime.InteropServices.dll', 'System.dll'))
    $compilerParams.CompilerOptions = '/unsafe'
    $compilerParams.GenerateInMemory = $True
    Add-Type -TypeDefinition $csharpCode -Language CSharp -CompilerParameters $compilerParams
    # Adding powershell executeable to the command
    $Command = '{0}\System32\WindowsPowerShell\v1.0\powershell.exe -executionPolicy bypass {1}' -f $($env:windir),$Command
    # Adding double slashes to the command paths, as this is required.
    $Command = $Command.Replace("\","\\")
    # Execute a process as the currently logged on user. 
    # Absolute paths required if running as SYSTEM!
    if($Hidden) { #running the command hidden
        $runCommand = [murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser($Command,$false)
    }else{ #running the command visible
        $runCommand = [murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser($Command,$true)
    }

    if ($runCommand) {
        return "Executed `"$Command`" as loggedon user"
    } else {
        throw "Something went wrong when executing process as currently logged-on user"
    }
}

function Uninstall-ZoomLocalMachine() {

    Write-Verbose -Verbose -Message "Running Uninstall-ZoomLocalMachine function"
    $registryPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    if (Test-Path -Path $registryPath) {
        $installedZoomApps = Get-ChildItem -Path $registryPath -Recurse | Get-ItemProperty | Where-Object {$_.Publisher -like "Zoom*" } | Select-Object Displayname,UninstallString
        if ($installedZoomApps) {
            Write-Verbose -Verbose -Message "Installed Zoom applications found in HKLM"
            foreach ($zoomApp in $installedZoomApps) {
                if ($zoomApp.UninstallString) {
                    # Regular expression for format of MSI product code
                    $msiRegEx = "\w{8}-\w{4}-\w{4}-\w{4}-\w{12}"
                    # Formatting the productcode in a creative way. 
                    # Needed this separately, as the uninstall string retrieved from registry sometimes wasn't formatted properly
                    $a = $zoomApp.Uninstallstring.Split("{")[1] 
                    $b = $a.Split("}")[0]
                    # Only continuing if the uninstall string matches a regular MSI product code
                    if ($b -match $msiRegEx) {
                        $productCode = "{" + $b + "}"
                        if ($productCode) {
                            try {
                                Write-Verbose -Verbose -Message "Uninstalling application: $($zoomApp.DisplayName)"
                                Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList ("/x" + $productCode + " /passive") -Wait
                            }

                            catch {
                                Write-Error -Message "Failed to uninstall application: $($zoomApp.DisplayName)"
                            }
                        }
                    }
                }
            }
        }
        else {
            Write-Verbose -Verbose -Message "No Zoom applications found in HKLM"
        }
    }
    else {
        Write-Verbose -Verbose -Message "Registry path not found"
    }
}

function Uninstall-ZoomCurrentUser() {

    Write-Verbose -Verbose -Message "Running Uninstall-ZoomCurrentUser function"
    # Getting all user profiles on the computer
    $userProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object {$_.PSChildName -match "S-1-5-21-(\d+-?){4}$"} | Select-Object @{Name="SID"; Expression={$_.PSChildName}}, @{Name="UserHive";Expression={"$($_.ProfileImagePath)\NTuser.dat"}}
    foreach ($userProfile in $userProfiles) {
        # Formatting the username in a separate variable
        $userName = $userProfile.UserHive.Split("\")[2]
        $registryPath = "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        if (Test-Path -Path $registryPath) {
            $installedZoomApps = Get-ChildItem -Path $registryPath -Recurse | Get-ItemProperty | Where-Object {$_.Publisher -like "Zoom*" } | Select-Object Displayname,UninstallString
            if ($installedZoomApps) {
                Write-Verbose -Verbose -Message "Installed Zoom applications found in HKCU for user: $userName"
                foreach ($zoomApp in $installedZoomApps) {
                    if ($zoomApp.UninstallString) {
                        $userCommand = '-command &{Start-Process "C:\Users\USERNAME\AppData\Roaming\Zoom\uninstall\Installer.exe" -ArgumentList "/uninstall" -Wait}'
                        # Replacing the placeholder: USERNAME with the actual username retrieved from the userprofile
                        # This can probably be done smarter, but I failed to find another method
                        $userCommand = $userCommand -replace "USERNAME",$userName
                        try {
                            Write-Verbose -Verbose -Message "Uninstalling application: $($zoomApp.DisplayName) as the logged on user: $userName"
                            Execute-AsLoggedOnUser -Command $userCommand
                        }
                        catch {
                            Write-Error -Message "Failed to uninstall application: $($zoomApp.DisplayName) for user: $userName"
                        }
                    }
                }
            }
            else {
                Write-Verbose -Verbose -Message "No Zoom applications found in HKCU for user: $userName"
            }
        }
        else {
            Write-Verbose -Verbose -Message "Registry path not found for user: $userName"
        }
    }
}

try {
    Write-Verbose -Verbose -Message "Script is running"
    Uninstall-ZoomLocalMachine
    Uninstall-ZoomCurrentUser
}

catch {
    Write-Verbose -Verbose -Message "Something went wrong during running of the script"
}

finally {
    Write-Verbose -Verbose -Message "Script is done running"
}
