<#
.SYNOPSIS
    Install RSAT features for Windows 10 1809 or 1903 or 1909 or 2004 or 20H2.
    
.DESCRIPTION
    Install RSAT features for Windows 10 1809 or 1903 or 1909 or 2004 or 20H2. All features are installed online from Microsoft Update thus the script requires Internet access

.PARAMETER All
    Installs all the features within RSAT. This takes several minutes, depending on your Internet connection

.PARAMETER Basic
    Installs ADDS, DHCP, DNS, GPO, ServerManager

.PARAMETER ServerManager
    Installs ServerManager

.PARAMETER Uninstall
    Uninstalls all the RSAT features

.PARAMETER disableWSUS
    Disables the use of WSUS prior to installing the RSAT features. This involves restarting the wuauserv service. The script will enable WSUS again post installing the

.NOTES
    Filename: Install-RSATv1809v1903v1909v2004.ps1
    Version: 1.6
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

    Version history:

    1.0   -   Script created

    1.2   -   Added test for pending reboots. If reboot is pending, RSAT features might not install successfully
              Added test for configuration of local WSUS by Group Policy.
                - If local WSUS is configured by Group Policy, history shows that additional settings might be needed for some environments
                - This policy in question is located in administrative templates -> System
    1.3   -   Now using Get-CmiInstance instead of Get-WmiObject for determining OS buildnumber

    1.4   -   Script updated to support installing RSAT on Windows 10 v2004
    
    1.5   -   Script updated to support installing RSAT on Windows 10 v20H2

    1.6   -   Added option to disable WSUS prior to installing RSAT as features on demand
                - Some environments seems to require this
                - Will enable WSUS again post installation
    
#> 

[CmdletBinding()]
param(
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$All,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Basic,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$ServerManager,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Uninstall,
    [Parameter(Mandatory=$false)]
    [switch]$DisableWSUS
)

# Check for administrative rights
if (-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning -Message "The script requires elevation"
    break
}

# Create Write-Log function
function Write-Log() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$message,
        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$path = "$env:windir\Install-RSAT.log",
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$level = "Info"
    )
    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $verbosePreference = 'Continue'
    }
    Process {
		if ((Test-Path $Path)) {
			$logSize = (Get-Item -Path $Path).Length/1MB
			$maxLogSize = 5
		}
        # Check for file size of the log. If greater than 5MB, it will create a new one and delete the old.
        if ((Test-Path $Path) -AND $LogSize -gt $MaxLogSize) {
            Write-Error "Log file $Path already exists and file exceeds maximum file size. Deleting the log and starting fresh."
            Remove-Item $Path -Force
            $newLogFile = New-Item $Path -Force -ItemType File
        }
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (-NOT(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $newLogFile = New-Item $Path -Force -ItemType File
        }
        else {
            # Nothing to see here yet.
        }
        # Format Date for our Log File
        $formattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($level) {
            'Error' {
                Write-Error $message
                $levelText = 'ERROR:'
            }
            'Warn' {
                Write-Warning $Message
                $levelText = 'WARNING:'
            }
            'Info' {
                Write-Verbose $Message
                $levelText = 'INFO:'
            }
        }
        # Write log entry to $Path
        "$formattedDate $levelText $message" | Out-File -FilePath $path -Append
    }
    End {
    }
}

# Create Pending Reboot function for registry
function Test-PendingRebootRegistry {
    $cbsRebootKey = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Ignore
    $wuRebootKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction Ignore
    if (($cbsRebootKey -ne $null) -OR ($wuRebootKey -ne $null)) {
        $true
    }
    else {
        $false
    }
}

# Minimum required Windows 10 build (v1809)
$1809Build = "17763"
# Get running Windows build
$windowsBuild = (Get-CimInstance -Class Win32_OperatingSystem).BuildNumber
# Get information about local WSUS server
$wuServer = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name WUServer -ErrorAction Ignore).WUServer
$useWUServer = (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction Ignore).UseWuServer
# Look for pending reboots in the registry
$testPendingRebootRegistry = Test-PendingRebootRegistry

if ($windowsBuild -ge $1809Build) {
    Write-Log -Message "Running correct Windows 10 build number for installing RSAT with Features on Demand. Build number is: $WindowsBuild"
    Write-Log -Message "***********************************************************"

    if ($wuServer -ne $null) {
        Write-Log -Message "A local WSUS server was found configured by group policy: $wuServer"
        Write-Log -Message "You might need to configure additional setting by GPO if things are not working"
        Write-Log -Message "The GPO of interest is following: Specify settings for optional component installation and component repair"
        Write-Log -Message "Check ON: Download repair content and optional features directly from Windows Update..."
        Write-Log -Message "***********************************************************"
        Write-Log -Message "Alternatively, run this script with parameter -disableWSUS to allow the script to temporarily disable WSUS"
    }
    if ($PSBoundParameters["DisableWSUS"]) {
        if (-NOT[string]::IsNullOrEmpty($useWUServer)) {
            if ($useWUServer -eq 1) {
                Write-Log -Message "***********************************************************"
                Write-Log -Message "DisableWSUS selected. Temporarily disabling WSUS in order to successfully install features on demand"
                Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWuServer" -Value 0
                Restart-Service wuauserv
            }
        }
    }

    if ($testPendingRebootRegistry -eq $true) {
        Write-Log -Message "***********************************************************"
        Write-Log -Message "Reboots are pending. The script will continue, but RSAT might not install successfully"
    }

    if ($PSBoundParameters["All"]) {
        Write-Log -Message "***********************************************************"
        Write-Log -Message "Script is running with -All parameter. Installing all available RSAT features"
        $install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "NotPresent"}
        if ($install -ne $null) {
            foreach ($item in $install) {
                $rsatItem = $item.Name
                Write-Log -Message "Adding $RsatItem to Windows"
                try {
                    Add-WindowsCapability -Online -Name $rsatItem
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to add $rsatItem to Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
            if ($PSBoundParameters["DisableWSUS"]) {
                if (-NOT[string]::IsNullOrEmpty($useWUServer)) {
                    if ($useWUServer -eq 1) {
                        Write-Log -Message "***********************************************************"
                        Write-Log -Message "Enabling WSUS again post installing features on demand"
                        Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWuServer" -Value 1
                        Restart-Service wuauserv
                    }
                }
            }
        }
        else {
            Write-Log -Message "All RSAT features seems to be installed already"
        }
    }

    if ($PSBoundParameters["Basic"]) {
        Write-Log -Message "***********************************************************"
        Write-Log -Message "Script is running with -Basic parameter. Installing basic RSAT features"
        # Querying for what I see as the basic features of RSAT. Modify this if you think something is missing. :-)
        $install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat.ActiveDirectory*" -OR $_.Name -like "Rsat.DHCP.Tools*" -OR $_.Name -like "Rsat.Dns.Tools*" -OR $_.Name -like "Rsat.GroupPolicy*" -OR $_.Name -like "Rsat.ServerManager*" -AND $_.State -eq "NotPresent" }
        if ($install -ne $null) {
            foreach ($item in $install) {
                $rsatItem = $item.Name
                Write-Log -Message "Adding $rsatItem to Windows"
                try {
                    Add-WindowsCapability -Online -Name $rsatItem
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to add $rsatItem to Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
            if ($PSBoundParameters["DisableWSUS"]) {
                if (-NOT[string]::IsNullOrEmpty($useWUServer)) {
                    if ($useWUServer -eq 1) {
                        Write-Log -Message "***********************************************************"
                        Write-Log -Message "Enabling WSUS again post installing features on demand"
                        Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWuServer" -Value 1
                        Restart-Service wuauserv
                    }
                }
            }
        }
        else {
            Write-Log -Message "The basic features of RSAT seems to be installed already"
        }
    }

    if ($PSBoundParameters["ServerManager"]) {
        Write-Log -Message "***********************************************************"
        Write-Log -Message "Script is running with -ServerManager parameter. Installing Server Manager RSAT feature"
        $install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat.ServerManager*" -AND $_.State -eq "NotPresent"} 
        if ($install -ne $null) {
            $rsatItem = $Install.Name
            Write-Log -Message "Adding $rsatItem to Windows"
            try {
                Add-WindowsCapability -Online -Name $rsatItem
            }
            catch [System.Exception] {
                Write-Log -Message "Failed to add $rsatItem to Windows" -Level Warn 
                Write-Log -Message "$($_.Exception.Message)" -Level Warn 
            }
            if ($PSBoundParameters["DisableWSUS"]) {
                if (-NOT[string]::IsNullOrEmpty($useWUServer)) {
                    if ($useWUServer -eq 1) {
                        Write-Log -Message "***********************************************************"
                        Write-Log -Message "Enabling WSUS again post installing features on demand"
                        Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWuServer" -Value 1
                        Restart-Service wuauserv
                    }
                }
            }
         }
        
        else {
            Write-Log -Message "$rsatItem seems to be installed already"
        }
    }

    if ($PSBoundParameters["Uninstall"]) {
        Write-Log -Message "***********************************************************"
        Write-Log -Message "Script is running with -Uninstall parameter. Uninstalling all RSAT features"
        # Querying for installed RSAT features first time
        $installed = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed" -AND $_.Name -notlike "Rsat.ServerManager*" -AND $_.Name -notlike "Rsat.GroupPolicy*" -AND $_.Name -notlike "Rsat.ActiveDirectory*"} 
        if ($installed -ne $null) {
            Write-Log -Message "Uninstalling the first round of RSAT features"
            # Uninstalling first round of RSAT features - some features seems to be locked until others are uninstalled first
            foreach ($item in $installed) {
                $rsatItem = $item.Name
                Write-Log -Message "Uninstalling $rsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $rsatItem -Online
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to uninstall $rsatItem from Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
        }
        # Querying for installed RSAT features second time
        $installed = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed"}
        if ($installed -ne $null) { 
            Write-Log -Message "Uninstalling the second round of RSAT features"
            # Uninstalling second round of RSAT features
            foreach ($item in $installed) {
                $rsatItem = $item.Name
                Write-Log -Message "Uninstalling $rsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $rsatItem -Online
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to remove $rsatItem from Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            } 
        }
        else {
            Write-Log -Message "All RSAT features seems to be uninstalled already"
        }
    }
}
else {
    Write-Log -Message "Not running correct Windows 10 build: $windowsBuild" -Level Warn
}