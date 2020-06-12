<#
.SYNOPSIS
    Install RSAT features for Windows 10 1809 or 1903 or 1909 or 2004.
    
.DESCRIPTION
    Install RSAT features for Windows 10 1809 or 1903 or 1909 or 2004. All features are installed online from Microsoft Update thus the script requires Internet access

.PARAM All
    Installs all the features within RSAT. This takes several minutes, depending on your Internet connection

.PARAM Basic
    Installs ADDS, DHCP, DNS, GPO, ServerManager

.PARAM ServerManager
    Installs ServerManager

.PARAM Uninstall
    Uninstalls all the RSAT features

.NOTES
    Filename: Install-RSATv1809v1903v1909v2004.ps1
    Version: 1.4
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
    [switch]$Uninstall
)

# Check for administrative rights
if (-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning -Message "The script requires elevation"
    break
}

# Create write log function
function Write-Log() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
        
        # EDIT with your location for the local log file
        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path="$env:windir\Install-RSATFeatures.log",

        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info"
    )

    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process {
		if ((Test-Path $Path)) {
			$LogSize = (Get-Item -Path $Path).Length/1MB
			$MaxLogSize = 5
		}
                
        # Check for file size of the log. If greater than 5MB, it will create a new one and delete the old.
        if ((Test-Path $Path) -AND $LogSize -gt $MaxLogSize) {
            Write-Error "Log file $Path already exists and file exceeds maximum file size. Deleting the log and starting fresh."
            Remove-Item $Path -Force
            $NewLogFile = New-Item $Path -Force -ItemType File
        }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (-NOT(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
        }

        else {
            # Nothing to see here yet.
        }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
            }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
            }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
            }
        }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End {
    }
}

# Create Pending Reboot function for registry
function Test-PendingRebootRegistry {
    $CBSRebootKey = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Ignore
    $WURebootKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction Ignore
    if (($CBSRebootKey -ne $null) -OR ($WURebootKey -ne $null)) {
        $true
    }
    else {
        $false
    }
}

# Windows 10 1809 build
$1809Build = "17763"
# Windows 10 1903 build
$1903Build = "18362"
# Windows 10 1909 build
$1909Build = "18363"
# Windows 10 2004 build
$2004Build = "19041"
# Get running Windows build
$WindowsBuild = (Get-CimInstance -Class Win32_OperatingSystem).BuildNumber
# Get information about local WSUS server
$WUServer = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name WUServer -ErrorAction Ignore).WUServer
# Look for pending reboots in the registry
$TestPendingRebootRegistry = Test-PendingRebootRegistry

if (($WindowsBuild -eq $1809Build) -OR ($WindowsBuild -eq $1903Build) -OR ($WindowsBuild -eq $1909Build) -OR ($WindowsBuild -eq $2004Build)) {
    Write-Log -Message "Running correct Windows 10 build number for installing RSAT with Features on Demand. Build number is: $WindowsBuild"
    Write-Log -Message "***********************************************************"

    if ($WUServer -ne $null) {
        Write-Log -Message "A local WSUS server was found configured by group policy: $WUServer"
        Write-Log -Message "You might need to configure additional setting by GPO if things are not working"
        Write-Log -Message "The GPO of interest is following: Specify settings for optional component installation and component repair"
        Write-Log -Message "Check ON: Download repair content and optional features directly from Windows Update..."
        Write-Log -Message "***********************************************************"
    }

    if ($TestPendingRebootRegistry -eq $true) {
        Write-Log -Message "Reboots are pending. The script will continue, but RSAT might not install successfully"
        Write-Log -Message "***********************************************************"
    }

    if ($PSBoundParameters["All"]) {
        Write-Log -Message "Script is running with -All parameter. Installing all available RSAT features"
        $Install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "NotPresent"}
        if ($Install -ne $null) {
            foreach ($Item in $Install) {
                $RsatItem = $Item.Name
                Write-Log -Message "Adding $RsatItem to Windows"
                try {
                    Add-WindowsCapability -Online -Name $RsatItem
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to add $RsatItem to Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
        }
        else {
            Write-Log -Message "All RSAT features seems to be installed already"
        }
    }

    if ($PSBoundParameters["Basic"]) {
        Write-Log -Message "Script is running with -Basic parameter. Installing basic RSAT features"
        # Querying for what I see as the basic features of RSAT. Modify this if you think something is missing. :-)
        $Install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat.ActiveDirectory*" -OR $_.Name -like "Rsat.DHCP.Tools*" -OR $_.Name -like "Rsat.Dns.Tools*" -OR $_.Name -like "Rsat.GroupPolicy*" -OR $_.Name -like "Rsat.ServerManager*" -AND $_.State -eq "NotPresent" }
        if ($Install -ne $null) {
            foreach ($Item in $Install) {
                $RsatItem = $Item.Name
                Write-Log -Message "Adding $RsatItem to Windows"
                try {
                    Add-WindowsCapability -Online -Name $RsatItem
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to add $RsatItem to Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
        }
        else {
            Write-Log -Message "The basic features of RSAT seems to be installed already"
        }
    }

    if ($PSBoundParameters["ServerManager"]) {
        Write-Log -Message "Script is running with -ServerManager parameter. Installing Server Manager RSAT feature"
        $Install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat.ServerManager*" -AND $_.State -eq "NotPresent"} 
        if ($Install -ne $null) {
            $RsatItem = $Install.Name
            Write-Log -Message "Adding $RsatItem to Windows"
            try {
                Add-WindowsCapability -Online -Name $RsatItem
            }
            catch [System.Exception] {
                Write-Log -Message "Failed to add $RsatItem to Windows" -Level Warn 
                Write-Log -Message "$($_.Exception.Message)" -Level Warn 
            }
         }
        
        else {
            Write-Log -Message "$RsatItem seems to be installed already"
        }
    }

    if ($PSBoundParameters["Uninstall"]) {
        Write-Log -Message "Script is running with -Uninstall parameter. Uninstalling all RSAT features"
        # Querying for installed RSAT features first time
        $Installed = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed" -AND $_.Name -notlike "Rsat.ServerManager*" -AND $_.Name -notlike "Rsat.GroupPolicy*" -AND $_.Name -notlike "Rsat.ActiveDirectory*"} 
        if ($Installed -ne $null) {
            Write-Log -Message "Uninstalling the first round of RSAT features"
            # Uninstalling first round of RSAT features - some features seems to be locked until others are uninstalled first
            foreach ($Item in $Installed) {
                $RsatItem = $Item.Name
                Write-Log -Message "Uninstalling $RsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $RsatItem -Online
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to uninstall $RsatItem from Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }       
        }
        # Querying for installed RSAT features second time
        $Installed = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed"}
        if ($Installed -ne $null) { 
            Write-Log -Message "Uninstalling the second round of RSAT features"
            # Uninstalling second round of RSAT features
            foreach ($Item in $Installed) {
                $RsatItem = $Item.Name
                Write-Log -Message "Uninstalling $RsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $RsatItem -Online
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to remove $RsatItem from Windows" -Level Warn 
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
    Write-Log -Message "Not running correct Windows 10 build: $WindowsBuild" -Level Warn
}
