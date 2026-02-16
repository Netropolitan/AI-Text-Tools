# download-deps.ps1 - Download whisper.cpp binaries and model for local STT
#
# Downloads:
#   - whisper-cli.exe from whisper.cpp GitHub releases
#   - ggml-tiny.en.bin model from HuggingFace
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\download-deps.ps1

param(
    [string]$BinDir = (Join-Path $PSScriptRoot "..\bin"),
    [string]$WhisperVersion = "v1.7.5"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AI Text Tools - Download Dependencies" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create bin directory
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    Write-Host "Created bin/ directory" -ForegroundColor Green
}

# --- Download whisper-cli.exe ---
$whisperExe = Join-Path $BinDir "whisper-cli.exe"
if (Test-Path $whisperExe) {
    Write-Host "[SKIP] whisper-cli.exe already exists" -ForegroundColor Yellow
} else {
    Write-Host "Downloading whisper-cli.exe ($WhisperVersion)..." -ForegroundColor White

    $whisperZipUrl = "https://github.com/ggml-org/whisper.cpp/releases/download/$WhisperVersion/whisper-$WhisperVersion-bin-x64.zip"
    $zipPath = Join-Path $BinDir "whisper-bin.zip"
    $extractPath = Join-Path $BinDir "whisper-extract"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $whisperZipUrl -OutFile $zipPath -UseBasicParsing
        Write-Host "  Downloaded ZIP ($([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB)" -ForegroundColor Gray

        # Extract and find whisper-cli.exe
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $found = Get-ChildItem -Path $extractPath -Recurse -Filter "whisper-cli.exe" | Select-Object -First 1
        if ($found) {
            Copy-Item $found.FullName $whisperExe
            Write-Host "  Extracted whisper-cli.exe" -ForegroundColor Green
        } else {
            # Try main.exe (older releases name it differently)
            $found = Get-ChildItem -Path $extractPath -Recurse -Filter "main.exe" | Select-Object -First 1
            if ($found) {
                Copy-Item $found.FullName $whisperExe
                Write-Host "  Extracted main.exe as whisper-cli.exe" -ForegroundColor Green
            } else {
                throw "whisper-cli.exe not found in archive"
            }
        }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  You can download manually from:" -ForegroundColor Yellow
        Write-Host "  https://github.com/ggml-org/whisper.cpp/releases" -ForegroundColor Yellow
    } finally {
        # Clean up
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    }
}

# --- Download ggml-tiny.en.bin model ---
$modelFile = Join-Path $BinDir "ggml-tiny.en.bin"
if (Test-Path $modelFile) {
    Write-Host "[SKIP] ggml-tiny.en.bin already exists" -ForegroundColor Yellow
} else {
    Write-Host "Downloading ggml-tiny.en.bin model (~75 MB)..." -ForegroundColor White

    $modelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $modelUrl -OutFile $modelFile -UseBasicParsing
        $size = [math]::Round((Get-Item $modelFile).Length / 1MB, 1)
        Write-Host "  Downloaded ggml-tiny.en.bin ($size MB)" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  You can download manually from:" -ForegroundColor Yellow
        Write-Host "  https://huggingface.co/ggerganov/whisper.cpp" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# Verify
$allGood = $true
if (Test-Path $whisperExe) {
    Write-Host "[OK] whisper-cli.exe" -ForegroundColor Green
} else {
    Write-Host "[MISSING] whisper-cli.exe" -ForegroundColor Red
    $allGood = $false
}

if (Test-Path $modelFile) {
    Write-Host "[OK] ggml-tiny.en.bin" -ForegroundColor Green
} else {
    Write-Host "[MISSING] ggml-tiny.en.bin" -ForegroundColor Red
    $allGood = $false
}

if ($allGood) {
    Write-Host ""
    Write-Host "All dependencies ready!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some dependencies are missing. See errors above." -ForegroundColor Yellow
    exit 1
}
