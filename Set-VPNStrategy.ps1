<#
.SYNOPSIS
    This script reads the current AlwaysOn VPN strategy and changes it to the set value if required.
   
.DESCRIPTION
    This script reads the current AlwaysOn VPN strategy and changes it to the set value if required.
    This is to cater for situation where Windows 10 automatically changes the VPN strategy to something undesirable.

    Intune currently only supports setting the connection type to either IKEv2, L2TP, PPT or automatic. 
    If you want a different strategy, you will need to use a script like this.

.PARAMETER strategyNumber
    Specify the desired VPN strategy by number. The options are:

    5 = Only SSTP is attempted
    6 = SSTP is attempted first
    7 = Only IKEv2 is attempted
    8 = IKEv2 is attempted first
    14 = IKEv2 is attempted followed by SSTP

.NOTES
    Filename: Set-VPNStrategy.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

#> 

[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("5","6","7","8","14")]
    [string]$strategyNumber
)

function Get-VPNStrategy() {
    
    switch ($strategyNumber) {
        5 {$strategyDesc = "Only SSTP is attempted"}
        6 {$strategyDesc = "SSTP is attempted first"}
        7 {$strategyDesc = "Only IKEv2 is attempted"}
        8 {$strategyDesc = "IKEv2 is attempted first"}
        14 {$strategyDesc = "IKEv2 is attempted followed by SSTP"}
    }
    
    $rasphonePath = "$env:APPDATA\Microsoft\Network\Connections\Pbk\rasphone.pbk"

    if (Test-Path $rasphonePath) {
        try {
            $currentStrategy = (Get-Content $rasphonePath) -like "VpnStrategy=*"
        }
        catch { }
    }
    else {
        Write-Verbose -Verbose -Message "The path for rasphone.pbk does not exist"
    }
    Write-Output $currentStrategy
}

function Set-VPNStrategy() {

    switch ($strategyNumber) {
        5 {$strategyDesc = "Only SSTP is attempted"}
        6 {$strategyDesc = "SSTP is attempted first"}
        7 {$strategyDesc = "Only IKEv2 is attempted"}
        8 {$strategyDesc = "IKEv2 is attempted first"}
        14 {$strategyDesc = "IKEv2 is attempted followed by SSTP"}
    }

    $rasphonePath = "$env:APPDATA\Microsoft\Network\Connections\Pbk\rasphone.pbk"
    $currentStrategy = Get-VPNStrategy
    $newStrategy = "VpnStrategy=$strategyNumber"

    if ($currentStrategy) {
        if ($currentStrategy -ne $newStrategy) {
            try {
                (Get-Content $rasphonePath).Replace($currentStrategy,$newStrategy) | Set-Content $rasphonePath
                Write-Verbose -Verbose -Message "VPN strategy is now configured to: $newStrategy"
                Write-Verbose -Verbose -Message "The VPN strategy description is: $strategyDesc"
            }
            catch { 
                Write-Verbose -Verbose -Message "Failed to apply new VPN strategy"
            }
        }
        elseif ($currentStrategy -eq $newStrategy) {

            Write-Verbose -Verbose -Message "VPN strategy is already properly configured to: $currentStrategy"
            Write-Verbose -Verbose -Message "The VPN strategy description is: $strategyDesc"
        }
    }
}

try {
    Write-Verbose -Verbose -Message "Script is running"
    Set-VPNStrategy
}

catch {
    Write-Verbose -Verbose -Message "Something went wrong during running of the script"
}

finally {
    Write-Verbose -Verbose -Message "Script is done running"
}
