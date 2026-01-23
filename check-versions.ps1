Get-ChildItem 'C:\Users\HP ZBook\Documents\AutoHotkey\ai-text-tools-v1.5\*.exe' | ForEach-Object {
    $ver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).FileVersion
    Write-Host "$($_.Name): $ver - Modified: $($_.LastWriteTime)"
}
