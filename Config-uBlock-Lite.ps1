<#
.SYNOPSIS
    Configure uBlock Origin Lite extension via Group Policy for Microsoft Edge and Google Chrome

.DESCRIPTION
    Deploys uBlock Origin Lite (Manifest V3) extension configuration via registry-based Group Policy.
    Runs in SYSTEM context and configures HKLM registry keys.
    Provides simplified configuration suitable for the future-proof MV3 version.

.NOTES
    Author: Martin Bengtsson
    Requires: Administrator privileges
    Extension: uBlock Origin Lite (Manifest V3)
    Benefits: Future-proof, compatible with Chrome's Manifest V3 requirements
#>

#Requires -RunAsAdministrator

# ============================================
# Configuration
# ============================================

# --- Script Behavior ---
$RemoveConfiguration = $false  # Set to $true to REMOVE all uBlock Origin Lite policies instead of configuring them

# --- Browser Selection ---
$ConfigureEdge = $true         # Configure Microsoft Edge
$ConfigureChrome = $true       # Configure Google Chrome

# --- Extension Installation ---
$InstallExtension = $true      # Force-install the extension automatically

# --- Internal ---
$LogPrefix = "[uBlock-Lite]"

# ============================================
# uBlock Origin Lite Settings
# ============================================

# Default Filtering Mode
# Options: "none", "basic", "optimal", "complete"
$DefaultFiltering = "optimal"

# Show blocked count on extension icon
# 1 = true, 0 = false
$ShowBlockedCount = 1

# Strict block mode
# 1 = true, 0 = false
$StrictBlockMode = 1

# Disable first run page
# 1 = true, 0 = false
$DisableFirstRunPage = 1

# Trusted Sites - Sites where uBlock Lite will be disabled
# JSON array format: '["example.com", "trusted-site.org"]'
$NoFiltering = '["imab.dk", "mindcore.dk"]'

# ============================================
# Browser Definitions
# ============================================
$browsers = @{
    "Edge" = @{
        "Enabled" = $ConfigureEdge
        "PolicyPath" = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        "ExtensionID" = "cimighlppcgcoapaliogpjjdehbnofhn"
        "UpdateURL" = "https://edge.microsoft.com/extensionwebstorebase/v1/crx"
    }
    "Chrome" = @{
        "Enabled" = $ConfigureChrome
        "PolicyPath" = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        "ExtensionID" = "ddkjiahejlhfcafbddmgiahcphecmpfh"
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
    $litePolicyPath = "$($browser.PolicyPath)\3rdparty\extensions\$($browser.ExtensionID)\policy"
    $extensionInstallPath = "$($browser.PolicyPath)\ExtensionInstallForcelist"
    
    # ============================================
    # Remove Configuration Mode
    # ============================================
    
    If ($RemoveConfiguration) {
        Write-Output "$LogPrefix REMOVING uBlock Origin Lite configuration for $browserName"
        
        # Remove from force install list
        If (Test-Path -Path $extensionInstallPath) {
            $existingItems = Get-ItemProperty -Path $extensionInstallPath -ErrorAction SilentlyContinue
            
            If ($existingItems) {
                $existingProps = $existingItems.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
                
                ForEach ($prop in $existingProps) {
                    If ($prop.Value -like "$($browser.ExtensionID)*") {
                        Remove-ItemProperty -Path $extensionInstallPath -Name $prop.Name -ErrorAction SilentlyContinue
                        Write-Output "$LogPrefix Removed from force install list (index: $($prop.Name))."
                    }
                }
            }
        }
        
        # Remove policy configuration
        If (Test-Path -Path $litePolicyPath) {
            Remove-Item -Path $litePolicyPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Output "$LogPrefix Removed policy configuration."
        }
        
        Write-Output "$LogPrefix $browserName configuration removal completed!"
        Continue
    }
    
    # ============================================
    # Normal Configuration Mode
    # ============================================
    
    Write-Output "$LogPrefix Configuring uBlock Origin Lite for $browserName"
    
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
            
            # Check existing extensions and find next available index
            $existingItems = Get-ItemProperty -Path $extensionInstallPath -ErrorAction SilentlyContinue
            $existingProps = $existingItems.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
            
            # Check if already installed
            $alreadyInstalled = $existingProps | Where-Object { $_.Value -like "$($browser.ExtensionID)*" } | Select-Object -First 1
            
            If ($alreadyInstalled) {
                Write-Output "$LogPrefix uBlock Origin Lite is already in the $browserName force install list (index: $($alreadyInstalled.Name))."
            } Else {
                # Find next available index
                $nextIndex = If ($existingProps) { (($existingProps.Name | ForEach-Object { [int]$_ }) | Measure-Object -Maximum).Maximum + 1 } Else { 1 }
            
                Set-ItemProperty -Path $extensionInstallPath -Name "$nextIndex" -Value $extensionValue -Type String -ErrorAction Stop
                Write-Output "$LogPrefix Added uBlock Origin Lite to $browserName extension force install list (index: $nextIndex)."
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
    # uBlock Origin Lite Configuration
    # ============================================
    
    Write-Output "$LogPrefix Configuring uBlock Origin Lite for $browserName..."
    
    Try {
        If (-Not (Test-Path -Path $litePolicyPath)) {
            New-Item -Force -Path $litePolicyPath -ErrorAction Stop | Out-Null
            Write-Output "$LogPrefix Created policy path for uBlock Origin Lite."
        }
        
        # Apply configuration settings
        $settings = @(
            @{ Name = "defaultFiltering"; Value = $DefaultFiltering; Type = "String" }
            @{ Name = "showBlockedCount"; Value = $ShowBlockedCount; Type = "DWord" }
            @{ Name = "strictBlockMode"; Value = $StrictBlockMode; Type = "DWord" }
            @{ Name = "disableFirstRunPage"; Value = $DisableFirstRunPage; Type = "DWord" }
            @{ Name = "noFiltering"; Value = $NoFiltering; Type = "String" }
        )
        
        ForEach ($setting in $settings) {
            Set-ItemProperty -Path $litePolicyPath -Name $setting.Name -Value $setting.Value -Type $setting.Type -ErrorAction Stop
        }
        
        Write-Output "$LogPrefix Applied configuration for uBlock Origin Lite."
    }
    Catch {
        Write-Output "$LogPrefix ERROR: Failed to configure uBlock Origin Lite - $($_.Exception.Message)"
        Exit 1
    }
    
    Write-Output "$LogPrefix $browserName configuration completed successfully!"

} # End ForEach browser

Write-Output "$LogPrefix All browser operations completed successfully!"

# Exit with success code for Intune
Exit 0
