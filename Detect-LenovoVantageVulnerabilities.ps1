<#
.SYNOPSIS
    Detects the Lenovo Vantage vulnerabilities explained here: https://support.lenovo.com/cy/en/product_security/len-75210
   
.DESCRIPTION
    Detects the Lenovo Vantage vulnerabilities explained here: https://support.lenovo.com/cy/en/product_security/len-75210

.NOTES
    Filename: Detect-LenovoVantageVulnerabilities.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#> 
$imControllerPath = "$env:windir\Lenovo\ImController\PluginHost\Lenovo.Modern.ImController.PluginHost.exe"
$imCOntrollerServiceName = "ImControllerService"
$imCOntrollerService = Get-Service -Name $imCOntrollerServiceName -ErrorAction SilentlyContinue
$checkVersion = "1.1.20.3"
if (-NOT[string]::IsNullOrEmpty($imCOntrollerService)) {
    if (Test-Path -Path $imControllerPath) {
        $fileVersion = (Get-Item -Path $imControllerPath).VersionInfo.FileVersion
        if ($fileVersion -lt $checkVersion) {
            Write-Output "[NOT GOOD]. IMController file version is less than $checkVersion. Device is vulnerable"
            exit 1
        }
        else {
            Write-Output "[ALL GOOD]. IMController file version is NOT less than $checkVersion. Device is NOT vulnerable"
            exit 0
        }
    }
    else {
        Write-Output "Lenovo IMController PATH not found. Device not affected by vulnerability"
        exit 0
    }
}
else {
    Write-Output "Lenovo IMController SERVICE not found. Device not affected by vulnerability"
    exit 0
}