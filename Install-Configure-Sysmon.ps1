<#
.SYNOPSIS
	This script installs, configures, or uninstalls Sysmon on a Windows system.

.DESCRIPTION
	The script provides functionality to download, install, and configure Sysmon, a system monitoring tool from Sysinternals. It also allows for the uninstallation of Sysmon. The script includes logging capabilities and checks to ensure Sysmon is running with the latest configuration.

.PARAMETER InstallSysmon
	Switch parameter to install and configure Sysmon.

.PARAMETER UninstallSysmon
	Switch parameter to uninstall Sysmon.

.EXAMPLE
	.\Install-Configure-Sysmon.ps1 -InstallSysmon
	Installs and configures Sysmon with the specified configuration.

.EXAMPLE
	.\Install-Configure-Sysmon.ps1 -UninstallSysmon
	Uninstalls Sysmon from the system.

.NOTES
	Author: Martin Bengtsson
	Date: 12-02-2025
	Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
	[switch]$InstallSysmon,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$UninstallSysmon
)
# Define the URLs for Sysmon download and configuration file
$sysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
$sysmonBasePath = "C:\Windows\Sysmon"
$sysmonZipPath = "C:\Windows\Temp\Sysmon.zip"
$sysmonExtractPath = $sysmonBasePath
$sysmonConfigPath = (Join-Path -Path $sysmonBasePath -ChildPath "sysmon-config.xml")
$sysmonLogPath = (Join-Path -Path $sysmonBasePath -ChildPath "sysmon-install.log")
$sysmonConfigVersion = "75"
$sysmonConfigContent = ""
# Function to log messages
function Write-Log {
	param (
		[string]$logMessage
	)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logMessage = "$timestamp - $logMessage"
	$logMessage | Out-File -FilePath $sysmonLogPath -Append -Encoding UTF8
	Write-Output $logMessage
}
# Function to test if Sysmon service is running
function Test-SysmonService {
	try {
		$service = Get-Service -Name "Sysmon" -ErrorAction Stop
		if ($service.Status -eq 'Running') {
			Write-Log "Sysmon service is running."
			return $true
		} else {
			Write-Log "Sysmon service is not running."
			return $false
		}
	} catch {
		Write-Log "Sysmon service is not installed."
		return $false
	}
}
# Function to get the current Sysmon configuration version
function Get-SysmonConfigVersion {
	if (Test-Path -Path $sysmonConfigPath) {
		$currentConfig = Get-Content -Path $sysmonConfigPath -ErrorAction SilentlyContinue
		if ($currentConfig) {
			$versionLine = $currentConfig | Select-String -Pattern "Source version:"
			if ($versionLine) {
				return ($versionLine -split ":")[1].Trim()
			}
		}
	} else {
		Write-Log "Sysmon configuration file not found."
	}
	return $null
}
# Function to install Sysmon
function Install-Sysmon() {
	$sysmonService = Test-SysmonService
	if ($sysmonService[1] -eq $true) {
		$currentVersion = Get-SysmonConfigVersion
		if ($currentVersion -lt $sysmonConfigVersion) {
			try {
				Write-Log "Updating Sysmon configuration to version $sysmonConfigVersion."
				$sysmonConfigContent | Out-File -FilePath $sysmonConfigPath -Encoding UTF8 -Force
				Start-Process -FilePath (Join-Path -Path $sysmonExtractPath -ChildPath "Sysmon.exe") -ArgumentList "-c $sysmonConfigPath" -NoNewWindow -Wait
				Write-Log "Sysmon configuration updated."
			} catch {
				Write-Log "Failed to update Sysmon configuration: $_"
			}
		} else {
			Write-Log "Sysmon is already running with the latest configuration version $sysmonConfigVersion."
		}
	} else {
		try {
			Write-Log "Downloading Sysmon from $sysmonUrl to $sysmonZipPath."
			Invoke-WebRequest -Uri $sysmonUrl -OutFile $sysmonZipPath -UseBasicParsing -ErrorAction Stop
		} catch {
			Write-Log "Failed to download Sysmon: $_"
			return
		}
		try {
			Write-Log "Extracting Sysmon to $sysmonExtractPath."
			Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonExtractPath -ErrorAction Stop -Force
		} catch {
			Write-Log "Failed to extract Sysmon: $_"
			return
		}
		try {
			Write-Log "Saving Sysmon configuration to $sysmonConfigPath."
			$sysmonConfigContent | Out-File -FilePath $sysmonConfigPath -Encoding UTF8 -Force
		} catch {
			Write-Log "Failed to save Sysmon configuration: $_"
			return
		}
		try {
			$sysmonExePath = (Join-Path -Path $sysmonExtractPath -ChildPath "Sysmon.exe")
			Write-Log "Installing Sysmon with the saved configuration."
			Start-Process -FilePath $sysmonExePath -ArgumentList "-accepteula -i $sysmonConfigPath" -NoNewWindow -Wait
			$sysmonService = Test-SysmonService
			if ($sysmonService[1] -eq $true) {
				Write-Log "Sysmon successfully installed."
			}
		} catch {
			Write-Log "Failed to install Sysmon: $_"
		}
	}
}
# Function to uninstall Sysmon
function Uninstall-Sysmon {
	try {
		Write-Log "Uninstalling Sysmon."
		$sysmonExePath = (Join-Path -Path $sysmonExtractPath -ChildPath "Sysmon.exe")
		Start-Process -FilePath $sysmonExePath -ArgumentList "-u" -NoNewWindow -Wait
		Write-Log "Sysmon successfully uninstalled."
	} catch {
		Write-Log "Failed to uninstall Sysmon: $_"
	}
}
if ($PSBoundParameters["InstallSysmon"]) {
	# Call the function to install Sysmon
	Install-Sysmon
}
if ($PSBoundParameters["UninstallSysmon"]) {
	# Call the function to uninstall Sysmon
	Uninstall-Sysmon
}
