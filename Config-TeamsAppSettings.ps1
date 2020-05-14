<#
.SYNOPSIS
    Manage the 5 different application settings in Microsoft Teams for Windows

.DESCRIPTION
    Manage the 5 different application settings in Microsoft Teams for Windows, which currently consists of:

    - Auto-start application
    - Open application in background
    - On close, keep  the application running
    - Disable GPU hardware acceleration
    - Register Teams as the chat app for Office
   
.EXAMPLE
    
     .\Config-TeamsAppSettings.ps1 -openAsHidden $true -openAtLogin $true -runningOnClose $true -disableGpu $false -registerAsIMProvider $false

.NOTES
    Filename: Config-TeamsAppSettings.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/configure-microsoft-teams-application-settings-using-configuration-manager-and-powershell
    
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet($true,$false)]
    [bool]$openAsHidden,

    [Parameter(Mandatory=$true)]
    [ValidateSet($true,$false)]
    [bool]$openAtLogin,

    [Parameter(Mandatory=$true)]
    [ValidateSet($true,$false)]
    [bool]$runningOnClose,

    [Parameter(Mandatory=$true)]
    [ValidateSet($true,$false)]
    [bool]$disableGpu,

    [Parameter(Mandatory=$true)]
    [ValidateSet($true,$false)]
    [bool]$registerAsIMProvider
)

function Get-TeamsDesktopConfig() {
    $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $configPath = "$env:APPDATA\Microsoft\Teams\desktop-config.json"
    $teamsInstalled = Get-ChildItem -Path $registryPath -Recurse | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Microsoft Teams" } | Select-Object Displayname,InstallLocation,DisplayVersion
    if ($teamsInstalled) {
        $displayName = $teamsInstalled.DisplayName
        $installLocation = $teamsInstalled.InstallLocation
        $appVersion = $teamsInstalled.DisplayVersion
        Write-Verbose -Verbose -Message "Application: $displayName is installed in $installLocation. Application version is $appVersion"
        if (Test-Path -Path $installLocation) {
            Write-Verbose -Verbose -Message "Teams installation found in $installLocation"
            if (Test-Path -Path $configPath) {
                Write-Verbose -Verbose -Message "Teams config found in $configPath"
                $true
                $configPath
                $installLocation
            }
            else {
                Write-Verbose -Verbose -Message "Teams config file not found"
                $false
            }
        }

        else {
            Write-Verbose -Verbose -Message "Teams install location not found"
            $false
        }
    }
    else {
        Write-Verbose -Verbose -Message "Microsoft Teams application not installed"
        $false
    }
}

function Stop-Teams() {
    if (Get-Process Teams) {
        Write-Verbose -Verbose -Message "Teams is running. Trying to stop the process"
        try {
            Stop-Process -Name Teams -Force
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

$getTeamsDesktopConfig = Get-TeamsDesktopConfig
$getTeamsDesktopConfigStatus = $getTeamsDesktopConfig[0]
$teamsConfigPath = $getTeamsDesktopConfig[1]
$teamsInstallLocation = $getTeamsDesktopConfig[2]

if ($getTeamsDesktopConfigStatus -eq $True) {
    try {
        Write-Verbose -Verbose -Message "Getting content of Teams config file at $teamsConfigPath"
        $teamsConfigContent = Get-Content -Path $teamsConfigPath
    }
    catch { 
        Write-Verbose -Verbose -Message "Failed to get content of Teams config file at $teamsConfigPath. Breaking script"
        break
    }

    if ($teamsConfigContent) {

        try {
            Write-Verbose -Verbose -Message "Converting Teams config content from JSON format"
            $json = ConvertFrom-Json -InputObject $teamsConfigContent
        }
        catch { 
            Write-Verbose -Verbose -Message "Failed to convert config content from JSON format. Breaking script"
            Write-Verbose -Verbose -Message "Make sure Microsoft Teams is launched between doing changes to the config file to properly format the content"
            break           
        }
        if ($json) {
            $stopTeams = Stop-Teams
            if ($stopTeams -eq $true) {
                try {
                    Write-Verbose -Verbose -Message "Modifying Teams setting: OpenAsHidden. Setting value to $openAsHidden"
                    $json.appPreferenceSettings.OpenAsHidden = $openAsHidden
                                                            
                    Write-Verbose -Verbose -Message "Modifying Teams setting: OpenAtLogin. Setting value to $openAtLogin"
                    $json.appPreferenceSettings.OpenAtLogin = $openAtLogin
                                        
                    Write-Verbose -Verbose -Message "Modifying Teams setting: RunningOnClose. Setting value to $runningOnClose"
                    $json.appPreferenceSettings.RunningOnClose = $runningOnClose
                    
                    Write-Verbose -Verbose -Message "Modifying Teams setting: disableGpu. Setting value to $disableGpu"
                    $json.appPreferenceSettings.disableGpu = $disableGpu
                }
                catch { 
                    Write-Verbose -Verbose -Message "Failed to modify Teams settings"
                }

                try {
                    Write-Verbose -Verbose -Message "Modifying Teams setting: registerAsIMProvider. Setting value to $registerAsIMProvider"
                    $json.appPreferenceSettings.registerAsIMProvider = $registerAsIMProvider

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
                }
                catch { 
                    Write-Verbose -Verbose -Message "Failed to modify Teams setting: registerAsIMProvider"
                }

                try {
                    Write-Verbose -Verbose -Message "Creating and converting new content to Teams config file"
                    $newContent = $json | ConvertTo-Json
                    $newContent | Set-Content -Path $teamsConfigPath
                    Write-Verbose -Verbose -Message "Successfully applied new content to Teams config file at $teamsConfigPath"
                }
                catch { 
                    Write-Verbose -Verbose -Message "Failed to create and convert new content to Teams config file"   
                }

                if (($newContent) -AND ($teamsInstallLocation)) {
                    try {
                        Write-Verbose -Verbose -Message "Launching Microsoft Teams post processing config changes"
                        Start-Process -FilePath $teamsInstallLocation\Current\Teams.exe
                    }
                    catch { 
                        Write-Verbose -Verbose -Message "Failed to launch Microsoft Teams post processing config changes"       
                    }
                }                    
            }           
        }
    }
}

Write-Verbose -Verbose -Message "Script is done running. Thank you"
