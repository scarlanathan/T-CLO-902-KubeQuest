# fix-ssh-config.ps1
$path = Join-Path $env:USERPROFILE ".ssh\config"
$bytes = [System.IO.File]::ReadAllBytes($path)

# Remove UTF-8 BOM (EF BB BF)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length - 1)]
    [System.IO.File]::WriteAllBytes($path, $bytes)
    Write-Host "BOM removed from $path" -ForegroundColor Green
} else {
    Write-Host "No BOM found, file is OK" -ForegroundColor Yellow
}

# Show first line to verify
$first = [System.IO.File]::ReadAllLines($path)[0]
Write-Host "First line: $first"
