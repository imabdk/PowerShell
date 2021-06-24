<#
.DESCRIPTION
    Installs the new Remote Desktop Connection Manager directly from the Sysinternals online file share.

.EXAMPLES
    .\Install-NewRDCMan.ps1 -Install
        Uninstall the old version, if the old version is installed. Then downloads the new version directly from the Internet.

    .\Install-NewRDCMan.ps1 -Uninstall
        Uninstalls (deletes) the entire directory
 
.NOTES
    FileName:    Install-NewRDCMan.ps1
    Author:      Martin Bengtsson
#>

[CmdletBinding()]
param(
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Install,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Uninstall
 )

function Uninstall-OldRDCMan() {
    $registryPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    if (Test-Path -Path $registryPath) {
        $rdcMan = Get-ChildItem -Path $registryPath -Recurse | Get-ItemProperty | Where-Object {$_.Displayname -eq "Remote Desktop Connection Manager" } | Select-Object DisplayName,DisplayVersion,UninstallString
        if (-NOT[string]::IsNullOrEmpty($rdcMan)) {
            Write-Verbose -Verbose -Message "RDCMan found in HKLM"
            foreach ($app in $rdcMan) {
                if ($app.UninstallString) {
                    # Regular expression for format of MSI product code
                    $msiRegEx = "\w{8}-\w{4}-\w{4}-\w{4}-\w{12}"
                    # Formatting the product code in a creative way. 
                    # Needed this separately, as the uninstall string retrieved from registry sometimes wasn't formatted properly
                    $a = $app.Uninstallstring.Split("{")[1] 
                    $b = $a.Split("}")[0]
                    # Only continuing if the uninstall string matches a regular MSI product code
                    if ($b -match $msiRegEx) {
                        $productCode = "{" + $b + "}"
                        if (-NOT[string]::IsNullOrEmpty($productCode)) {
                            try {
                                Write-Verbose -Verbose -Message "Uninstalling application: $($app.DisplayName)"
                                Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList ("/x" + $productCode + " /passive") -Wait
                                Write-Verbose -Verbose -Message "Successfully uninstalled application: $($app.DisplayName) version: $($app.DisplayVersion)"
                            }

                            catch {
                                Write-Error -Message "Failed to uninstall application: $($app.DisplayName)"
                            }
                        }
                    }
                }
            }
        }
        else {
            Write-Verbose -Verbose -Message "Old RDCMan is not installed. Doing nothing"   
        }
    }
}

function Install-NewRDCMan() {
    $rdcManSource = "https://live.sysinternals.com/RDCMan.exe"
    $rdcManDestination = "C:\Program Files\SysinternalsSuite"
    $rdcManFile = "$rdcManDestination\RDCMan.exe"
    try { $testRdcManSource = Invoke-WebRequest -Uri $rdcManSource -UseBasicParsing } catch { <# nothing to see here. Used to make webrequest silent #> }
    if ($testRdcManSource.StatusDescription -eq "OK") {
        if (-NOT(Test-Path $rdcManDestination)) {
            New-Item -ItemType Directory -Path $rdcManDestination
        }
        try {
            Invoke-WebRequest -Uri $rdcManSource -OutFile $rdcManFile
            Write-Verbose -Verbose -Message "Succesfully installed NEW Remote Desktop Connection Manager from $rdcManSource"
        }
        catch {
            Write-Verbose -Verbose -Message "Failed to download RDCman.exe from $rdcManSource"            
        }
    }
    else {
        Write-Verbose -Verbose -Message "RDCMan.exe is not available at the set location or there's no access to the Internet"        
    }    
}

function Uninstall-NewRDCMan() {
    $rdcManDestination = "C:\Program Files\SysinternalsSuite"
    $rdcManFile = "$rdcManDestination\RDCMan.exe"
    if (Test-Path $rdcManFile) {
        try {
            Remove-Item $rdcManDestination -Force -Recurse
            Write-Verbose -Verbose -Message "Successfully removed Remote Desktop Connection Manager from $rdcManFile"
        }
        catch {
            Write-Verbose -Verbose -Message "Failed to remove Remote Desktop Connection Manager from $rdcManFile"
        }
    }
    else {
        Write-Verbose -Verbose -Message "Remote Desktop Connection Manager is not found in $rdcManFile"  
    }
}

if ($PSBoundParameters["Install"]) {
    Uninstall-OldRDCMan
    Install-NewRDCMan
}

if ($PSBoundParameters["Uninstall"]) {
    Uninstall-NewRDCMan
}