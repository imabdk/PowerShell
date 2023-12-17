<#
.SYNOPSIS
    Uninstalls the applications registered with the set displayname in the Windows installer. 
   
.DESCRIPTION
    Searches registry for applications registered with the set displayname. 
    If any found, the uninstall string is retrieved and used to uninstall the application.

    Works with installation made via .MSI as well as some .EXE compilers with unins000.exe used for uninstallation
    
.NOTES
    Filename: Uninstall-Application.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
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
            $installedApps = Get-ChildItem -Path $path -Recurse | Get-ItemProperty | Where-Object {$_.DisplayName -like "*$displayName*" } | Select-Object Displayname,UninstallString
            if ($installedApps) {
                Write-Verbose -Verbose -Message "Installed application: $displayName found in HKLM"
                foreach ($App in $installedApps) {
                    if ($App.UninstallString) {
                        if ($App.UninstallString.Contains("MsiExec.exe")) {
                            try {
                                Write-Verbose -Verbose -Message "Uninstalling application: $($App.DisplayName)"
                                #Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList ("/x" + $productCode + " /passive") -Wait
                                Start-Process 'cmd.exe' -ArgumentList ("/c" + $($App.UninstallString) + " /quiet" + " /noreboot")
                            } catch {
                                Write-Error -Message "Failed to uninstall application: $($App.DisplayName)"
                            }
                        }
                        if ($App.UninstallString.Contains("unins000.exe")) {
                            try {
                                Write-Verbose -Verbose -Message "Uninstalling application: $($App.DisplayName)"
                                #Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList ("/x" + $productCode + " /passive") -Wait
                                Start-Process 'cmd.exe' -ArgumentList ("/c" + $($App.UninstallString) + " /SILENT" + " /NORESTART")
                            } catch {
                                Write-Error -Message "Failed to uninstall application: $($App.DisplayName)"
                            }
                        }
                    }
                }
            }
            else {
                Write-Verbose -Verbose -Message "No installed apps that matches displayname: $displayName"
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
