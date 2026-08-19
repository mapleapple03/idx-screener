<#
.SYNOPSIS
    Pemandu penyiapan GitHub Pages untuk screener (langkah 2 dan 3).

.DESCRIPTION
    Skrip ini menanyakan username GitHub Anda, menghubungkan repositori lokal ke
    GitHub, lalu mengunggahnya. Anda tidak perlu mengetik perintah git manual.

    Skrip TIDAK PERNAH meminta atau menyimpan password/token. Login dilakukan
    lewat jendela browser milik Git Credential Manager.

    Sebelum menjalankan ini, pastikan repositori KOSONG sudah dibuat di
    https://github.com/new (langkah 1).

.EXAMPLE
    .\Setup-GitHub.ps1
#>
[CmdletBinding()]
param(
    [string]$Username = '',
    [string]$RepoName = 'idx-screener'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Say([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }

Say ''
Say '  ============================================================' DarkCyan
Say '   PENYIAPAN GITHUB PAGES - SCREENER SAHAM IDX' Cyan
Say '  ============================================================' DarkCyan
Say ''

# --- Pemeriksaan awal ---
if (-not (Test-Path (Join-Path $root '.git'))) {
    Say '  Repositori git belum ada di folder ini.' Red
    return
}
if (-not (Test-Path (Join-Path $root 'docs\index.html'))) {
    Say '  Folder docs\ belum siap. Jalankan dulu:' Yellow
    Say '    .\Run-Screener.ps1' DarkGray
    return
}

Say '  Sebelum lanjut, pastikan Anda SUDAH membuat repositori kosong di:' Yellow
Say '    https://github.com/new' White
Say '  (nama: ' -NoNewline; Say $RepoName -NoNewline White; Say ', JANGAN centang "Add a README")'
Say ''

# --- Username ---
while ([string]::IsNullOrWhiteSpace($Username) -or $Username -eq 'USERNAME') {
    $Username = (Read-Host '  Ketik username GitHub Anda').Trim()
    if ($Username -eq 'USERNAME') {
        Say '  Itu masih contoh, bukan username asli Anda. Coba lagi.' Red
        $Username = ''
    }
    elseif ($Username -match '[^A-Za-z0-9\-]') {
        Say '  Username GitHub hanya boleh huruf, angka, dan tanda minus.' Red
        $Username = ''
    }
}

$url = "https://github.com/$Username/$RepoName.git"
Say ''
Say "  Akan dihubungkan ke: $url" Cyan
$ok = (Read-Host '  Sudah benar? (y/n)').Trim().ToLower()
if ($ok -ne 'y') { Say '  Dibatalkan.' Yellow; return }

# --- Pasang remote (ganti kalau sudah ada) ---
$existing = ''
try { $existing = (git remote get-url origin 2>$null) } catch { }
if (-not [string]::IsNullOrWhiteSpace($existing)) {
    Say "  Remote lama dihapus: $existing" DarkGray
    git remote remove origin
}
git remote add origin $url
Say '  Remote terpasang.' Green

# --- Pastikan docs\ ikut ter-commit ---
git add -A 2>&1 | Out-Null
$dirty = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    git commit -q -m ("Perbarui screener " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    Say '  Perubahan terbaru ikut disimpan.' Green
}

# --- Unggah ---
Say ''
Say '  Mengunggah ke GitHub...' Cyan
Say '  Kalau muncul jendela login, pilih "Sign in with your browser".' DarkGray
Say ''

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
git push -u origin $branch

if ($LASTEXITCODE -ne 0) {
    Say ''
    Say '  Unggah GAGAL. Penyebab yang paling sering:' Red
    Say '   1. Repositori belum dibuat di GitHub -> buka https://github.com/new' Yellow
    Say "   2. Nama repositori beda -> pastikan namanya persis '$RepoName'" Yellow
    Say '   3. Username salah ketik' Yellow
    Say '   4. Login dibatalkan -> jalankan ulang skrip ini' Yellow
    Say ''
    Say '  Perbaiki lalu jalankan lagi: .\Setup-GitHub.ps1' DarkGray
    Say ''
    return
}

Say ''
Say '  ============================================================' DarkCyan
Say '   BERHASIL DIUNGGAH' Green
Say '  ============================================================' DarkCyan
Say ''
Say '  LANGKAH TERAKHIR - aktifkan GitHub Pages (sekali saja):' Yellow
Say ''
Say "   1. Buka  https://github.com/$Username/$RepoName/settings/pages" White
Say '   2. Bagian "Build and deployment":' White
Say '        Source : Deploy from a branch' DarkGray
Say "        Branch : $branch    Folder: /docs" DarkGray
Say '   3. Klik Save, lalu tunggu 1-2 menit.' White
Say ''
Say '  Setelah itu situs Anda aktif di:' Cyan
Say "    https://$Username.github.io/$RepoName/" Green
Say ''
Say '  Buka alamat itu di HP, lalu:' Cyan
Say '    Android (Chrome) : menu titik tiga -> Add to Home screen' DarkGray
Say '    iPhone (Safari)  : tombol Share -> Add to Home Screen' DarkGray
Say ''
Say '  Supaya situs ikut diperbarui otomatis tiap hari bursa:' Cyan
Say '    .\Install-Schedule.ps1 -Publish' DarkGray
Say ''
