<#
.SYNOPSIS
    Ensure membership compliance on Active Directory groups.
    Also capable of disabling users during the compliance check.

.DESCRIPTION
    This script is specifically tailored towards my own needs, where I reserve an extensionattribute for the purpose of defining a role.
    Take this script and use it as inspiration towards your own requirements.

.NOTES
    Filename: iAM-Compliance-Domain-Admins.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

#> 
# Load AD module (RSAT is required for this to load)
if (Get-Module -Name ActiveDirectory -ListAvailable) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Verbose -Message "Successfully imported ActiveDirectory module" -Verbose
    } 
    catch {
        Write-Error "ActiveDirectory module failed to import."
    }
}
elseif (-NOT(Get-Module -Name ActiveDirectory -ListAvailable)) {
    break  
}
# Create functions
# This function gets the content of the allocated extensionattribute
function Get-iAMRole() {
    [CmdletBinding()]
    param (
        [string]$SamAccountName
    )
    $iAMResult = 
    try {
        # Getting user object
        (Get-ADUser -Identity $SamAccountName -Properties extensionAttribute2 -ErrorAction SilentlyContinue | Select-Object extensionAttribute2).extensionAttribute2
    } 
    catch {
        # Otherwise assuming computer object
        (Get-ADComputer -Identity $SamAccountName -Properties extensionAttribute2 -ErrorAction SilentlyContinue | Select-Object extensionAttribute2).extensionAttribute2
    }
    # This dictates that the iAM roles are separated with ";" on the extensionattribute in AD
    if (-NOT[string]::IsNullOrEmpty($iAMResult)) {
         $iAMResult = $iAMResult -split ";"
         Write-Output $iAMResult
    }
    else {
        Write-Output "null"
    }
}
# This function queries AD within the specified OU with a filter for users with the specified iAM role
function Get-UsersWithiAMRole() {
    [CmdletBinding()]
    param (
        [string]$iAMRole,
        [string]$OU
    )
    $getUsers = (Get-ADUser -SearchBase $OU -SearchScope Subtree -Filter "extensionattribute2 -like '*$($iAMRole)*'" -Properties extensionAttribute2 | Select-Object SamAccountName).SamAccountName
    Write-Output $getUsers
}
# Variables
$iAMGroup = "Domain Admins"
$iAMRole = "iAM-Domain-Admin"
$iAMGroupMembers = Get-ADGroupMember -Identity $iAMGroup
$iAMRoleUsers = Get-UsersWithiAMRole -iAMRole $iAMRole -OU "DistinguishedName for Domain Admins" # Replace with your own
# Removing and potentially disabling user accounts who does not belong to the membership of group
foreach ($member in $iAMGroupMembers) {
    $getiAMRole = Get-iAMRole -SamAccountName $member.SamAccountName
    if ($getiAMRole -notcontains $iAMRole) {
        Write-Verbose -Message "Trying to remove and disable $($member.SamAccountName)" -Verbose
        try {
            #Remove-ADGroupMember -Identity $iAMGroup -Member $member.SamAccountName -Confirm:$false
            #Disable-ADAccount -Identity $member.SamAccountName -Confirm:$false
        }
        catch { 
            Write-Verbose -Message "Removing or disabling $($member.SamAccountName) failed" -Verbose
        }
    }
    else {
        Write-Verbose -Message "Doing nothing! Object: $($member.SamAccountName) - iAMrole(s): $getiAMRole" -Verbose
    }
}
# Adding user accounts who do belong to the membership of group
# AD is queried within a sub OU for users who has $iAMRole noted in the relevant extensionattribute
foreach ($member in $iAMRoleUsers) {
    $userMemberOf = Get-ADPrincipalGroupMembership -Identity $member | Select-Object Name
    # If the user is not already a member of the group, add user to group
    if ($userMemberOf.Name -notcontains $iAMGroup) {
        Write-Verbose -Message "Adding $member as member to $iAMGroup" -Verbose
        try {
            #Add-ADGroupMember -Identity $iAMGroup -Members $member -Confirm:$false
        }
        catch {
            Write-Verbose -Message "Adding back $member failed" -Verbose
        }
    }
}