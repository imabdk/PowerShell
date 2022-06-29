<#
.SYNOPSIS
    Enable UE-V with selected settings and register the local templates
    
.DESCRIPTION
    Complete script to enable User Experience Virtualization during OSD with Configuration Manager. This script is initially tailored for my needs.
    Modify to suit your needs.
    I don't sync any Windows settings nor Windows apps, as I take care of that through Enterprise State Roaming in Azure.
    I don't use any central template catalog. Instead I just enable those built into the OS that I initially need (W10 1803 by the time of writing)

.NOTES
    Filename: Enable-UEV.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson
#> 

# Enable User Experience Virtualization
try {
    Enable-Uev
}

catch [System.Exception] {
    Write-Warning -Message $_.Exception.Message ; break
}

# Set variables
$UEVStatus = Get-UevStatus
$TemplateDir = "$env:ALLUSERSPROFILE\Microsoft\UEV\InboxTemplates\"
$TemplateArray = "DesktopSettings2013.xml","MicrosoftNotepad.xml","MicrosoftOffice2016Win32.xml","MicrosoftOffice2016Win64.xml","MicrosoftOutlook2016CAWin32.xml","MicrosoftOutlook2016CAWin64.xml","MicrosoftSkypeForBusiness2016Win32.xml","MicrosoftSkypeForBusiness2016Win64.xml","MicrosoftWordpad.xml"

# Configure UEV
if ($UEVStatus.UevEnabled -eq "True") {
    
    # Set sync to wait for logon and start of applications
    Set-UevConfiguration -Computer -EnableWaitForSyncOnApplicationStart -EnableWaitForSyncOnLogon
    
    # Set SyncMethod to External - for use with OneDrive
    Set-UevConfiguration -Computer -SyncMethod External

    # Set the Storagepath to OneDrive
    Set-UevConfiguration -Computer -SettingsStoragePath %OneDrive%

    # Do not synchronize any Windows apps settings for all users on the computer.
    Set-UevConfiguration -Computer -EnableDontSyncWindows8AppSettings

    # Do not display notification the first time that the service runs for all users on the computer.
    Set-UevConfiguration -Computer -DisableFirstUseNotification
    
    # Do not sync any Windows apps for all users on the computer
    Set-UevConfiguration -Computer -DisableSyncUnlistedWindows8Apps
            
    foreach ($Template in $TemplateArray) {
    
        try {
            # Register local UE-v templates
            Register-UevTemplate -LiteralPath $TemplateDir\$Template
        }
        catch [System.Exception]
            {
            Write-Warning -Message $_.Exception.Message ; break
        }
    }
}
