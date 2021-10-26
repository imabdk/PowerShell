<#
.SYNOPSIS
    Load and run the LSUClient PowerShell module. Used for installing Lenovo BIOS and Drivers during OSD with Configuration Manager
   
.DESCRIPTION
    Same as above

.NOTES
    Filename: Run-LSUClientModule-OSD.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/install-lenovo-drivers-and-bios-directly-from-lenovos-driver-catalog-during-osd-using-configuration-manager/
    
#> 

$companyName = "imab.dk"
$global:regKey = "HKLM:\SOFTWARE\$companyName\OSDDrivers"
function Get-LenovoComputerModel() {
    $lenovoVendor = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Vendor
    if ($lenovoVendor = "LENOVO") {
        Write-Verbose -Verbose "Lenovo device is detected. Continuing."
        $global:lenovoModel = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version
        $modelRegEx = [regex]::Match((Get-CimInstance -ClassName CIM_ComputerSystem -ErrorAction SilentlyContinue -Verbose:$false).Model, '^\w{4}')
        if ($modelRegEx.Success -eq $true) {
            $global:lenovoModelNumber = $modelRegEx.Value
            Write-Verbose -Verbose "Lenovo modelnumber: $global:lenovoModelNumber - Lenovo model: $global:lenovoModel"
        } else {
            Write-Verbose -Verbose "Failed to retrieve computermodel"
        } 
    } else {
        Write-Verbose -Verbose "Not a Lenovo device. Aborting."
        exit 1
    }  
}
function Load-LSUClientModule() {
    if (-NOT(Get-Module -Name LSUClient)) {
        Write-Verbose -Verbose "LSUClient module not loaded. Continuing."
        if (Get-Module -Name LSUClient -ListAvailable) {
            Write-Verbose -Verbose "LSUClient module found available. Try importing and loading it."
            try {
                Import-Module -Name LSUClient
                Write-Verbose -Verbose "Successfully imported and loaded the LSUClient module."
            } catch {
                Write-Verbose -Verbose "Failed to import the LSUClient module. Aborting."
                exit 1
            }
        }
    } else {
        Write-Verbose -Verbose "LSUClient module already imported and loaded."
    }
}
#Function for locating and installing all drivers and BIOS which can be installed silent and unattended
function Run-LSUClientModuleDefault() {
    $regKey = $global:regKey
    if (-NOT(Test-Path -Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }
    foreach ($update in $updates) {
        Install-LSUpdate $update -Verbose
        New-ItemProperty -Path $regKey -Name $update.ID -Value $update.Title -Force | Out-Null
    }
}
#Exclude Intel Graphics Driver
#Some weird shit going on with the package here on certain models, making the script run forever, thus exlcuding the driver
function Run-LSUClientModuleCustom() {
    $regKey = $global:regKey
    if (-NOT(Test-Path -Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended -AND $_.Title -notlike "Intel HD Graphics Driver*"}
    foreach ($update in $updates) {
        Install-LSUpdate $update -Verbose
        New-ItemProperty -Path $regKey -Name $update.ID -Value $update.Title -Force | Out-Null
    }
}
try {
    Write-Verbose -Verbose "Script is running."
    Get-LenovoComputerModel
    Load-LSUClientModule
    if ($global:lenovoModelNumber -eq "20QF") {
        Write-Verbose -Verbose "Running LSUClient with custom function"
        Run-LSUClientModuleCustom
    } else {
        Write-Verbose -Verbose "Running LSUClient with default function"
        Run-LSUClientModuleDefault
    }
}
catch [Exception] {
    Write-Verbose -Verbose "Script failed to carry out one or more actions."
    Write-Verbose -Verbose $_.Exception.Message
    exit 1
}
finally { 
    $currentDate = Get-Date -Format g
    if (-NOT(Test-Path -Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
    New-ItemProperty -Path $regKey -Name "_RunDateTime" -Value $currentDate -Force | Out-Null
    New-ItemProperty -Path $regKey -Name "_LenovoModelNumber" -Value $global:lenovoModelNumber -Force | Out-Null
    New-ItemProperty -Path $regKey -Name "_LenovoModel" -Value $global:lenovoModel -Force | Out-Null
    Write-Verbose -Verbose "Script is done running."
}