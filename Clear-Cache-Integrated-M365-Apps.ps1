<#
.SYNOPSIS
This script clears the cache for specified Microsoft 365 applications, such as Outlook and other Office apps (Excel, Word, PowerPoint).

.PARAMETER OfficeApp
Specifies the Microsoft 365 application whose cache should be cleared. Valid values are "Outlook" and "Other".

.DESCRIPTION
The script deletes the cache files for the specified Microsoft 365 application to potentially resolve issues related to cached data. 
For Outlook, it clears the cache located in the HubAppFileCache directory. For other Office apps (Excel, Word, PowerPoint), it clears the cache located in the Wef directory.

.EXAMPLE
.\Clear-Cache-Integrated-M365-Apps.ps1 -OfficeApp "Outlook"
Deletes the cache for Outlook.

.EXAMPLE
.\Clear-Cache-Integrated-M365-Apps.ps1 -OfficeApp "Other"
Deletes the cache for other Office apps (Excel, Word, PowerPoint).

.NOTES
Author: Martin Bengtsson
Blog: https://www.imab.dk
#>
param (
    [parameter(Mandatory=$false)]
    [ValidateSet("Outlook", "Other")]
    [string]$OfficeApp
)
$appsCacheOutlook = "$env:LOCALAPPDATA\Microsoft\Outlook\HubAppFileCache"
$appsCacheExcelWordPpt = "$env:LOCALAPPDATA\Microsoft\Office\16.0\Wef"
switch ($OfficeApp) {
    "Outlook" {
        try {
            if (Test-Path $appsCacheOutlook) {
                Remove-Item -Path $appsCacheOutlook -Recurse -Force
                Write-Output "Outlook cache deleted."
            } else {
                Write-Output "Outlook cache not found."
            }
        } catch {
            Write-Output "Failed to delete Outlook cache: $_"
        }
    }
    "Other" {
        try {
            if (Test-Path $appsCacheExcelWordPpt) {
                Remove-Item -Path $appsCacheExcelWordPpt -Recurse -Force
                Write-Output "Office cache deleted."
            } else {
                Write-Output "Office cache not found."
            }
        } catch {
            Write-Output "Failed to delete Office cache: $_"
        }
    }
}