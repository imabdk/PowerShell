<#
.SYNOPSIS
    This script will configure all the specific registry keys within the configured path, to the set value
    
    This is currently tailored directly towards replacing the GPO: MSFT Microsoft 365 Apps v2206 - Legacy JScript Block - Computer
    With a few adjustments, this can be used to configure any registry key and value

.DESCRIPTION
    Same as above

.NOTES
    Filename: Configure-Legacy-JScript-Registry.ps1
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
        # The path to the registry key where the value should exist
        [string]$registryPath,
        [Parameter(Mandatory=$true)]
        # The name of the registry key
        [string]$registryName
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

function Remove-RegistryKeyValue() {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        # The path to the registry key where the value should be removed
        [string]$registryPath,        
        [Parameter(Mandatory=$true)]
        # The name of the value to remove
        [string]$registryName
    )
    if ((Test-RegistryKeyValue -Path $registryPath -Name $registryName)) {
        if ($pscmdlet.ShouldProcess(('Item: {0} Property: {1}' -f $registryPath,$registryName),'Remove Property')) {
            Remove-ItemProperty -Path $removePath -Name $removeName
        }
    }
}

function Install-RegistryKey() {
    [CmdletBinding(SupportsShouldPRocess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        # The path to the registry key to create
        [string]$registryPath
    )
    if (-NOT(Test-Path -Path $registryPath -PathType Container)) {
        New-Item -Path $registryPath -ItemType RegistryKey -Force | Out-String | Write-Verbose
    }
}

function Set-RegistryKeyValue() {
    [CmdletBinding(SupportsShouldPRocess=$true,DefaultParameterSetName='String')]
    param(
        [Parameter(Mandatory=$true)]
        # The path to the registry key where the value should be set. Will be created if it doesn't exist.
        [string]$registryPath,
        [Parameter(Mandatory=$true)]
        # The name of the value being set.
        [string]$registryName,
        [Parameter(Mandatory=$true,ParameterSetName='String')]
        [AllowEmptyString()]
        [AllowNull()]
        # The value's data. Creates a value for holding string data (i.e. `REG_SZ`). If `$null`, the value will be saved as an empty string.
        [string]$String,
        [Parameter(ParameterSetName='String')]
        # The string should be expanded when retrieved. Creates a value for holding expanded string data (i.e. `REG_EXPAND_SZ`).
        [Switch]$Expand,
        [Parameter(Mandatory=$true,ParameterSetName='Binary')]
        # The value's data. Creates a value for holding binary data (i.e. `REG_BINARY`).
        [byte[]]$Binary,
        [Parameter(Mandatory=$true,ParameterSetName='DWord')]
        # The value's data. Creates a value for holding a 32-bit integer (i.e. `REG_DWORD`).
        [int]$DWord,
        [Parameter(Mandatory=$true,ParameterSetName='DWordAsUnsignedInt')]
        # The value's data as an unsigned integer (i.e. `UInt32`). Creates a value for holding a 32-bit integer (i.e. `REG_DWORD`).
        [uint32]$UDWord,
        [Parameter(Mandatory=$true,ParameterSetName='QWord')]
        # The value's data. Creates a value for holding a 64-bit integer (i.e. `REG_QWORD`).
        [long]$QWord,
        [Parameter(Mandatory=$true,ParameterSetName='QWordAsUnsignedInt')]
        # The value's data as an unsigned long (i.e. `UInt64`). Creates a value for holding a 64-bit integer (i.e. `REG_QWORD`).
        [uint64]$UQWord,
        [Parameter(Mandatory=$true,ParameterSetName='MultiString')]
        # The value's data. Creates a value for holding an array of strings (i.e. `REG_MULTI_SZ`).
        [string[]]$Strings,
        # Removes and re-creates the value. Useful for changing a value's type.
        [Switch]$Force
    )

    $value = $null
    $type = $pscmdlet.ParameterSetName
    switch -Exact ($pscmdlet.ParameterSetName) {
        'String' { 
            $value = $String 
            if ($Expand) {
                $type = 'ExpandString'
            }
        }
        'Binary' { $value = $Binary }
        'DWord' { $value = $DWord }
        'QWord' { $value = $QWord }
        'DWordAsUnsignedInt' { 
            $value = $UDWord 
            $type = 'DWord'
        }
        'QWordAsUnsignedInt' { 
            $value = $UQWord 
            $type = 'QWord'
        }
        'MultiString' { $value = $Strings }
    }
    
    Install-RegistryKey -registryPath $registryPath
    
    if ($Force) {
        Remove-RegistryKeyValue -registryPath $registryPath -registryName $Name
    }

    if (Test-RegistryKeyValue -registryPath $registryPath -registryName $Name) {
        $currentValue = Get-RegistryKeyValue -registryPath $registryPath -registryName $Name
        if ($currentValue -ne $value) {
            Write-Verbose -Message ("[{0}@{1}] {2} -> {3}'" -f $registryPath,$registryName,$currentValue,$value)
            Set-ItemProperty -Path $registryPath -Name $registryName -Value $value
        }
    }
    else {
        Write-Verbose -Message ("[{0}@{1}] -> {2}'" -f $registryPath,$registryName,$value)
        $null = New-ItemProperty -Path $registryPath -Name $registryName -Value $value -PropertyType $type
    }
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
    # Looping through each registry value- This means all registry keys are being configured to the set value
    foreach ($name in $registryNames) {
        Set-RegistryKeyValue -registryPath $registryPath -registryName $name -DWord 69632
    }
    Write-Output "[All good]. Registry keys has been configured to the set value"
    exit 0
}
catch {
    Write-Output "[Not good]. Something went wrong when trying to configure the registry keys. Please investigate"
    exit 1
}
#endregion