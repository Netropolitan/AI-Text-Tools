# Convert PNG to multi-size ICO for Windows
Add-Type -AssemblyName System.Drawing

$pngPath = "C:\Users\HP ZBook\Downloads\AHK Logo.png"
$icoPath = "C:\Users\HP ZBook\Documents\AutoHotkey\ai-text-tools\assets\icon.ico"

# Load source image
$sourceImage = [System.Drawing.Image]::FromFile($pngPath)

# ICO sizes needed for Windows
$sizes = @(16, 24, 32, 48, 64, 128, 256)

# Create memory stream for ICO
$ms = New-Object System.IO.MemoryStream

# ICO Header
$iconDir = New-Object byte[] 6
$iconDir[0] = 0  # Reserved
$iconDir[1] = 0
$iconDir[2] = 1  # Type: 1 = ICO
$iconDir[3] = 0
$iconDir[4] = [byte]$sizes.Count  # Number of images
$iconDir[5] = 0
$ms.Write($iconDir, 0, 6)

# Calculate offsets
$headerSize = 6 + ($sizes.Count * 16)
$imageDataOffset = $headerSize
$imageData = @()

foreach ($size in $sizes) {
    # Create resized bitmap
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
    $graphics.Dispose()

    # Convert to PNG bytes
    $pngMs = New-Object System.IO.MemoryStream
    $bitmap.Save($pngMs, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytes = $pngMs.ToArray()
    $pngMs.Dispose()
    $bitmap.Dispose()

    $imageData += ,@{
        Size = $size
        Bytes = $pngBytes
    }
}

# Write ICONDIRENTRY for each image
$offset = $headerSize
foreach ($img in $imageData) {
    $entry = New-Object byte[] 16
    $entry[0] = if ($img.Size -eq 256) { 0 } else { [byte]$img.Size }  # Width (0 = 256)
    $entry[1] = if ($img.Size -eq 256) { 0 } else { [byte]$img.Size }  # Height
    $entry[2] = 0   # Color palette
    $entry[3] = 0   # Reserved
    $entry[4] = 1   # Color planes
    $entry[5] = 0
    $entry[6] = 32  # Bits per pixel
    $entry[7] = 0

    # Size of image data (4 bytes, little-endian)
    $sizeBytes = [BitConverter]::GetBytes([uint32]$img.Bytes.Length)
    $entry[8] = $sizeBytes[0]
    $entry[9] = $sizeBytes[1]
    $entry[10] = $sizeBytes[2]
    $entry[11] = $sizeBytes[3]

    # Offset (4 bytes, little-endian)
    $offsetBytes = [BitConverter]::GetBytes([uint32]$offset)
    $entry[12] = $offsetBytes[0]
    $entry[13] = $offsetBytes[1]
    $entry[14] = $offsetBytes[2]
    $entry[15] = $offsetBytes[3]

    $ms.Write($entry, 0, 16)
    $offset += $img.Bytes.Length
}

# Write image data
foreach ($img in $imageData) {
    $ms.Write($img.Bytes, 0, $img.Bytes.Length)
}

# Save to file
[System.IO.File]::WriteAllBytes($icoPath, $ms.ToArray())
$ms.Dispose()
$sourceImage.Dispose()

Write-Host "Multi-size icon created: $icoPath"
Write-Host "Sizes: $($sizes -join ', ')px"
