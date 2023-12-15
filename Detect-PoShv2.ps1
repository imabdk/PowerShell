<#
.SYNOPSIS
    This script checks if Windows PowerShell version 2.0 is enabled on the system.

.DESCRIPTION
    The script uses the Get-WindowsOptionalFeature cmdlet to get the status of the "MicrosoftWindowsPowerShellV2Root" feature, which represents Windows PowerShell version 2.0. If the feature is enabled, the script exits with a status code of 1.

.NOTES
    Filename: Detect-PoShv2.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson
#>
# Get the state of the PowerShell v2.0 feature
try {
    $PoShv2Enabled = Get-WindowsOptionalFeature -FeatureName "MicrosoftWindowsPowerShellV2Root" -Online | Select-Object -ExpandProperty State
} catch {
    Write-Error "Failed to get the state of the PowerShell v2.0 feature: $_"
    exit 1
}
# If the feature is enabled, exit with a status code of 1
if ($PoShv2Enabled -eq "Enabled") {
    exit 1
}