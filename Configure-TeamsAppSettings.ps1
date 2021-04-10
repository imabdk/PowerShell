<#
.SYNOPSIS
    Manage various application settings in Microsoft Teams for Windows.

    This script is used as remediation script with Proactive Remediations in Microsoft Endpoint Manager

.DESCRIPTION
    Manage various application settings in Microsoft Teams for Windows, which currently consists of:

    - Auto-start application
    - Open application in background
    - On close, keep  the application running
    - Disable GPU hardware acceleration
    - Register Teams as the chat app for Office
    - Application language
    - Application theme

.NOTES
    Filename: Configure-TeamsAppSettings.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/configure-microsoft-teams-application-settings-using-proactive-remediations-in-microsoft-endpoint-manager-and-powershell    
        
#> 
#region parameters
param(
[ValidateSet($true,$false)]
[bool]$openAsHidden = $true,
[ValidateSet($true,$false)]
[bool]$openAtLogin = $true,
[ValidateSet($true,$false)]
[bool]$runningOnClose = $true,
[ValidateSet($true,$false)]
[bool]$disableGpu = $false,
[ValidateSet($true,$false)]
[bool]$registerAsIMProvider = $true,
[string]$appLanguage = "da-dk",
[string]$appTheme = "darkV2", # Possible values are darkV2, defaultV2, contrast
[string]$cookieFile = "$env:APPDATA\Microsoft\Teams\Cookies"
)
#endregion
#region functions
# Function to retrieve Teams config and install location
function Get-TeamsDesktopConfig() {
    $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $configPath = "$env:APPDATA\Microsoft\Teams\desktop-config.json"
    $teamsInstalled = Get-ChildItem -Path $registryPath -Recurse | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Microsoft Teams" } | Select-Object Displayname,InstallLocation,DisplayVersion
    if (-NOT[string]::IsNullOrEmpty($teamsInstalled)) {
        $displayName = $teamsInstalled.DisplayName
        $installLocation = $teamsInstalled.InstallLocation
        $appVersion = $teamsInstalled.DisplayVersion
        Write-Verbose -Verbose -Message "Application: $displayName is installed in $installLocation. Application version is $appVersion"
        if (Test-Path -Path $installLocation) {
            Write-Verbose -Verbose -Message "Teams installation found in $installLocation"
            if (Test-Path -Path $configPath) {
                Write-Verbose -Verbose -Message "Teams config found in $configPath"
                $configPath
                $installLocation
            }
        }
    }
    else {
        Write-Verbose -Verbose -Message "Microsoft Teams application not installed"
        $false
    }
}
# Function to stop the Teams process
function Stop-Teams() {
    if (Get-Process Teams -ErrorAction SilentlyContinue) {
        Write-Verbose -Verbose -Message "Teams is running. Trying to stop the process"
        try {
            Stop-Process -Name Teams -Force
            Start-Sleep 5
            Write-Verbose -Verbose -Message "Teams process successfully stopped"
            $true
        }
        catch {
            Write-Verbose -Verbose -Message "Failed to stop Teams"
            $false
        }
    }
    else {
        Write-Verbose -Verbose -Message "Teams is not running. Doing nothing"
        $true
    }
}
#endregion
#region main process
$getTeamsDesktopConfig = Get-TeamsDesktopConfig
$teamsConfigPath = $getTeamsDesktopConfig[0]
$teamsInstallLocation = $getTeamsDesktopConfig[1]

if (-NOT[string]::IsNullOrEmpty($teamsConfigPath)) {
    $teamsConfigContent = Get-Content -Path $teamsConfigPath
    if (-NOT[string]::IsNullOrEmpty($teamsConfigContent)) {
        $configJson = ConvertFrom-Json -InputObject $teamsConfigContent
        if (-NOT[string]::IsNullOrEmpty($configJson)) {
            $stopTeams = Stop-Teams
            if ($stopTeams -eq $true) {
                # Deleting cookie file enabling us to write changes to config.json
                # This is a somewhat new requirement, and wasn't needed when I created my initial script
                if (Test-Path -Path $cookieFile) {
                    Remove-Item -Path $cookieFile -Force -ErrorAction SilentlyContinue
                }
                try {
                    $configJson.appPreferenceSettings.OpenAsHidden = $openAsHidden
                    $configJson.appPreferenceSettings.OpenAtLogin = $openAtLogin
                    $configJson.appPreferenceSettings.RunningOnClose = $runningOnClose
                    $configJson.appPreferenceSettings.disableGpu = $disableGpu
                    $configJson.appPreferenceSettings.registerAsIMProvider = $registerAsIMProvider
                    $configJson.currentWebLanguage = $appLanguage
                    $configJson.theme = $appTheme
                }
                catch { 
                    Write-Verbose -Verbose -Message "Failed to apply one or more changes to config.json"
                }
                # Additional configuration in registry is needed in order to change the IM provider
                if ($registerAsIMProvider -eq $true) {
                    $imProviders = "HKCU:\SOFTWARE\IM Providers"
                    if (Test-Path -Path $imProviders) {
                        New-ItemProperty -Path $imProviders -Name DefaultIMApp -Value Teams -PropertyType STRING -Force
                    }                        
                }
                elseif ($registerAsIMProvider -eq $false) {
                    $imProviders = "HKCU:\SOFTWARE\IM Providers"
                    $teamsIMProvider = "HKCU:\SOFTWARE\IM Providers\Teams"
                    if (Test-Path -Path $teamsIMProvider) {
                        $previousDefaultIMApp = (Get-ItemProperty -Path $teamsIMProvider -Name PreviousDefaultIMApp -ErrorAction SilentlyContinue).PreviousDefaultIMApp
                        if ($previousDefaultIMApp) {
                            New-ItemProperty -Path $imProviders -Name DefaultIMApp -Value $previousDefaultIMApp -PropertyType STRING -Force
                        }
                        else {
                            Remove-ItemProperty -Path $imProviders -Name DefaultIMApp -ErrorAction SilentlyContinue
                        }
                    }
                }
                try {
                    Write-Verbose -Verbose -Message "Creating and converting new content to Teams config file"
                    $configJson | ConvertTo-Json -Compress| Set-Content -Path $teamsConfigPath -Force
                    Write-Verbose -Verbose -Message "Successfully applied new content to Teams config file at $teamsConfigPath"
                }
                catch { 
                    Write-Output "Failed to create and convert new content to Teams config file. Exiting script with 1"
                    exit 1
                }
                if (-NOT[string]::IsNullOrEmpty($teamsInstallLocation)) {
                    try {
                        Write-Verbose -Verbose -Message "Launching Microsoft Teams post processing config changes"
                        Start-Process -FilePath $teamsInstallLocation\Current\Teams.exe
                        Write-Output "All good. Successfully applied config changes and re-launched Teams. Exiting script with 0"
                        exit 0
                    }
                    catch { 
                        Write-Output "Failed to launch Microsoft Teams post processing config changes. Exiting script with 1"
                        exit 1
                    }
                }
            }
        }
    }
}
#endregion