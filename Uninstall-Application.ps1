<#
.SYNOPSIS
    Uninstalls the applications registered with the set displayname in the Windows installer. 
   
.DESCRIPTION
    Searches registry for applications registered with the set displayname. 
    If any found, the uninstall string is retrieved and used to uninstall the application.

    Works with installation made via .MSI as well as some .EXE compilers with unins000.exe used for uninstallation
    
.NOTES
    Filename: Uninstall-Application.ps1
    Version: 2.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

    Version history:

    1.0   -   Script created
    2.0   -   Realized not all applications are properly registered in Windows installer to use msiexec.exe /x as the UninstallString
              Some applications are registered with msiexec.exe /i, which requires a slight change in the script below

.LINK
    https://www.imab.dk/uninstall-any-application-in-a-jiffy-using-powershell-and-configuration-manager
    
#> 
[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$displayName
)
function Uninstall-ApplicationLocalMachine() {
    Write-Verbose -Verbose -Message "Running Uninstall-ApplicationLocalMachine function"
    Write-Verbose -Verbose -Message "Looking for installed application: $displayName"
    $registryPaths = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    foreach ($path in $registryPaths) {
        Write-Verbose -Verbose -Message "Looping through $path"
        if (Test-Path -Path $path) {
            $installedApps = Get-ChildItem -Path $path -Recurse | Get-ItemProperty | Where-Object {$_.DisplayName -like "*$displayName*" } | Select-Object Displayname,UninstallString,PSChildName
            if ($installedApps) {
                Write-Verbose -Verbose -Message "Installed applications matching '$displayName' found in $path"
                foreach ($App in $installedApps) {
                    if ($App.UninstallString) {
                        if ($App.UninstallString.Contains("MsiExec.exe")) {
                            try {
                                Write-Verbose -Verbose -Message "Uninstalling application: $($App.DisplayName) via $($App.UninstallString)"
                                Start-Process 'cmd.exe' -ArgumentList ("/c" + "MsiExec.exe /x" + $($App.PSChildName) + " /quiet" + " /norestart") -Wait
                                
                            } catch {
                                Write-Error -Message "Failed to uninstall application: $($App.DisplayName)"
                            }
                        }
                        if ($App.UninstallString.Contains("unins000.exe")) {
                            try {
                                Write-Verbose -Verbose -Message "Uninstalling application: $($App.DisplayName) via $($App.UninstallString)"
                                Start-Process 'cmd.exe' -ArgumentList ("/c" + $($App.UninstallString) + " /SILENT" + " /NORESTART") -Wait
                            } catch {
                                Write-Error -Message "Failed to uninstall application: $($App.DisplayName)"
                            }
                        }
                        else {
                            # If script reaches this point, the application is installed with an unsupported installer
                        }
                    }
                }
            }
            else {
                Write-Verbose -Verbose -Message "No installed apps that matches displayname: $displayName found in $path"
            }
        }
        else {
            Write-Verbose -Verbose -Message "Path: $path does not exist"
        }
    }
}
try {
    Write-Verbose -Verbose -Message "Script is running"
    Uninstall-ApplicationLocalMachine
}
catch {
    Write-Verbose -Verbose -Message "Something went wrong during running of the script: $($_.Exception.Message)"
}
finally {
    Write-Verbose -Verbose -Message "Script is done running"
}
