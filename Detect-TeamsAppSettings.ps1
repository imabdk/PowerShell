<#
.SYNOPSIS
    Manage various application settings in Microsoft Teams for Windows.

    This script is used as detection script with Proactive Remediations in Microsoft Endpoint Manager

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
    Filename: Detect-TeamsAppSettings.ps1
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
[string]$appTheme = "darkV2" # Possible values are darkV2, defaultV2, contrast
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
            }
        }
    }
    else {
        Write-Verbose -Verbose -Message "Microsoft Teams application not installed"
        $false
    }
}
#endregion
#region main process
$teamsConfigPath = Get-TeamsDesktopConfig
if (-NOT[string]::IsNullOrEmpty($teamsConfigPath)) {

    $teamsConfigContent = Get-Content -Path $teamsConfigPath
    $configJson = ConvertFrom-Json -InputObject $teamsConfigContent
    $configCheck = $configJson | Where-Object {($_.theme -ne $appTheme) -OR ($_.currentWebLanguage -ne $appLanguage) -OR ($_.appPreferenceSettings.OpenAsHidden -ne $openAsHidden) -OR ($_.appPreferenceSettings.OpenAtLogin -ne $openAtLogin) -OR ($_.appPreferenceSettings.RunningOnClose -ne $runningOnClose) -OR ($_.appPreferenceSettings.disableGpu -ne $disableGpu) -OR ($_.appPreferenceSettings.registerAsIMProvider -ne $registerAsIMProvider)} -ErrorAction SilentlyContinue

    if (-NOT[string]::IsNullOrEmpty($configCheck)) {
        Write-Output "Teams application settings are NOT configured as desired. Exiting script with 1"
        exit 1
    }
    else {
        Write-Output "Teams application settings are already configured as desired. Exiting script with 0"
        exit 0
    }
}
else {
    Write-Output "No Teams configuration found. Doing nothing. Exiting script with 0"
    exit 0
}
#endregion