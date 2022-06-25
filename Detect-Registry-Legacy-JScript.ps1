<#
.SYNOPSIS
    This script will detect if one or more specific registry keys within the same path is configured with the set value.
    Script will exit with exit code 1 or 0, depending on mismatch or not, instructing Intune to potentially run the remediation script
   

    This is currently tailored directly towards replacing the GPO: MSFT Microsoft 365 Apps v2206 - Legacy JScript Block - Computer
    With a few adjustments, this can be used to configure any registry key and value

.DESCRIPTION
    Same as above

.NOTES
    Filename: Detect-Legacy-JScript-Registry.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/use-group-policy-analytics-to-move-microsoft-365-apps-security-baseline-to-the-cloud
#> 

#region Functions
function Test-RegistryKeyValue() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The path to the registry key where the value should exist
        $registryPath,
        [Parameter(Mandatory=$true)]
        [string]
        # The name of the registry key
        $registryName
    )
    if (-NOT(Test-Path -Path $registryPath -PathType Container)) {
        return $false
    }
    $registryProperties = Get-ItemProperty -Path $registryPath 
    if (-NOT($registryProperties)) {
        return $false
    }
    $member = Get-Member -InputObject $registryProperties -Name $registryName
    if (-NOT[string]::IsNullOrEmpty($member)) {
        return $true
    }
    else {
        return $false
    }
}

function Get-RegistryKeyValue() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The path to the registry key where the value should exist
        $registryPath,
        [Parameter(Mandatory=$true)]
        [string]
        # The name of the registry
        $registryName
    )
    if (-NOT(Test-RegistryKeyValue -registryPath $registryPath -registryName $registryName)) {
        return $null
    }
    $registryProperties = Get-ItemProperty -Path $registryPath -Name *
    $value = $registryProperties.$registryName
    Write-Debug -Message ('[{0}@{1}: {2} -is {3}' -f $registryPath,$registryName,$value,$value.GetType())
    return $value
}
#endregion

#region Variables
# Path to the relevant area in registry
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_RESTRICT_LEGACY_JSCRIPT_PER_SECURITY_ZONE"
# All names of relevant registry keys
$registryNames = @(
    "excel.exe"
    "msaccess.exe"
    "mspub.exe"
    "onenote.exe"
    "outlook.exe"
    "powerpnt.exe"
    "visio.exe"
    "winproj.exe"
    "winword.exe"
)
#endregion

#region Execution
try {
    # Looping through each registry value to see if any changes are needed
    foreach ($name in $registryNames) {
        $getValue = Get-RegistryKeyValue -registryPath $registryPath  -registryName $name
        # Hard coding the value of 69632. No need to do anything fancy here, as this is really the value needed
        if ($getValue -ne "69632") {
            Write-Output "[Not good]. Value of registry key: $name is not as expected. Needs remediation"
            $needsRemediation = $true
            # Breaking if registry key is missing or if value is not equal to 69632
            break
        }
        else {
            $needsRemediation = $false
        }
    }
    # Exit with proper exit code, instructing Intune to potentially carry out the remediation script
    if ($needsRemediation -eq $true) {
        exit 1
    }
    elseif ($needsRemediation -eq $false) {
        Write-Output "[All good]. Values of all registry keys are as expected. Doing nothing"
        exit 0
    }
}
catch {
    Write-Output "[Not good]. Something is broken. Please investigate"
}
#endregion