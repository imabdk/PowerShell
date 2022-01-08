<#
.SYNOPSIS
    This script queries the registry in the context of the logged on user. 
    It queries a specific registry value, to determine if a PIN provider is added for the user in question.
    Using a PIN provider is the minimum required in order to use Windows Hello for Business
      
.DESCRIPTION
    Same as above

.NOTES
    Filename: Get-WindowsHelloStatus.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/use-custom-compliance-settings-in-microsoft-intune-to-require-windows-hello-enrollment
    
#> 

function Get-WindowsHelloStatus() {
    # Get currently logged on user's SID
    $currentUserSID = (whoami /user /fo csv | convertfrom-csv).SID
    # Registry path to credential provider belonging for the PIN. A PIN is required with Windows Hello
    $credentialProvider = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"
    if (Test-Path -Path $credentialProvider) {
        $userSIDs = Get-ChildItem -Path $credentialProvider
        $registryItems = $userSIDs | Foreach-Object { Get-ItemProperty $_.PsPath }
    }
    else {
        Write-Output "Not able to determine Windows Hello enrollment status"
        Exit 1
    }
    if(-NOT[string]::IsNullOrEmpty($currentUserSID)) {
        # If multiple SID's are found in registry, look for the SID belonging to the logged on user
        if ($registryItems.GetType().IsArray) {
            # LogonCredsAvailable needs to be set to 1, indicating that the PIN credential provider is in use
            if ($registryItems.Where({$_.PSChildName -eq $currentUserSID}).LogonCredsAvailable -eq 1) {
                Write-Output "ENROLLED"    
            }
            else {
                Write-Output "NOTENROLLED" 
            }
        }
        else {
            if (($registryItems.PSChildName -eq $currentUserSID) -AND ($registryItems.LogonCredsAvailable -eq 1)) {
                Write-Output "ENROLLED"      
            }
            else {
                Write-Output "NOTENROLLED"
            } 
        }
    }
    else {
        Write-Output "Not able to determine Windows Hello enrollment status"
        Exit 1
    }
}
# Return Windows Hello status to Intune in JSON format
$WHfB = Get-WindowsHelloStatus
$hash = @{EnrollmentStatus = $WHfB}
return $hash | ConvertTo-Json -Compress