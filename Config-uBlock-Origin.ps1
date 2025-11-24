<#
.SYNOPSIS
    Configure uBlock Origin extension via Group Policy for Microsoft Edge and Google Chrome

.DESCRIPTION
    Deploys uBlock Origin (Manifest V2) extension configuration via registry-based Group Policy.
    Runs in SYSTEM context and configures HKLM registry keys.
    Provides full-featured configuration with detailed user settings, filter lists, and custom filters.

.NOTES
    Author: Martin Bengtsson
    Requires: Administrator privileges
    Extension: uBlock Origin (Manifest V2)
    Note: Chrome is deprecating Manifest V2 - consider uBlock Origin Lite for long-term Chrome support
#>

#Requires -RunAsAdministrator

# ============================================
# Configuration
# ============================================

# --- Script Behavior ---
$RemoveConfiguration = $true  # Set to $true to REMOVE all uBlock Origin policies instead of configuring them

# --- Browser Selection ---
$ConfigureEdge = $true         # Configure Microsoft Edge
$ConfigureChrome = $true       # Configure Google Chrome

# --- Extension Installation ---
$InstallExtension = $true      # Force-install the extension automatically

# --- Advanced: Chrome Manifest V2 Policy ---
# Chrome is deprecating Manifest V2. Setting this to $true allows MV2 extensions that are force-installed.
$EnableManifestV2 = $true

# --- Internal ---
$LogPrefix = "[uBlock-Origin]"

# ============================================
# Browser Definitions
# ============================================
$browsers = @{
    "Edge" = @{
        "Enabled" = $ConfigureEdge
        "PolicyPath" = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        "ExtensionID" = "odfafepnkmbhccpbejgmiehpchacaeak"
        "UpdateURL" = "https://edge.microsoft.com/extensionwebstorebase/v1/crx"
    }
    "Chrome" = @{
        "Enabled" = $ConfigureChrome
        "PolicyPath" = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        "ExtensionID" = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        "UpdateURL" = "https://clients2.google.com/service/update2/crx"
    }
}

# ============================================
# Process Each Browser
# ============================================

ForEach ($browserName in $browsers.Keys) {
    $browser = $browsers[$browserName]
    
    If (-Not $browser.Enabled) {
        Write-Output "$LogPrefix Skipping $browserName (disabled in configuration)"
        Continue
    }
    
    # Build registry paths
    $uBlockPolicyPath = "$($browser.PolicyPath)\3rdparty\Extensions\$($browser.ExtensionID)\policy"
    $extensionInstallPath = "$($browser.PolicyPath)\ExtensionInstallForcelist"
    
    # ============================================
    # Remove Configuration Mode
    # ============================================
    
    If ($RemoveConfiguration) {
        Write-Output "$LogPrefix REMOVING uBlock Origin configuration for $browserName"
        
        # Remove from force install list
        If (Test-Path -Path $extensionInstallPath) {
            Write-Output "$LogPrefix Checking extension force install list..."
            $existingItems = Get-ItemProperty -Path $extensionInstallPath -ErrorAction SilentlyContinue
            
            If ($existingItems) {
                $existingProps = $existingItems.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
                $removed = $false
                
                ForEach ($prop in $existingProps) {
                    If ($prop.Value -like "$($browser.ExtensionID)*") {
                        Remove-ItemProperty -Path $extensionInstallPath -Name $prop.Name -ErrorAction SilentlyContinue
                        Write-Output "$LogPrefix Removed uBlock Origin from force install list (index: $($prop.Name))."
                        $removed = $true
                    }
                }
                
                If (-Not $removed) {
                    Write-Output "$LogPrefix uBlock Origin was not found in the force install list."
                }
            }
        } Else {
            Write-Output "$LogPrefix Extension force install list does not exist for $browserName."
        }
        
        # Remove uBlock policy configuration
        If (Test-Path -Path $uBlockPolicyPath) {
            Remove-Item -Path $uBlockPolicyPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Output "$LogPrefix Removed uBlock Origin policy configuration for $browserName."
        } Else {
            Write-Output "$LogPrefix uBlock Origin policy configuration does not exist for $browserName."
        }
        
        Write-Output "$LogPrefix $browserName configuration removal completed!"
        Continue
    }
    
    # ============================================
    # Normal Configuration Mode
    # ============================================
    
    Write-Output "$LogPrefix Configuring uBlock Origin for $browserName"
    
    # ============================================
    # Extension Force Installation
    # ============================================
    
    If ($InstallExtension) {
        Write-Output "$LogPrefix Configuring extension force installation for $browserName..."
        
        Try {
            If (-Not (Test-Path -Path $extensionInstallPath)) { 
                New-Item -Force -Path $extensionInstallPath -ErrorAction Stop | Out-Null
                Write-Output "$LogPrefix Created ExtensionInstallForcelist registry key for $browserName."
            }
            
            $extensionValue = "$($browser.ExtensionID);$($browser.UpdateURL)"
            
            # Find next available index
            $existingItems = Get-ItemProperty -Path $extensionInstallPath -ErrorAction SilentlyContinue
            $nextIndex = 1
            If ($existingItems) {
                $existingProps = $existingItems.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
                If ($existingProps) {
                    $nextIndex = ($existingProps.Name | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum + 1
                }
            }
            
            # Check if already in list
            $alreadyInstalled = $false
            If ($existingItems) {
                $existingProps = $existingItems.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
                ForEach ($prop in $existingProps) {
                    If ($prop.Value -like "$($browser.ExtensionID)*") {
                        $alreadyInstalled = $true
                        Write-Output "$LogPrefix uBlock Origin is already in the $browserName force install list (index: $($prop.Name))."
                        Break
                    }
                }
            }
            
            If (-Not $alreadyInstalled) {
                Set-ItemProperty -Path $extensionInstallPath -Name "$nextIndex" -Value $extensionValue -Type String -ErrorAction Stop
                Write-Output "$LogPrefix Added uBlock Origin to $browserName extension force install list (index: $nextIndex)."
                Write-Output "$LogPrefix The extension will be automatically installed when $browserName is restarted."
            }
        }
        Catch {
            Write-Output "$LogPrefix ERROR: Failed to configure extension force installation for $browserName - $($_.Exception.Message)"
            Exit 1
        }
    } Else {
        Write-Output "$LogPrefix Skipping extension force installation for $browserName (disabled in configuration)."
    }
    
    # ============================================
    # Chrome Manifest V2 Support Configuration
    # ============================================
    
    If ($browserName -eq "Chrome" -and $EnableManifestV2) {
        Write-Output "$LogPrefix Configuring Manifest V2 support for Chrome..."
        Try {
            $manifestV2Path = "$($browser.PolicyPath)"
            
            If (-Not (Test-Path -Path $manifestV2Path)) {
                New-Item -Force -Path $manifestV2Path -ErrorAction Stop | Out-Null
            }
            
            Set-ItemProperty -Path $manifestV2Path -Name "ExtensionManifestV2Availability" -Value 3 -Type DWord -ErrorAction Stop
            Write-Output "$LogPrefix Set ExtensionManifestV2Availability to 3 (Manifest V2 enabled for force-installed extensions only)."
        }
        Catch {
            Write-Output "$LogPrefix ERROR: Failed to configure Manifest V2 support - $($_.Exception.Message)"
            Exit 1
        }
    }
    
    # ============================================
    # uBlock Origin Configuration
    # ============================================
    
    Write-Output "$LogPrefix Configuring uBlock Origin for $browserName..."
    
    # Create policy path if it doesn't exist
    Try {
        If (-Not (Test-Path -Path $uBlockPolicyPath)) { 
            New-Item -Force -Path $uBlockPolicyPath -ErrorAction Stop | Out-Null
            Write-Output "$LogPrefix Created uBlock Origin policy registry path for $browserName."
        }
    }
    Catch {
        Write-Output "$LogPrefix ERROR: Failed to create policy path - $($_.Exception.Message)"
        Exit 1
    }
    
    Write-Output "$LogPrefix Applying uBlock Origin configuration for $browserName..."

    # ============================================
    # User Settings Configuration
    # Set to "true" or "false" to enable/disable
    # ============================================

    # General Settings
    $hidePlaceholders = "true"             # Hide placeholders of blocked elements
    $showIconBadge = "false"               # Show blocked count on icon
    $contextMenuEnabled = "true"           # Enable right-click context menu
    $cloudStorageEnabled = "false"         # Enable cloud storage support

    # Privacy Settings
    $prefetchingDisabled = "true"          # Disable prefetching
    $hyperlinkAuditingDisabled = "true"    # Disable hyperlink auditing/tracking
    $blockCSPReports = "false"             # Block CSP reports
    $cnameUncloakEnabled = "false"         # Uncloak canonical names (Firefox only)

    # Appearance Settings
    $uiTheme = "auto"                      # Theme: "light", "dark", or "auto"
    $colorBlindFriendly = "false"          # Color-blind friendly mode
    $tooltipsDisabled = "false"            # Disable tooltips

    # Default Behavior (Global per-site switches)
    $noCosmeticFiltering = "false"         # Disable cosmetic filtering globally
    $noLargeMedia = "false"                # Block large media elements globally
    $noRemoteFonts = "false"               # Block remote fonts globally
    $noScripting = "false"                 # Disable JavaScript globally

    # Advanced Settings
    $advancedUserEnabled = "false"         # Enable advanced user mode
    $dynamicFilteringEnabled = "false"     # Enable dynamic filtering (requires advanced mode)

    # Build userSettings array
    $userSettingsArray = @(
        "[ `"contextMenuEnabled`", `"$contextMenuEnabled`" ]",
        "[ `"showIconBadge`", `"$showIconBadge`" ]",
        "[ `"hidePlaceholders`", `"$hidePlaceholders`" ]",
        "[ `"cloudStorageEnabled`", `"$cloudStorageEnabled`" ]",
        "[ `"prefetchingDisabled`", `"$prefetchingDisabled`" ]",
        "[ `"hyperlinkAuditingDisabled`", `"$hyperlinkAuditingDisabled`" ]",
        "[ `"blockCSPReports`", `"$blockCSPReports`" ]",
        "[ `"cnameUncloakEnabled`", `"$cnameUncloakEnabled`" ]",
        "[ `"uiTheme`", `"$uiTheme`" ]",
        "[ `"colorBlindFriendly`", `"$colorBlindFriendly`" ]",
        "[ `"tooltipsDisabled`", `"$tooltipsDisabled`" ]",
        "[ `"noCosmeticFiltering`", `"$noCosmeticFiltering`" ]",
        "[ `"noLargeMedia`", `"$noLargeMedia`" ]",
        "[ `"noRemoteFonts`", `"$noRemoteFonts`" ]",
        "[ `"noScripting`", `"$noScripting`" ]",
        "[ `"advancedUserEnabled`", `"$advancedUserEnabled`" ]",
        "[ `"dynamicFilteringEnabled`", `"$dynamicFilteringEnabled`" ]"
    )

    $userSettingsValue = "[ " + ($userSettingsArray -join ", ") + " ]"

    # Apply userSettings
    $userSettings = @{
        "Force" = $true
        "Path"  = "$uBlockPolicyPath"
        "Type"  = "String"
        "Name"  = "userSettings"
        "Value" = $userSettingsValue
    }
    Try {
        Set-ItemProperty @userSettings -ErrorAction Stop
        Write-Output "$LogPrefix Applied userSettings for $browserName."
    }
    Catch {
        Write-Output "$LogPrefix ERROR: Failed to apply userSettings - $($_.Exception.Message)"
        Exit 1
    }

    # ============================================
    # Filter Lists and Custom Filters
    # ============================================

    # Filter Lists - Add or remove filter list tokens
    $filterLists = @(
        "user-filters",
        "ublock-filters",
        "ublock-badware",
        "ublock-privacy",
        "ublock-abuse",
        "ublock-unbreak",
        "easylist",
        "easyprivacy",
        "urlhaus-1",
        "adguard-annoyance",
        "ublock-annoyances",
        "plowe-0"
    )

    # Trusted Sites - Sites where uBlock will be disabled
    $trustedSites = @(
        "chrome-extension-scheme"
        "moz-extension-scheme",
        "imab.dk",
        "mindcore.dk"
        # Add more trusted sites below (one per line):
        # "example.com",
        # "trusted-site.org"
    )

    # Custom Filters - Add custom blocking rules
    $customFilters = @(
        # "! Test filters",
        # "||test.com^`$important",
        # "||example.com^`$important"
    )

    # Build the toOverwrite JSON value
    $filterListsJson = ($filterLists | ForEach-Object { "`"$_`"" }) -join ", "
    $trustedSitesJson = ($trustedSites | ForEach-Object { "`"$_`"" }) -join ", "
    $customFiltersJson = ($customFilters | ForEach-Object { "`"$_`"" }) -join ", "

    $toOverwriteValue = "{ `"filterLists`": [ $filterListsJson ], `"trustedSiteDirectives`": [ $trustedSitesJson ], `"filters`": [ $customFiltersJson ] }"

    # Apply toOverwrite configuration
    $toOverwrite = @{
        "Force" = $true
        "Path"  = "$uBlockPolicyPath"
        "Type"  = "String"
        "Name"  = "toOverwrite"
        "Value" = $toOverwriteValue
    }
    Try {
        Set-ItemProperty @toOverwrite -ErrorAction Stop
        Write-Output "$LogPrefix Applied filter lists and custom filters for $browserName."
    }
    Catch {
        Write-Output "$LogPrefix ERROR: Failed to apply filter configuration - $($_.Exception.Message)"
        Exit 1
    }

    Write-Output "$LogPrefix $browserName configuration completed successfully!"

} # End ForEach browser

If ($RemoveConfiguration) {
    Write-Output "$LogPrefix All browser configuration removals completed successfully!"
} Else {
    Write-Output "$LogPrefix All browser configurations completed successfully!"
}

# Exit with success code for Intune
Exit 0
