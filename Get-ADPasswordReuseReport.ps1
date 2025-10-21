<#
.SYNOPSIS
    Generates a password reuse report for Active Directory by analyzing offline database for shared password hashes.

.DESCRIPTION
    Get-ADPasswordReuseReport analyzes an offline Active Directory database (ntds.dit) to extract NTLM hashes
    and identify accounts sharing the same password - a common security vulnerability. 
    
    The script operates in two modes:
    - Targeted: Queries specific accounts or patterns (faster, recommended for routine checks)
    - All: Scans entire database (comprehensive but slower)
    
    Wildcard patterns are supported in Targeted mode (e.g., '*admin*' matches all accounts 
    containing 'admin'). When wildcards are detected, the script retrieves all accounts and 
    filters them accordingly.
    
    Results include account names, enabled/disabled status, and groups accounts by shared hash 
    values for easy identification of password reuse.

.PARAMETER Mode
    'Targeted' - Query specific accounts only (default, faster)
    'All' - Scan all accounts in the database (slower, more comprehensive)

.PARAMETER TargetAccounts
    Array of account names or patterns to query when using Targeted mode.
    Supports wildcards (e.g., '*admin*').
    Default includes common administrative accounts and specific user accounts.

.EXAMPLE
    .\Get-ADPasswordReuseReport.ps1
    Runs in Targeted mode with default account list (includes *admin* wildcard and specific users).

.EXAMPLE
    .\Get-ADPasswordReuseReport.ps1 -Mode Targeted -TargetAccounts @('Administrator', '*svc*', 'krbtgt')
    Queries specific accounts: Administrator, all accounts containing 'svc', and krbtgt.

.EXAMPLE
    .\Get-ADPasswordReuseReport.ps1 -Mode All
    Scans all accounts in the database for shared password hashes.

.OUTPUTS
    Text file at C:\Temp\ntds\SharedPasswordHashes.txt containing:
    - Analysis summary (timestamp, mode, account counts)
    - Grouped accounts by shared hash
    - Account status (enabled/disabled)

.NOTES
    Author: Martin Bengtsson
    Blog: https://www.imab.dk
    Requires DSInternals module (Install-Module DSInternals)
    Run in an elevated PowerShell session
    Requires offline copies of ntds.dit and SYSTEM registry hive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Targeted', 'All')]
    [string]$Mode = 'Targeted',

    [Parameter(Mandatory=$false)]
    [string[]]$TargetAccounts = @(
        '*admin*', 
        'MAB', 
        'CFP', 
        'MOEH', 
        'IKAS', 
        'KKL', 
        'JBRA', 
        'JEBO', 
        'OMKA', 
        'ALSI', 
        'JIK', 
        'OLLJ', 
        'MSD', 
        'JBS', 
        'RAHA', 
        'ZAAK'
    )
)

# Import DSInternals module
Import-Module DSInternals -ErrorAction Stop

# Define paths
$DatabasePath = 'C:\Temp\ntds\Active Directory\ntds.dit'
$SystemHivePath = 'C:\Temp\ntds\registry\SYSTEM'
$OutputPath = 'C:\Temp\ntds\SharedPasswordHashes.txt'

try {
    # Verify files exist
    if (-not (Test-Path $DatabasePath)) { throw "NTDS file not found at $DatabasePath" }
    if (-not (Test-Path $SystemHivePath)) { throw "SYSTEM hive not found at $SystemHivePath" }

    Write-Host "Extracting boot key from SYSTEM hive..." -ForegroundColor Cyan
    # Extract the boot key from SYSTEM hive
    $BootKey = Get-BootKey -SystemHivePath $SystemHivePath -ErrorAction Stop

    # Initialize an array to store all accounts
    $AllAccounts = @()

    if ($Mode -eq 'Targeted') {
        Write-Host "Running in TARGETED mode..." -ForegroundColor Cyan
        Write-Host "Querying specific accounts: $($TargetAccounts -join ', ')" -ForegroundColor Yellow
        
        # First, get all accounts if we have wildcards, otherwise query specific accounts
        $HasWildcards = $TargetAccounts | Where-Object { $_ -match '\*' }
        
        if ($HasWildcards) {
            Write-Host "  Wildcards detected, retrieving all accounts for filtering..." -ForegroundColor Yellow
            $AllDbAccounts = Get-ADDBAccount -All -DatabasePath $DatabasePath -BootKey $BootKey -Properties Secrets
            Write-Host "  Retrieved $($AllDbAccounts.Count) total accounts" -ForegroundColor Green
            
            # Filter accounts based on patterns
            foreach ($AccountPattern in $TargetAccounts) {
                Write-Host "  Filtering for pattern: $AccountPattern" -ForegroundColor Gray
                $MatchedAccounts = $AllDbAccounts | Where-Object { $_.SamAccountName -like $AccountPattern }
                if ($MatchedAccounts) {
                    $AllAccounts += $MatchedAccounts
                    $Count = @($MatchedAccounts).Count
                    Write-Host "    Found: $Count account(s)" -ForegroundColor Green
                }
                else {
                    Write-Host "    No matches found" -ForegroundColor DarkGray
                }
            }
        }
        else {
            # No wildcards, query specific accounts directly
            foreach ($AccountName in $TargetAccounts) {
                Write-Host "  Querying: $AccountName" -ForegroundColor Gray
                try {
                    $Account = Get-ADDBAccount -DatabasePath $DatabasePath -BootKey $BootKey `
                                              -SamAccountName $AccountName `
                                              -Properties Secrets -ErrorAction Stop
                    if ($Account) {
                        $AllAccounts += $Account
                        Write-Host "    Found: 1 account" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "    Not found" -ForegroundColor DarkGray
                }
            }
        }
    }
    elseif ($Mode -eq 'All') {
        Write-Host "Running in ALL mode..." -ForegroundColor Cyan
        Write-Host "Retrieving ALL accounts from database (this may take a while)..." -ForegroundColor Yellow
        
        # Get all accounts from the database
        $AllAccounts = Get-ADDBAccount -All -DatabasePath $DatabasePath -BootKey $BootKey -Properties Secrets
        
        Write-Host "  Retrieved: $($AllAccounts.Count) total account(s)" -ForegroundColor Green
    }

    # Check if any accounts were found
    if (-not $AllAccounts -or $AllAccounts.Count -eq 0) {
        Write-Warning "No accounts found with the specified criteria"
        return
    }

    Write-Host "`nProcessing $($AllAccounts.Count) account(s)..." -ForegroundColor Cyan

    # Remove duplicates (in case same account matched multiple patterns)
    $UniqueAccounts = $AllAccounts | Sort-Object -Property SamAccountName -Unique

    Write-Host "Unique accounts: $($UniqueAccounts.Count)" -ForegroundColor Green

    # Convert NTHash to hex, group by hash, filter for groups with multiple accounts, sort by hash, then by SamAccountName
    Write-Host "`nAnalyzing for shared password hashes..." -ForegroundColor Cyan
    
    $GroupedAccounts = $UniqueAccounts | Where-Object { $_.NTHash } | 
                      Select-Object SamAccountName, Enabled, 
                                    @{Name='NTHashHex';Expression={[System.BitConverter]::ToString($_.NTHash).Replace('-','').ToLower()}} |
                      Group-Object -Property NTHashHex | 
                      Where-Object { $_.Count -gt 1 } | 
                      Sort-Object -Property Name

    # Check if any shared hashes were found
    if (-not $GroupedAccounts) {
        Write-Warning "No accounts share identical NTLM hashes"
        return
    }

    # Build output with grouping
    $OutputLines = @()
    $OutputLines += "=" * 80
    $OutputLines += "SHARED PASSWORD ANALYSIS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $OutputLines += "Mode: $Mode"
    $OutputLines += "Total Accounts Analyzed: $($UniqueAccounts.Count)"
    $OutputLines += "Accounts with Shared Passwords: $($GroupedAccounts | ForEach-Object { $_.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum)"
    $OutputLines += "=" * 80
    $OutputLines += ""

    foreach ($Group in $GroupedAccounts) {
        $OutputLines += "$($Group.Count) users sharing hash: $($Group.Name)"
        foreach ($Account in ($Group.Group | Sort-Object -Property SamAccountName)) {
            $EnabledStatus = if ($Account.Enabled) { "[ENABLED]" } else { "[DISABLED]"}
            $OutputLines += "  - $($Account.SamAccountName) $EnabledStatus"
        }
        $OutputLines += ""
    }

    # Export to file
    $OutputLines | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

    Write-Host "`n" + ("=" * 80) -ForegroundColor Green
    Write-Host "ANALYSIS COMPLETE" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Green
    Write-Host "Output saved to: $OutputPath" -ForegroundColor Cyan
    Write-Host "Total accounts analyzed: $($UniqueAccounts.Count)" -ForegroundColor Yellow
    Write-Host "Accounts with shared passwords: $($GroupedAccounts | ForEach-Object { $_.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum)" -ForegroundColor Yellow
    Write-Host "Number of shared password groups: $($GroupedAccounts.Count)" -ForegroundColor Yellow
    
    # Display summary
    Write-Host "`nShared Password Groups:" -ForegroundColor Cyan
    foreach ($Group in $GroupedAccounts) {
        Write-Host "  $($Group.Count) accounts share hash: $($Group.Name.Substring(0, 16))..." -ForegroundColor Gray
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Error $_.Exception.StackTrace
}