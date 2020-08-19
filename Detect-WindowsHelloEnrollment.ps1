<#
.SYNOPSIS
    Script will detect if the logged on user is using the PIN credential provider indicating that the user is making use of Windows Hello for Business
   
.DESCRIPTION
    Script will detect if the logged on user is using the PIN credential provider indicating that the user is making use of Windows Hello for Business.
    If the logged on user is not making use of the PIN credential provider, the script will exit with error 1.
    This will signal an error to Endpoint Analytics Proactive Remediations


.NOTES
    Filename: Detect-WindowsHelloEnrollment.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#> 

# Getting the logged on user's SID
$loggedOnUserSID = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
# Registry path for the PIN credential provider
$credentialProvider = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"
if (Test-Path -Path $credentialProvider) {
    $userSIDs = Get-ChildItem -Path $credentialProvider
    $items = $userSIDs | Foreach-Object { Get-ItemProperty $_.PsPath }
}
else {
    Write-Output "Registry path for PIN credential provider not found. Exiting script with status 1"
    exit 1
}
if(-NOT[string]::IsNullOrEmpty($loggedOnUserSID)) {
    # If multiple SID's are found in registry, look for the SID belonging to the logged on user
    if ($items.GetType().IsArray) {
        # LogonCredsAvailable needs to be set to 1, indicating that the credential provider is in use
        if ($items.Where({$_.PSChildName -eq $loggedOnUserSID}).LogonCredsAvailable -eq 1) {
            Write-Output "[Multiple SIDs]: All good. PIN credential provider found for LoggedOnUserSID. This indicates that user is enrolled into WHfB."
            exit 0                    
        }
        # If LogonCredsAvailable is not set to 1, this will indicate that the PIN credential provider is not in use
        elseif ($items.Where({$_.PSChildName -eq $loggedOnUserSID}).LogonCredsAvailable -ne 1) {
            Write-Output "[Multiple SIDs]: Not good. PIN credential provider NOT found for LoggedOnUserSID. This indicates that the user is not enrolled into WHfB."
            exit 1
        }
        else {
            Write-Output "[Multiple SIDs]: Something is not right about the LoggedOnUserSID and the PIN credential provider. Needs investigation."
            exit 1
        }
    }
    # Looking for the SID belonging to the logged on user is slightly different if there's not mulitple SIDs found in registry
    else {
        if (($items.PSChildName -eq $loggedOnUserSID) -AND ($items.LogonCredsAvailable -eq 1)) {
            Write-Output "[Single SID]: All good. PIN credential provider found for LoggedOnUserSID. This indicates that user is enrolled into WHfB."
            exit 0                    
        }
        elseif (($items.PSChildName -eq $loggedOnUserSID) -AND ($items.LogonCredsAvailable -ne 1)) {
            Write-Output "[Single SID]: Not good. PIN credential provider NOT found for LoggedOnUserSID. This indicates that the user is not enrolled into WHfB."
            exit 1
        }
        else {
            Write-Output "[Single SID]: Something is not right about the LoggedOnUserSID and the PIN credential provider. Needs investigation."
            exit 1
        }
    }
}
else {
    Write-Output "Could not retrieve SID for the logged on user. Exiting script with status 1"
    exit 1
}
