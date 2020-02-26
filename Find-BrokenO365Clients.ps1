<#
.SYNOPSIS
    Find devices affected by issue described in KB4532996: https://support.microsoft.com/en-us/help/4532996/office-365-version-1910-updates-in-configmgr-do-not-download-or-apply
  
.DESCRIPTION
    Script loops through CMBitsManager.log and searches for entries which matches the issue described in KB4532966. If the script finds the log entry which is associated with the issue, the script returns NON-COMPLIANT.
    This is intended to be used with a configuration item/baseline in ConfigMgr.

.NOTES
    Filename: Find-BrokenO365Clients.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson
#> 

function Get-CCMLogDirectory {
    $ccmLogDir = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\CCM\Logging\@Global').LogDirectory
    if ($ccmLogDir -eq $null) { 
        $ccmLogDir = "$env:SystemDrive\windows\ccm\Logs" 
    }
    Write-Output $ccmLogDir
}

function Search-CMLogFile {
    param(
        [Parameter(Mandatory=$true)]$LogFile,
        [Parameter(Mandatory=$true)][String[]]$SearchString,
        [datetime]$StartTime = [datetime]::MinValue
    )

    $LogData = Get-Content $LogFile -ErrorAction SilentlyContinue

    if ($LogData) {
 
        :loop for ($i=($LogData.Count - 1);$i -ge 0; $i--) {

            try {
                $LogData[$i] -match '\<\!\[LOG\[(?<Message>.*)?\]LOG\]\!\>\<time=\"(?<Time>.+)(?<TZAdjust>[+|-])(?<TZOffset>\d{2,3})\"\s+date=\"(?<Date>.+)?\"\s+component=\"(?<Component>.+)?\"\s+context="(?<Context>.*)?\"\s+type=\"(?<Type>\d)?\"\s+thread=\"(?<TID>\d+)?\"\s+file=\"(?<Reference>.+)?\"\>' | Out-Null
                $LogTime = [datetime]::ParseExact($("$($matches.date) $($matches.time)"),"MM-dd-yyyy HH:mm:ss.fff", $null)
                $LogMessage = $matches.message
            }
            catch {
                Write-Warning "Could not parse the line $($i) in '$($LogFile)': $($LogData[$i])"
			    continue
            }

            if ($LogTime -lt $StartTime) {
                Write-Verbose -Verbose -Message "No log lines in $($LogFile) matched $($SearchString) before $($StartTime)."
                break loop
            }

            foreach ($String in $SearchString){
                if ($LogMessage -match $String) {
				    Write-Output $LogData[$i]
				    break loop
			    }
            }
        }
    }
    else {
        Write-Warning "No content from $LogFile retrieved"
    }
}

$localCulture = Get-Culture
$regionDateFormat = [System.Globalization.CultureInfo]::GetCultureInfo($LocalCulture.LCID).DateTimeFormat.LongDateTimePattern
$dateEnd = Get-Date -f $RegionDateFormat
$dateStart = $dateEnd.AddDays(-3)
$ccmLogDir = Get-CCMLogDirectory
$ccmLogName = "CMBITSManager.log"
$errorReason = "RemoteURL should be in this format - cmbits"

$updatesBroken = Search-CMLogFile -LogFile "$ccmLogDir\$ccmLogName" -SearchString $errorReason -StartTime $dateStart

if ($updatesBroken) {
    Write-Verbose -Verbose -Message "Found: '$errorReason' in log file: $ccmLogName"
    Write-Verbose -Verbose -Message "Office 365 ProPlus updates seems to be broken. Returning NON-COMPLIANT"
    Write-Output "NON-COMPLIANT"
}
else {
    Write-Verbose -Verbose -Message "Office 365 ProPlus updates seems OK. Returning COMPLIANT"
    Write-Output "COMPLIANT"
}