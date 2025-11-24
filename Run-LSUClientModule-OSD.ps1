<#
Lenovo Driver & BIOS Update via LSUClient - ConfigMgr Task Sequence
#>

$ErrorActionPreference = 'Continue'

$companyName = "Kromann Reumert"
$regRoot     = "HKLM:\SOFTWARE\$companyName\OSDDrivers"
$maxRounds   = 2

# Logging - clean and simple
try { $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment } catch { $tsenv = $null }
$logBuffer = New-Object System.Collections.ArrayList
function Log([string]$msg) {
    $line = "[LSUClient] $msg"
    Write-Output $line
    if ($tsenv) { [void]$logBuffer.Add("$line`r`n") }
}

Log "Lenovo LSUClient update started"

# Clean registry at start of each run
if (Test-Path $regRoot) { Remove-Item $regRoot -Recurse -Force -ErrorAction Stop }
New-Item $regRoot -Force | Out-Null
Log "Registry cleaned: $regRoot"

# Lenovo check
$cs = Get-CimInstance Win32_ComputerSystemProduct
if ($cs.Vendor -notlike "*Lenovo*") { Log "Not Lenovo - skipping"; exit 0 }
Log "Lenovo detected: $($cs.Name) ($($cs.Version))"

# Module
try {
    Import-Module LSUClient -Force -ErrorAction Stop
    Log "LSUClient loaded v$((Get-Module LSUClient).Version)"
} catch {
    Log "LSUClient module missing"
    exit 0
}

# Update loop
$mandatoryReboot = $false
$regProperties = @{}
$installedUpdates = @{}  # Track updates installed during THIS run only

for ($round = 1; $round -le $maxRounds; $round++) {
    Log "Round $round of $maxRounds"

    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }

    if (-not $updates) {
        Log "No more unattended updates"
        break
    }

    # Filter out already installed updates
    $updates = $updates | Where-Object { -not $installedUpdates.ContainsKey($_.ID) }

    if (-not $updates) {
        Log "All available updates already installed in this run"
        break
    }

    Log "Processing $($updates.Count) new update(s)"

    foreach ($u in $updates) {
        Log "Installing: $($u.Title) [$($u.ID)]"

        try {
            $results = Install-LSUpdate $u

            $regProperties[$u.ID] = $u.Title
            $installedUpdates[$u.ID] = $true  # Mark as installed for subsequent rounds

            # Log the actual PendingAction value
            $pendingAction = $results.PendingAction
            Log "PendingAction: $pendingAction"

            if ($results.PendingAction -contains 'REBOOT_MANDATORY' -or $results.PendingAction -contains 'SHUTDOWN') {
                $mandatoryReboot = $true
                Log "Success - MANDATORY reboot required"
            } else {
                Log "Success"
            }
        }
        catch {
            Log "FAILED: $_"
            $regProperties["$($u.ID)_ERROR"] = "$($u.Title): $_"
            $installedUpdates[$u.ID] = $true  # Mark to avoid retry in next round
        }
    }
}

# Final registry stamps
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$regProperties["_LastRun_TS"] = $now
$regProperties["_LenovoModel"] = $cs.Name
$regProperties["_LenovoModelNumber"] = $cs.Version
$regProperties["_RebootRequired"] = $mandatoryReboot
$regProperties["_ScriptVersion"] = "2025.11.23-Optimized"

# Write all registry properties in batch
foreach ($key in $regProperties.Keys) {
    New-ItemProperty $regRoot -Name $key -Value $regProperties[$key] -Force | Out-Null
}

# Flush log buffer to TS environment
if ($tsenv -and $logBuffer.Count -gt 0) {
    $tsenv.Value("LenovoLSULog") = $logBuffer -join ''
}

Log "LSUClient finished. Mandatory reboot: $mandatoryReboot"
if ($mandatoryReboot) { exit 3010 } else { exit 0 }