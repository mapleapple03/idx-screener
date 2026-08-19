<#
.SYNOPSIS
    Menyiapkan dan menerbitkan dashboard screener ke GitHub Pages.

.DESCRIPTION
    Menyalin dashboard terbaru ke folder docs\ (folder yang dibaca GitHub Pages),
    membuat ikon dan manifest agar bisa dipasang di layar utama ponsel, lalu
    commit dan push ke GitHub.

    Autentikasi GitHub harus Anda lakukan sendiri lebih dulu (lihat README).
    Skrip ini tidak pernah menyimpan atau meminta password/token.

.PARAMETER Push
    Lakukan git commit + push. Tanpa ini, hanya menyiapkan folder docs\ saja.

.PARAMETER Message
    Pesan commit. Default memakai tanggal-jam pembaruan.

.EXAMPLE
    .\Publish-Web.ps1                 # siapkan docs\ saja
    .\Publish-Web.ps1 -Push           # siapkan lalu unggah ke GitHub
#>
[CmdletBinding()]
param(
    [switch]$Push,
    [string]$Message = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$docs = Join-Path $root 'docs'
$src  = Join-Path $root 'output\index.html'

if (-not (Test-Path $src)) {
    throw "Dashboard belum dibuat. Jalankan .\Run-Screener.ps1 dulu."
}
if (-not (Test-Path $docs)) { New-Item -ItemType Directory -Path $docs -Force | Out-Null }

# --- 1. Salin dashboard ---
Copy-Item $src (Join-Path $docs 'index.html') -Force

# --- 2. Ikon aplikasi (dibuat sekali, dipakai untuk Add to Home Screen) ---
function New-AppIcon([int]$Size, [string]$Path) {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Latar gelap sesuai tema dashboard
    $bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(11, 15, 23))
    $g.FillRectangle($bg, 0, 0, $Size, $Size)

    # Grafik batang naik sederhana, warna hijau/cyan tema
    $bars = @(
        @{ x = 0.18; h = 0.26; c = [System.Drawing.Color]::FromArgb(6, 182, 212) },
        @{ x = 0.38; h = 0.45; c = [System.Drawing.Color]::FromArgb(6, 182, 212) },
        @{ x = 0.58; h = 0.62; c = [System.Drawing.Color]::FromArgb(34, 197, 94) },
        @{ x = 0.78; h = 0.80; c = [System.Drawing.Color]::FromArgb(34, 197, 94) }
    )
    $bw = [int]($Size * 0.13)
    foreach ($b in $bars) {
        $bh = [int]($Size * $b.h)
        $bx = [int]($Size * $b.x) - [int]($bw / 2)
        $by = $Size - $bh - [int]($Size * 0.14)
        $brush = New-Object System.Drawing.SolidBrush $b.c
        $g.FillRectangle($brush, $bx, $by, $bw, $bh)
        $brush.Dispose()
    }
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

foreach ($sz in @(180, 192, 512)) {
    $p = Join-Path $docs "icon-$sz.png"
    if (-not (Test-Path $p)) { New-AppIcon -Size $sz -Path $p }
}

# --- 3. Manifest PWA ---
$manifest = @'
{
  "name": "Screener Saham IDX",
  "short_name": "Screener IDX",
  "description": "Screener saham Indonesia: analisa fundamental dan teknikal otomatis.",
  "start_url": "./index.html",
  "display": "standalone",
  "background_color": "#0b0f17",
  "theme_color": "#0b0f17",
  "orientation": "portrait-primary",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" }
  ]
}
'@
[System.IO.File]::WriteAllText((Join-Path $docs 'manifest.json'), $manifest, (New-Object System.Text.UTF8Encoding $false))

# GitHub Pages jangan memproses file lewat Jekyll.
[System.IO.File]::WriteAllText((Join-Path $docs '.nojekyll'), '', (New-Object System.Text.UTF8Encoding $false))

$size = [Math]::Round((Get-Item (Join-Path $docs 'index.html')).Length / 1KB, 0)
Write-Host ''
Write-Host "  Folder docs\ siap ($size KB)" -ForegroundColor Green

# --- 4. Unggah ke GitHub ---
if (-not $Push) {
    Write-Host '  Jalankan dengan -Push untuk mengunggah ke GitHub.' -ForegroundColor DarkGray
    Write-Host ''
    return
}

Push-Location $root
try {
    if (-not (Test-Path (Join-Path $root '.git'))) {
        throw "Belum ada repositori git di sini. Ikuti langkah penyiapan di README."
    }
    $remote = ''
    try { $remote = (git remote get-url origin 2>$null) } catch { }
    if ([string]::IsNullOrWhiteSpace($remote)) {
        throw "Remote 'origin' belum diatur. Ikuti langkah penyiapan di README."
    }

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = "Perbarui screener " + (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }

    git add docs 2>&1 | Out-Null
    $status = git status --porcelain docs
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host '  Tidak ada perubahan untuk diunggah.' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    git commit -m $Message | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git commit gagal." }

    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    git push origin $branch
    if ($LASTEXITCODE -ne 0) {
        throw "git push gagal. Pastikan Anda sudah login ke GitHub (lihat README)."
    }

    Write-Host "  Terunggah ke GitHub (branch $branch)." -ForegroundColor Green
    $url = $remote -replace '\.git$', '' -replace '^git@github\.com:', 'https://github.com/'
    if ($url -match 'github\.com/([^/]+)/([^/]+)') {
        Write-Host "  Situs: https://$($Matches[1]).github.io/$($Matches[2])/" -ForegroundColor Cyan
    }
    Write-Host ''
}
finally { Pop-Location }
