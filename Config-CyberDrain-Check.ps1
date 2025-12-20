<#
.SYNOPSIS
    Configure CyberDrain Check Extension via Group Policy for Microsoft Edge or Google Chrome

.DESCRIPTION
    Configures CyberDrain Check Extension via registry-based Group Policy.
    Runs in SYSTEM context and writes settings to HKLM registry keys.

.PARAMETER Browser
    Target browser(s). Options: "Edge", "Chrome", or both. Default: "Edge"

.PARAMETER RemoveConfiguration
    Set to $true to remove all extension policies instead of configuring them

.PARAMETER ShowNotifications
    Enable or disable extension notifications. Default: $true

.PARAMETER EnableValidPageBadge
    Show badge on valid pages. Default: $true

.PARAMETER EnablePageBlocking
    Enable page blocking functionality. Default: $true

.PARAMETER EnableDebugLogging
    Enable debug logging. Default: $false

.PARAMETER UpdateInterval
    Update interval in hours. Default: 24

.PARAMETER EnableCippReporting
    Enable CIPP integration reporting. Default: $false

.PARAMETER CippServerUrl
    CIPP server URL for integration

.PARAMETER CippTenantId
    CIPP tenant ID for integration

.PARAMETER CustomRulesUrl
    URL for custom rules configuration

.PARAMETER UrlAllowlist
    Array of URLs to allowlist. Default: @("https://*.contoso.com/*")

.PARAMETER EnableGenericWebhook
    Enable generic webhook integration. Default: $false

.PARAMETER GenericWebhookUrl
    Generic webhook URL

.PARAMETER GenericWebhookEvents
    Array of events to trigger webhook

.PARAMETER CompanyName
    Company name for branding. Default: "Contoso"

.PARAMETER CompanyURL
    Company URL for branding. Default: "https://contoso.com"

.PARAMETER ProductName
    Product name for branding. Default: "Contoso IT"

.PARAMETER SupportEmail
    Support email for branding. Default: "support@contoso.com"

.PARAMETER PrimaryColor
    Primary color for branding (hex format). Default: "#0078D4"

.PARAMETER LogoUrl
    Logo URL for branding

.NOTES
    Author: Martin Bengtsson
    Blog: https://www.imab.dk
    Requires: Administrator privileges
    Extension: CyberDrain Check Extension
    Extension ID (Edge): knepjpocdagponkonnbggpcnhnaikajg
    Extension ID (Chrome): benimdeioplgkhanklclahllklceahbe
#>

#Requires -RunAsAdministrator

Param(
    [ValidateSet("Edge", "Chrome")]
    [string[]]$Browser = @("Edge", "Chrome"),

    [bool]$RemoveConfiguration = $false,

    # Extension Configuration Settings
    # 0 = Unchecked, 1 = Checked (Enabled); default is 1
    # This will set the "Show Notifications" option in the extension settings
    [bool]$ShowNotifications = $true,
    
    # 0 = Unchecked, 1 = Checked (Enabled); default is 0
    # This will set the "Show Valid Page Badge" option in the extension settings
    [bool]$EnableValidPageBadge = $true,
    
    # 0 = Unchecked, 1 = Checked (Enabled); default is 1
    # This will set the "Enable Page Blocking" option in the extension settings
    [bool]$EnablePageBlocking = $true,
    
    # 0 = Unchecked, 1 = Checked (Enabled); default is 0
    # This will set the "Enable Debug Logging" option in the Activity Log settings
    [bool]$EnableDebugLogging = $false,
    
    # This will set the "Update Interval" option in the Detection Configuration settings
    # Default is 24 (hours). Range: 1-168 hours (1 hour to 1 week)
    [ValidateRange(1, 168)]
    [int]$UpdateInterval = 24,
    
    # CIPP Integration
    # 0 = Unchecked, 1 = Checked (Enabled); default is 0
    # This will set the "Enable CIPP Reporting" option in the extension settings
    [bool]$EnableCippReporting = $false,
    
    # This will set the "CIPP Server URL" option in the extension settings
    # Default is blank; if you set $EnableCippReporting to $true, you must set this to a valid URL including the protocol
    # Example: https://cipp.cyberdrain.com - Can be vanity URL or the default azurestaticapps.net domain
    [string]$CippServerUrl = "",
    
    # This will set the "Tenant ID/Domain" option in the extension settings
    # Default is blank; if you set $EnableCippReporting to $true, you must set this to a valid Tenant ID
    [string]$CippTenantId = "",
    
    # Custom Rules & Allowlist
    # This will set the "Config URL" option in the Detection Configuration settings
    # Default is blank
    [string]$CustomRulesUrl = "",
    
    # This will set the "URL Allowlist" option in the Detection Configuration settings
    # Default is blank; if you want to add multiple URLs, add them as a comma-separated array
    # Example: @("https://example1.com", "https://example2.com")
    # Supports simple URLs with * wildcard (e.g., https://*.example.com) or advanced regex patterns
    [string[]]$UrlAllowlist = @("https://*.contoso.com/*"),
    
    # Generic Webhook
    [bool]$EnableGenericWebhook = $false,
    [string]$GenericWebhookUrl = "",
    [string[]]$GenericWebhookEvents = @(),
    
    # Custom Branding Settings
    # This will set the "Company Name" option in the Custom Branding settings
    # Default is "Contoso"
    [string]$CompanyName = "Contoso",
    
    # This will set the Company URL option in the Custom Branding settings
    # Default is "https://contoso.com"; Must include the protocol (e.g., https://)
    [string]$CompanyURL = "https://contoso.com",
    
    # This will set the "Product Name" option in the Custom Branding settings
    # Default is "Contoso IT"
    [string]$ProductName = "Contoso IT",
    
    # This will set the "Support Email" option in the Custom Branding settings
    # Default is blank
    [string]$SupportEmail = "support@contoso.com",
    
    # This will set the "Primary Color" option in the Custom Branding settings
    # Default is "#0078D4"; must be a valid hex color code (e.g., #FFFFFF)
    [ValidatePattern('^#[0-9A-Fa-f]{6}$')]
    [string]$PrimaryColor = "#0078D4",
    
    # This will set the "Logo URL" option in the Custom Branding settings
    # Default is blank. Must be a valid URL including the protocol (e.g., https://example.com/logo.png)
    # Protocol must be https; recommended size is 48x48 pixels with a maximum of 128x128
    [string]$LogoUrl = ""
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
        return "knepjpocdagponkonnbggpcnhnaikajg"
    } else {
        return "benimdeioplgkhanklclahllklceahbe"
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

$LogPrefix = "[CyberDrain-Check]"

# Remove Configuration Mode

If ($RemoveConfiguration) {
    foreach ($BrowserName in $Browser) {
        $extensionID = Get-ExtensionID -Browser $BrowserName
        Remove-ExtensionConfiguration -Browser $BrowserName -ExtensionID $extensionID
    }
}

# Apply Configuration

$settings = @(
    @{ Name = "showNotifications"; Value = ([int]$ShowNotifications); Type = "DWord" }
    @{ Name = "enableValidPageBadge"; Value = ([int]$EnableValidPageBadge); Type = "DWord" }
    @{ Name = "enablePageBlocking"; Value = ([int]$EnablePageBlocking); Type = "DWord" }
    @{ Name = "enableDebugLogging"; Value = ([int]$EnableDebugLogging); Type = "DWord" }
    @{ Name = "updateInterval"; Value = $UpdateInterval; Type = "DWord" }
)

# Add CIPP settings if enabled
if ($EnableCippReporting) {
    $settings += @{ Name = "enableCippReporting"; Value = 1; Type = "DWord" }
    if ($CippServerUrl) {
        $settings += @{ Name = "cippServerUrl"; Value = $CippServerUrl; Type = "String" }
    }
    if ($CippTenantId) {
        $settings += @{ Name = "cippTenantId"; Value = $CippTenantId; Type = "String" }
    }
}

# Add custom rules URL if provided
if ($CustomRulesUrl) {
    $settings += @{ Name = "customRulesUrl"; Value = $CustomRulesUrl; Type = "String" }
}

# Add URL allowlist if provided
if ($UrlAllowlist.Count -gt 0) {
    $json = $UrlAllowlist | ConvertTo-Json -Compress
    $settings += @{ Name = "urlAllowlist"; Value = $json; Type = "String" }
}

# Add generic webhook if enabled
if ($EnableGenericWebhook) {
    $webhook = @{ enabled = $true }
    if ($GenericWebhookUrl) { $webhook.url = $GenericWebhookUrl }
    if ($GenericWebhookEvents.Count -gt 0) { $webhook.events = $GenericWebhookEvents }
    $json = $webhook | ConvertTo-Json -Compress
    $settings += @{ Name = "genericWebhook"; Value = $json; Type = "String" }
}

# Add custom branding
$branding = @{}
if ($CompanyName) { $branding.companyName = $CompanyName }
if ($CompanyURL) { $branding.companyURL = $CompanyURL }
if ($ProductName) { $branding.productName = $ProductName }
if ($SupportEmail) { $branding.supportEmail = $SupportEmail }
if ($PrimaryColor) { $branding.primaryColor = $PrimaryColor }
if ($LogoUrl) { $branding.logoUrl = $LogoUrl }

if ($branding.Count -gt 0) {
    $json = $branding | ConvertTo-Json -Compress
    $settings += @{ Name = "customBranding"; Value = $json; Type = "String" }
}

foreach ($BrowserName in $Browser) {
    $extensionID = Get-ExtensionID -Browser $BrowserName

    Write-Output "$LogPrefix Configuring for $BrowserName"

    $policyPath = Initialize-ExtensionPath -Browser $BrowserName -ExtensionID $extensionID

    if (-not $policyPath) {
        Write-Output "$LogPrefix ERROR: Failed to initialize extension path for $BrowserName"
        Exit 1
    }

    foreach ($setting in $settings) {
        Write-Output "$LogPrefix Applying setting: $($setting.Name) = $($setting.Value)"
        Set-RegistryProperty -Path $policyPath -Name $setting.Name -Value $setting.Value -Type $setting.Type | Out-Null
    }

    Write-Output "$LogPrefix Configuration completed successfully for $BrowserName!"
}

Write-Output "$LogPrefix Restart browser(s) for changes to take effect"

Exit 0

