<#
.SYNOPSIS
    Detect and remove desktop shortcuts using Proactive Remediations in Microft Endpoint Manager. 
   
.DESCRIPTION
    Detect and remove desktop shortcuts using Proactive Remediations in Microft Endpoint Manager.
    Shortcuts on All Users desktop (public desktop) or the current user's desktop can be detected and removed.

.NOTES
    Filename: Detection-DeleteShortcuts.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://imab.dk/remove-desktop-shortcuts-for-the-current-user-and-public-profile-using-powershell-and-proactive-remediations
#>

#region Functions
#Getting the current user's username by querying the explorer.exe process
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
#Getting the current user's SID by using the user's username
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
#Getting the current user's desktop path by querying registry with the user's SID
function Get-CurrentUserDesktop([string]$fUserRegistryPath) {
    try {
        if (Test-Path -Path $fUserRegistryPath) {
            $currentUserDesktop = (Get-ItemProperty -Path $fUserRegistryPath -Name Desktop -ErrorAction Ignore).Desktop
        }
    }
    catch {
        Write-Output "Failed to get current user's desktop"
    }
    if (-NOT[string]::IsNullOrEmpty($currentUserDesktop)) {
        Write-Output $currentUserDesktop
    }   
}
#endregion
#region Execution
try {
    #Edit here with names of the shortcuts you want removed
    $shortCutNames = @(
        "*Google Chrome*"
        "*compareDocs*"
        "*pdfDocs*"
        "*Microsoft Edge*"
        "*Microsoft Teams*"
    )
    #Create empty array for shortcutsFound
    $shortcutsFound = @()
    #Retrieving current user and current user's SID
    $currentUser = Get-CurrentUser
    $currentUserSID = Get-UserSID $currentUser
    # Getting the AllUsers desktop path
    $allUsersDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
    $userRegistryPath = "Registry::HKEY_USERS\$($currentUserSID)\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    $currentUserDesktop = Get-CurrentUserDesktop $userRegistryPath

    if (Test-Path -Path $allUsersDesktop) {
        foreach ($ShortcutName in $shortCutNames) {
           $shortCutsFound += Get-ChildItem -Path $allUsersDesktop -Filter *.lnk | Where-Object {$_.Name -like $shortCutName}
        }
    }
    if (Test-Path -Path $currentUserDesktop) {
        foreach ($ShortcutName in $shortCutNames) {
           $shortCutsFound += Get-ChildItem -Path $currentUserDesktop -Filter *.lnk | Where-Object {$_.Name -like $shortCutName}
        }
    }
    if (-NOT[string]::IsNullOrEmpty($shortcutsFound)) {
        Write-Output "Desktop shortcuts found. Returning True"
        $shortcutsFoundStatus = $true

    }
    elseif ([string]::IsNullOrEmpty($shortcutsFound)) {
        Write-Output "Desktop shortcuts NOT found. Returning False"
        $shortcutsFoundStatus = $false
    }
}
catch { 
    Write-Output "Something went wrong during running of the script. Variable values are: $currentUser,$currentUserSID,$allUsersDesktop,$currentUserDesktop"
}

finally { 
    if ($shortcutsFoundStatus -eq $true) {
        Write-Output "shortcutsFoundStatus equals True. Exiting with 1"
        exit 1
    }
    elseif ($shortcutsFoundStatus -eq $false) {
        Write-Output "shortcutsFoundStatus equals False. Exiting with 0"
        exit 0  
    }
}
#endregion