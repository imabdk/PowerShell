<#
.SYNOPSIS
    Edit local hosts file in C:\Windows\System32\drivers\etc\hosts
    
.DESCRIPTION
    Powershell script used to add or remove entries in the local hosts file in Windows

.EXAMPLE
    .\Edit-HostsFile.ps1 -AddHost -IP 192.168.1.1 -Hostname ftw.imab.dk
    .\Edit-HostsFile.ps1 -RemoveHost -Hostname ftw.imab.dk
    
.NOTES
    Filename: Edit-HostsFile.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson
#> 

param (
	[Parameter(Mandatory=$false)]
	[string]$IP,

	[Parameter(Mandatory=$true)]
	[string]$Hostname,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$AddHost,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$RemoveHost
)

# Path to local hosts file
$File = "C:\Windows\System32\drivers\etc\hosts"

# function to add new host to hosts file
function Add-Host([string]$fIP, [string]$fHostname) {
    Write-Verbose -Verbose -Message "Running Add-Host function..."
    $Content = Get-Content -Path $File | Select-String -Pattern ([regex]::Escape("$fHostname"))
    if(-NOT($Content)) {
        Write-Verbose -Verbose -Message "Adding $IP and $Hostname to hosts file"
        $fIP + "`t" + $fHostname | Out-File -Encoding ASCII -Append $File
    }
}

#function to remove host from hosts file
function Remove-Host([string]$fHostname) {
    Write-Verbose -Verbose -Message "Running Remove-Host function..."
	$Content = Get-Content -Path $File
	$newLines = @()
	
	foreach ($Line in $Content) {
		$Bits = [regex]::Split($Line, "\t+")
		if ($Bits.count -eq 2) {
            Write-Host "doing something 1"
			if ($Bits[1] -ne $fHostname) {
                Write-Host "doing something 2"
				$newLines += $Line
			}
		} else {
            Write-Host "doing something else"
			$newLines += $Line
		}
	}
	Write-Verbose -Verbose -Message "Removing $Hostname from hosts file"
    Clear-Content $File
	foreach ($Line in $newLines) {
        Write-Host "doing something 3"
        $Line | Out-File -Encoding ASCII -Append $File
	}
}

# Run the functions depending on choice
# Add host to file
if ($PSBoundParameters["AddHost"]) {

    Add-Host $IP $Hostname

}
# Remove host from file
if ($PSBoundParameters["RemoveHost"]) {

    Remove-Host $Hostname

}