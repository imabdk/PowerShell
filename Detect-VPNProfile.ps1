<#
.SYNOPSIS
    This scripts detects if the user has a relevant VPN profile, as configured with the vpnProfileVersion variable.
    This was made as an easy approach to version control.
   
.DESCRIPTION
    Currently when configuring the VPN profile via Intune and assign it to Windows 11 devices, Intune comes back with some random errors.
    Event logs comes back with event id 404, error CSP URI: (./User/Vendor/MSFT/VPNv2/W11-VPN-User-Tunnel), Result: (The specified quota list is internally inconsistent with its descriptor.

    This serves as an alternative to using Configuration Profiles in Intune and instead leverage Proactive Remediations.

.NOTES
    Filename: Detect-VPNProfile.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://imab.dk/deploy-your-always-on-vpn-profile-for-windows-11-using-proactive-remediations-in-microsoft-intune
    
#>

$global:RegistryPath = "HKCU:\SOFTWARE\imab.dk\VPN Profile"
$global:RegistryName = "VPNProfileVersion"
$global:vpnProfileVersion  = "1"
function Get-VPNProfileVersion() {
    if (Test-Path -Path $global:RegistryPath) {
        if (((Get-Item -Path $global:RegistryPath -ErrorAction SilentlyContinue).Property -contains $global:RegistryName) -eq $true) {
            $vpnVersion = (Get-ItemProperty -Path $global:RegistryPath -Name $global:RegistryName -ErrorAction SilentlyContinue).VPNProfileVersion
            if (-NOT[string]::IsNullOrEmpty($vpnVersion)) {
                Write-Output $vpnVersion
            }
        }
    }
}
$getVersion = Get-VPNProfileVersion
if (-NOT[string]::IsNullOrEmpty($getVersion)) {
    if ($getVersion -lt $global:vpnProfileVersion) {
        Write-Output "VPN profile version in registry is less than the version configured in the script. Needs updating"
        exit 1
    }
    elseif ($getVersion -eq $global:vpnProfileVersion) {
        Write-Output "VPN profile version in registry matches the version configured in the script. Doing nothing"
        exit 0
    }
    elseif ($getVersion -gt $global:vpnProfileVersion) {
        Write-Output "VPN profile version in registry is greater than the version configured in the script. This is unexpected. Doing nothing"
        exit 0
    }
}
else {
    Write-Output "VPN profile version not found in registry. This usually means, that the profile needs updating"
    exit 1   
}