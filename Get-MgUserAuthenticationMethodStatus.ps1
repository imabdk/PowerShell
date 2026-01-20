<#
.SYNOPSIS
    Reports on user MFA authentication method enrollment status using Microsoft Graph.

.DESCRIPTION
    This script checks Microsoft Entra ID users for their authentication method enrollment status,
    specifically Microsoft Authenticator and/or Passkey (FIDO2) methods. It can target specific
    groups or all enabled users, and optionally export results to CSV.

.PARAMETER ExportCsv
    Switch to enable exporting results to a CSV file.

.PARAMETER PathCsvFile
    Path where the CSV file will be saved. Defaults to $env:HomeDrive\Temp.

.PARAMETER GroupName
    One or more group names to check. Members of these groups will be evaluated.

.PARAMETER AllUsers
    Switch to check all enabled users in the tenant.

.PARAMETER CheckMethod
    Specifies which authentication method to check: 'Authenticator', 'Passkey', or 'Both'.
    Defaults to 'Authenticator'.

.EXAMPLE
    .\Get-MgUserAuthenticationMethodStatus.ps1 -GroupName "MFA Pilot Group"
    Checks Authenticator enrollment for members of the specified group.

.EXAMPLE
    .\Get-MgUserAuthenticationMethodStatus.ps1 -AllUsers -CheckMethod Both -ExportCsv
    Checks both Authenticator and Passkey enrollment for all users and exports to CSV.

.EXAMPLE
    .\Get-MgUserAuthenticationMethodStatus.ps1 -GroupName "Sales","Marketing" -CheckMethod Passkey
    Checks Passkey enrollment for members of multiple groups.

.NOTES
    Authors: Martin Bengtsson (imab.dk), Christian Frohn (christianfrohn.dk)
    Podcast: How To Get There From Here | HowToGetThereFromHere.com
    
    Required Modules:
        - Microsoft.Graph.Authentication
        - Microsoft.Graph.Users
        - Microsoft.Graph.Groups
        - Microsoft.Graph.Identity.SignIns
    
    Required Graph Permissions:
        - User.Read.All
        - UserAuthenticationMethod.Read.All
        - GroupMember.Read.All

.LINK
    https://www.imab.dk/how-to-get-there-from-here-monitor-passkey-and-phishing-resistant-mfa-user-adoption-with-powershell/
#>

[CmdletBinding()]
param (
    [parameter(Mandatory=$false)]
    [switch]$ExportCsv,
    
    [parameter(Mandatory=$false)]
    [string]$PathCsvFile = "$env:HomeDrive\Temp",
    
    [parameter(Mandatory=$false)]
    [string[]]$GroupName,
    
    [parameter(Mandatory=$false)]
    [switch]$AllUsers,
    
    [parameter(Mandatory=$false)]
    [ValidateSet('Authenticator', 'Passkey', 'Both')]
    [string]$CheckMethod = 'Authenticator'
)

# Check for required modules
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.SignIns'
)

$missingModules = @()
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        $missingModules += $module
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host "ERROR: The following required modules are not installed:" -ForegroundColor Red
    foreach ($module in $missingModules) {
        Write-Host "  - $module" -ForegroundColor Red
    }
    exit
}

# Validate parameters
if (-not $GroupName -and -not $AllUsers) {
    Write-Host "ERROR: You must specify either -GroupName or -AllUsers" -ForegroundColor Red
    exit
}
if ($GroupName -and $AllUsers) {
    Write-Host "ERROR: Cannot use both -GroupName and -AllUsers together" -ForegroundColor Red
    exit
}

# Set boolean flags for method checks (avoids repeated -in checks)
$checkAuthenticator = $CheckMethod -in 'Authenticator', 'Both'
$checkPasskey = $CheckMethod -in 'Passkey', 'Both'

# Set labels and filenames based on check method
$methodConfig = @{
    'Authenticator' = @{ Label = 'Microsoft Authenticator'; FileName = 'UserAuthenticationMethodStatus-Authenticator.csv' }
    'Passkey'       = @{ Label = 'Passkey (FIDO2)'; FileName = 'UserAuthenticationMethodStatus-Passkey.csv' }
    'Both'          = @{ Label = 'Authenticator + Passkey'; FileName = 'UserAuthenticationMethodStatus-Combined.csv' }
}
$checkingLabel = $methodConfig[$CheckMethod].Label
$csvFileName = $methodConfig[$CheckMethod].FileName

# Display banner
Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
Write-Host "  MFA Authentication Method Report" -ForegroundColor Cyan
Write-Host "  Martin Bengtsson | imab.dk" -ForegroundColor Gray
Write-Host "  Christian Frohn  | christianfrohn.dk" -ForegroundColor Gray
Write-Host ""
Write-Host "  Podcast: How To Get There From Here | HowToGetThereFromHere.com" -ForegroundColor Gray
Write-Host "$('=' * 70)`n" -ForegroundColor Cyan

try {
    Write-Host "[1/4] Connecting to Microsoft Graph..." -ForegroundColor Yellow
    # UserAuthenticationMethod.Read.All covers all authentication methods including FIDO2/Passkeys
    Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All", "GroupMember.Read.All" -NoWelcome
    Write-Host "      Successfully connected" -ForegroundColor Green

}
catch {
    Write-Host "ERROR: Failed to connect to Microsoft Graph" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}
try {
    $usersNeedingAttention = @()
    
    Write-Host "`n[2/4] Retrieving users..." -ForegroundColor Yellow
    
    # Get users based on group membership or all enabled users
    if ($GroupName) {
        $allMgUsers = @()
        foreach ($gName in $GroupName) {
            Write-Host "      Finding group: $gName..." -ForegroundColor Gray
            $group = Get-MgGroup -Filter "displayName eq '$gName'" -ConsistencyLevel eventual
            if ($group) {
                Write-Host "      Retrieving members..." -ForegroundColor Gray
                $groupMembers = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue | 
                    Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user' }
                
                foreach ($member in $groupMembers) {
                    $user = Get-MgUser -UserId $member.Id -Select Id,DisplayName,UserPrincipalName,Mail -ErrorAction SilentlyContinue
                    if ($user) {
                        $allMgUsers += $user
                    }
                }
            }
            else {
                Write-Host "      Group '$gName' not found. Skipping..." -ForegroundColor Red
            }
        }
        $allMgUsers = $allMgUsers | Sort-Object -Property Id -Unique
        Write-Host "      Total unique users found: $($allMgUsers.Count)" -ForegroundColor Green
    }
    else {
        Write-Host "      Retrieving all enabled users..." -ForegroundColor Gray
        $allMgUsers = Get-MgUser -Filter "AccountEnabled eq true" -Select Id,DisplayName,UserPrincipalName,Mail -All
        Write-Host "      Total users found: $($allMgUsers.Count)" -ForegroundColor Green
    }
    
    # Set CSV path and initialize collection
    $csvExportData = @()
    if ($ExportCsv) {
        if (-NOT(Test-Path $pathCsvFile)) { New-Item -Path $pathCsvFile -ItemType Directory -Force | Out-Null}
        $csvPath = Join-Path -Path $pathCsvFile -ChildPath $csvFileName
    }
    
    Write-Host "`n[3/4] Checking authentication methods..." -ForegroundColor Yellow
    Write-Host "      Checking: $checkingLabel`n" -ForegroundColor Gray
    
    # Display column headers based on check method
    $headerLine = "      " + "DisplayName".PadRight(30) + " " + "UPN".PadRight(40)
    if ($checkAuthenticator) { $headerLine += "Authenticator".PadRight(16) }
    if ($checkPasskey) { $headerLine += "Passkey" }
    Write-Host $headerLine -ForegroundColor Cyan
    
    # Calculate separator width based on columns
    $sepWidth = 71
    if ($checkAuthenticator) { $sepWidth += 16 }
    if ($checkPasskey) { $sepWidth += 10 }
    Write-Host "      $('-' * $sepWidth)" -ForegroundColor DarkGray
    
    $counter = 0
    foreach ($user in $allMgUsers) {
        $counter++
        Write-Progress -Activity "Checking authentication methods" -Status "Processing user $counter of $($allMgUsers.Count)" -PercentComplete (($counter / $allMgUsers.Count) * 100)
        
        # Reset variables for each user to avoid stale data
        $msAuthMethods = $null
        $passkeyMethods = $null
        
        # Check authentication methods based on selected option
        if ($checkAuthenticator) {
            $msAuthMethods = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $user.Id -ErrorAction SilentlyContinue
        }
        
        if ($checkPasskey) {
            $passkeyMethods = Get-MgUserAuthenticationFido2Method -UserId $user.Id -ErrorAction SilentlyContinue
        }
        
        # Determine enrollment status
        $hasAuthenticator = [bool]$msAuthMethods
        $hasPasskey = [bool]$passkeyMethods
        
        # Determine if user is missing required methods
        $shouldInclude = switch ($CheckMethod) {
            'Authenticator' { -not $hasAuthenticator }
            'Passkey' { -not $hasPasskey }
            'Both' { (-not $hasAuthenticator) -or (-not $hasPasskey) }
        }
        
        # Display status - name and UPN in white, Yes/No colored individually
        # Truncate long values to maintain column alignment
        $nameMaxLen = 28
        $upnMaxLen = 38
        $displayName = if ($user.DisplayName) {
            if ($user.DisplayName.Length -gt $nameMaxLen) { $user.DisplayName.Substring(0, $nameMaxLen - 3) + "..." } else { $user.DisplayName }
        } else { "(No name)" }
        $upnDisplay = if ($user.userPrincipalName.Length -gt $upnMaxLen) {
            $user.userPrincipalName.Substring(0, $upnMaxLen - 3) + "..."
        } else { $user.userPrincipalName }
        
        Write-Host "      $($displayName.PadRight(30)) $($upnDisplay.PadRight(40))" -NoNewline -ForegroundColor White
        
        if ($checkAuthenticator) {
            $authColor = if ($hasAuthenticator) { "Green" } else { "Red" }
            Write-Host $(if ($hasAuthenticator) {'Yes'} else {'No'}).PadRight(16) -NoNewline -ForegroundColor $authColor
        }
        
        if ($checkPasskey) {
            $passkeyColor = if ($hasPasskey) { "Green" } else { "Red" }
            Write-Host $(if ($hasPasskey) {'Yes'} else {'No'}) -ForegroundColor $passkeyColor
        } else {
            Write-Host
        }
        
        if ($shouldInclude) {
            $usersNeedingAttention += $user.userPrincipalName
            
            # Collect CSV data if export is enabled
            if ($ExportCsv) {
                $csvData = [ordered]@{
                    DisplayName = $user.DisplayName
                    userPrincipalName = $user.userPrincipalName
                    Mail = $user.Mail
                }
                if ($checkAuthenticator) {
                    $csvData['MicrosoftAuthenticator'] = if ($hasAuthenticator) {"Enrolled"} else {"Not enrolled"}
                }
                if ($checkPasskey) {
                    $csvData['Passkey'] = if ($hasPasskey) {"Enrolled"} else {"Not enrolled"}
                }
                $csvExportData += [PSCustomObject]$csvData
            }
        }
    }
    
    Write-Progress -Activity "Checking authentication methods" -Completed
    
    # Export all CSV data at once (more efficient than appending in loop)
    if ($ExportCsv -and $csvExportData.Count -gt 0) {
        $csvExportData | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
    }
    Write-Host
    Write-Host "[4/4] Report completed" -ForegroundColor Yellow
    
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
    Write-Host "Report generated:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    if ($GroupName) {
        $groupDisplay = if ($GroupName.Count -gt 2) {
            "$($GroupName.Count) groups ($($GroupName[0..1] -join ', '), ...)"
        } else {
            $GroupName -join ', '
        }
        Write-Host "Groups checked:        $groupDisplay" -ForegroundColor White
    } else {
        Write-Host "Scope:                 All enabled users" -ForegroundColor White
    }
    Write-Host "Method checked:        $checkingLabel" -ForegroundColor White
    Write-Host "Total users checked:   $($allMgUsers.Count)" -ForegroundColor White
    Write-Host "Users enrolled:        $($allMgUsers.Count - $usersNeedingAttention.Count)" -ForegroundColor Green
    Write-Host "Users missing method:  $($usersNeedingAttention.Count)" -ForegroundColor Red
    if ($ExportCsv) {
        Write-Host "`nCSV Report saved to: $csvPath" -ForegroundColor White
    }
    Write-Host "$('=' * 70)`n" -ForegroundColor Cyan
}
catch {
    Write-Host "`nERROR: Failed to process authentication methods" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "At line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}