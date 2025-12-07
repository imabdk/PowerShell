<#
.SYNOPSIS
    Configure uBlock Origin Lite extension via Group Policy for Microsoft Edge or Google Chrome

.DESCRIPTION
    Deploys uBlock Origin Lite (Manifest V3) extension configuration via registry-based Group Policy.
    Runs in SYSTEM context and configures HKLM registry keys.
    Provides simplified configuration suitable for the future-proof MV3 version.
    
    Extension installation is handled separately by Intune - this script only configures settings.

.PARAMETER Browser
    Target browser(s). Options: "Edge", "Chrome", or both. Default: "Edge"

.PARAMETER RemoveConfiguration
    Set to $true to remove all uBlock Origin Lite policies instead of configuring them

.PARAMETER DefaultFiltering
    Default filtering mode. Options: "none", "basic", "optimal", "complete"

.PARAMETER ShowBlockedCount
    Show blocked count on extension icon. 1 = true, 0 = false

.PARAMETER StrictBlockMode
    Strict block mode. 1 = true, 0 = false

.PARAMETER DisableFirstRunPage
    Disable first run page. 1 = true, 0 = false

.PARAMETER NoFiltering
    Trusted sites where uBlock Lite will be disabled. JSON array format: '["example.com", "trusted-site.org"]'

.PARAMETER DisabledFeatures
    Disable specific user-facing features. JSON array format: '["dashboard", "develop", "filteringMode", "picker", "zapper"]'
    Options: dashboard (prevent setting changes), develop (prevent developer mode), filteringMode (prevent filtering mode changes), picker (prevent custom filters), zapper (prevent element removal)

.PARAMETER Rulesets
    Enable/disable specific rulesets. JSON array format: '["+default", "+adguard-url-tracking", "-easylist-cookies"]'
    Use + to enable, - to disable. Special value "-*" disables all non-default rulesets. See https://github.com/uBlockOrigin/uBOL-home/blob/main/chromium/rulesets/ruleset-details.json for ruleset IDs
    
    Default rulesets (already enabled): ublock-filters, ublock-badware, ublock-privacy, ublock-unbreak, easylist, easyprivacy, plowe-0, urlhaus-full
    
    Common additional rulesets to enable:
    - adguard-spyware-url: Removes tracking parameters from URLs (AdGuard URL Tracking Protection)
    - annoyances-cookies: Blocks cookie consent notices (EasyList/uBO)
    - annoyances-overlays: Blocks popups and overlay notices (EasyList/uBO)
    - annoyances-social: Blocks social widgets (EasyList)
    - annoyances-notifications: Blocks notification prompts (EasyList)
    - adguard-mobile: Mobile-specific ad blocking (AdGuard/uBO)
    
    Example: '["+default", "+adguard-spyware-url", "+annoyances-cookies", "+annoyances-overlays"]'

.NOTES
    Author: Martin Bengtsson
    Blog: https://www.imab.dk
    Requires: Administrator privileges
    Extension: uBlock Origin Lite (Manifest V3)
    Extension ID (Edge): cimighlppcgcoapaliogpjjdehbnofhn
    Extension ID (Chrome): ddkjiahejlhfcafbddmgiahcphecmpfh
#>

#Requires -RunAsAdministrator

Param(
    [ValidateSet("Edge", "Chrome")]
    [string[]]$Browser = @("Edge", "Chrome"),

    [bool]$RemoveConfiguration = $false,

    [ValidateSet("none", "basic", "optimal", "complete")]
    [string]$DefaultFiltering = "optimal",

    [ValidateRange(0, 1)]
    [int]$ShowBlockedCount = 1,

    [ValidateRange(0, 1)]
    [int]$StrictBlockMode = 1,

    [ValidateRange(0, 1)]
    [int]$DisableFirstRunPage = 1,

    [string]$NoFiltering = '["imab.dk", "contoso.com", "contoso.sharepoint.com", "app.powerbi.com", "community.powerbi.com", "intranet.contoso.com", "portal.contoso.com", "app.bundledocs.com"]',

    # Available features: "dashboard", "develop", "filteringMode", "picker", "zapper"
    [string]$DisabledFeatures = '["dashboard"]',

    # Use +ruleset to enable, -ruleset to disable, -* to disable all except specified
    # Ruleset IDs: https://github.com/uBlockOrigin/uBOL-home/blob/main/chromium/rulesets/ruleset-details.json
    [string]$Rulesets = '["+default"]'
)

# Helper Functions

Function Get-BrowserPolicyPath {
    Param([string]$Browser)
    if ($Browser -eq "Edge") {
        return "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    } else {
        return "HKLM:\SOFTWARE\Policies\Google\Chrome"
    }
}

Function Get-ExtensionID {
    Param([string]$Browser)
    if ($Browser -eq "Edge") {
        return "cimighlppcgcoapaliogpjjdehbnofhn"
    } else {
        return "ddkjiahejlhfcafbddmgiahcphecmpfh"
    }
}

Function Get-ExtensionPolicyPath {
    Param(
        [string]$Browser,
        [string]$ExtensionID
    )
    return "$(Get-BrowserPolicyPath $Browser)\3rdparty\extensions\$ExtensionID\policy"
}

Function Set-RegistryProperty {
    Param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [ValidateSet("String", "DWord")]
        [string]$Type
    )
    
    Try {
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
        Write-Output "$LogPrefix Set '$Name' successfully"
    }
    Catch {
        Write-Output "$LogPrefix ERROR: Failed to set '$Name' - $($_.Exception.Message)"
    }
}

Function Initialize-ExtensionPath {
    Param(
        [string]$Browser,
        [string]$ExtensionID
    )
    
    $extensionPath = Get-ExtensionPolicyPath -Browser $Browser -ExtensionID $ExtensionID
    
    Try {
        if (-not (Test-Path $extensionPath)) {
            New-Item -Path $extensionPath -Force -ErrorAction Stop | Out-Null
        }
        return $extensionPath
    }
    Catch {
        Write-Output "$LogPrefix ERROR: Failed to create registry path - $($_.Exception.Message)"
        return $null
    }
}

Function Remove-ExtensionConfiguration {
    Param(
        [string]$Browser,
        [string]$ExtensionID
    )
    
    Write-Output "$LogPrefix REMOVING configuration for $Browser"
    
    $policyPath = Get-ExtensionPolicyPath -Browser $Browser -ExtensionID $ExtensionID
    
    if (Test-Path -Path $policyPath) {
        Try {
            Remove-Item -Path $policyPath -Recurse -Force -ErrorAction Stop
            Write-Output "$LogPrefix Removed policy configuration"
        }
        Catch {
            Write-Output "$LogPrefix ERROR: Failed to remove configuration - $($_.Exception.Message)"
            Exit 1
        }
    }
    
    Write-Output "$LogPrefix Configuration removal completed!"
    Exit 0
}

# Configuration

$LogPrefix = "[uBlock-Lite]"

# Remove Configuration Mode

If ($RemoveConfiguration) {
    foreach ($BrowserName in $Browser) {
        $extensionID = Get-ExtensionID -Browser $BrowserName
        Remove-ExtensionConfiguration -Browser $BrowserName -ExtensionID $extensionID
    }
}

# Apply Configuration

$settings = @(
    @{ Name = "defaultFiltering"; Value = $DefaultFiltering; Type = "String" }
    @{ Name = "showBlockedCount"; Value = $ShowBlockedCount; Type = "DWord" }
    @{ Name = "strictBlockMode"; Value = $StrictBlockMode; Type = "DWord" }
    @{ Name = "disableFirstRunPage"; Value = $DisableFirstRunPage; Type = "DWord" }
    @{ Name = "noFiltering"; Value = $NoFiltering; Type = "String" }
    @{ Name = "disabledFeatures"; Value = $DisabledFeatures; Type = "String" }
    @{ Name = "rulesets"; Value = $Rulesets; Type = "String" }
)

foreach ($BrowserName in $Browser) {
    $extensionID = Get-ExtensionID -Browser $BrowserName

    Write-Output "$LogPrefix Configuring for $BrowserName"

    $litePolicyPath = Initialize-ExtensionPath -Browser $BrowserName -ExtensionID $extensionID

    if (-not $litePolicyPath) {
        Write-Output "$LogPrefix ERROR: Failed to initialize extension path for $BrowserName"
        Exit 1
    }

    foreach ($setting in $settings) {
        Write-Output "$LogPrefix Applying setting: $($setting.Name) = $($setting.Value)"
        Set-RegistryProperty -Path $litePolicyPath -Name $setting.Name -Value $setting.Value -Type $setting.Type | Out-Null
    }

    Write-Output "$LogPrefix Configuration completed successfully for $BrowserName!"
}

Write-Output "$LogPrefix Restart browser(s) for changes to take effect"

Exit 0
