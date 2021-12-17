<#
.SYNOPSIS
    Remediates the Lenovo Vantage vulnerabilities explained here: https://support.lenovo.com/cy/en/product_security/len-75210
   
    
.DESCRIPTION
    Remediates the Lenovo Vantage vulnerabilities explained here: https://support.lenovo.com/cy/en/product_security/len-75210

.NOTES
    Filename: Remediate-LenovoVantageVulnerabilities.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#> 

$imCOntrollerServiceName = "ImControllerService"
$imCOntrollerService = Get-Service -Name $imCOntrollerServiceName
if (-NOT[string]::IsNullOrEmpty($imCOntrollerService)) {
    try { 
        Restart-Service -Name $imCOntrollerServiceName
        Write-Output "[ALL GOOD]. Service: $imCOntrollerServiceName restarted. Vulnerability expected to be mitigated"
        exit 0
    }
    catch {
        Write-Output "[NOT GOOD] Failed to restart service: $imCOntrollerServiceName"
        exit 1
    }
}