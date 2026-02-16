$base = 'C:\Users\HP ZBook\Documents\AutoHotkey\ai-text-tools-v1.7'
$compiler = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe'
$ahkBase = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'

# Delete existing exes
if (Test-Path "$base\AITextTools.exe") { Remove-Item "$base\AITextTools.exe" -Force }
if (Test-Path "$base\AITextTools-Setup.exe") { Remove-Item "$base\AITextTools-Setup.exe" -Force }
if (Test-Path "$base\Uninstall.exe") { Remove-Item "$base\Uninstall.exe" -Force }

Write-Host "Compiling AITextTools.exe..."
$result = & "$compiler" /in "$base\src\main.ahk" /out "$base\AITextTools.exe" /icon "$base\assets\icon.ico" /base "$ahkBase" 2>&1
Write-Host $result

Write-Host "Compiling AITextTools-Setup.exe..."
$result = & "$compiler" /in "$base\installer\Setup.ahk" /out "$base\AITextTools-Setup.exe" /icon "$base\assets\icon.ico" /base "$ahkBase" 2>&1
Write-Host $result

Write-Host "Compiling Uninstall.exe..."
$result = & "$compiler" /in "$base\installer\Uninstall.ahk" /out "$base\Uninstall.exe" /icon "$base\assets\icon.ico" /base "$ahkBase" 2>&1
Write-Host $result

Write-Host "Done! Checking versions..."

$files = @("$base\AITextTools.exe", "$base\AITextTools-Setup.exe", "$base\Uninstall.exe")
foreach ($file in $files) {
    if (Test-Path $file) {
        $info = (Get-Item $file).VersionInfo
        $name = Split-Path $file -Leaf
        Write-Host "$name`: Version=$($info.FileVersion), Modified=$((Get-Item $file).LastWriteTime)"
    } else {
        Write-Host "$file NOT FOUND"
    }
}
