<#
.SYNOPSIS
    Modify registry for the CURRENT user coming from SYSTEM context
 
.DESCRIPTION
    Same as above

.NOTES
    Filename: Edit-HKCURegistryFromSystem.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/back-to-basics-modifying-registry-for-the-current-user-coming-from-system-context    
#> 
function Get-CurrentUser() {
    try { 
        $currentUser = (Get-Process -IncludeUserName -Name explorer | Select-Object -First 1 | Select-Object -ExpandProperty UserName).Split("\")[1] 
    } 
    catch { 
        Write-Output "Failed to get current user." 
    }
    if (-NOT[string]::IsNullOrEmpty($currentUser)) {
        Write-Output $currentUser
    }
}
function Get-UserSID([string]$fCurrentUser) {
    try {
        $user = New-Object System.Security.Principal.NTAccount($fcurrentUser) 
        $sid = $user.Translate([System.Security.Principal.SecurityIdentifier]) 
    }
    catch { 
        Write-Output "Failed to get current user SID."   
    }
    if (-NOT[string]::IsNullOrEmpty($sid)) {
        Write-Output $sid.Value
    }
}
$currentUser = Get-CurrentUser
$currentUserSID = Get-UserSID $currentUser
$userRegistryPath = "Registry::HKEY_USERS\$($currentUserSID)\SOFTWARE\Policies\Microsoft\office\16.0\outlook\cached mode"
New-ItemProperty -Path $userRegistryPath -Name "Enabled" -Value 0 -PropertyType DWORD -Force | Out-Null