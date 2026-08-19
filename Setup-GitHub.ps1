<#
.SYNOPSIS
    Pemandu otomatis: bikin repositori GitHub, unggah, dan nyalakan situs web.

.DESCRIPTION
    Skrip ini mengerjakan semuanya untuk Anda:
      1. Membuat repositori di GitHub
      2. Mengunggah isi folder screener
      3. Menyalakan GitHub Pages (situs web)
      4. Menampilkan alamat situs Anda

    Yang harus Anda lakukan sendiri hanya satu: login ke GitHub lebih dulu dengan
    perintah  gh auth login  (login lewat browser, aman).

    Skrip TIDAK PERNAH meminta atau menyimpan password/token Anda.

.PARAMETER RepoName
    Nama repositori. Default: idx-screener

.PARAMETER Private
    Buat repositori privat. CATATAN: GitHub Pages di repositori privat butuh
    langganan GitHub Pro. Untuk akun gratis, biarkan publik.

.EXAMPLE
    .\Setup-GitHub.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoName = 'idx-screener',
    [switch]$Private
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Say([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }
function Head([string]$t) {
    Say ''
    Say '  ============================================================' DarkCyan
    Say "   $t" Cyan
    Say '  ============================================================' DarkCyan
    Say ''
}

Head 'PENYIAPAN SITUS SCREENER SAHAM IDX'

# --- Cari gh.exe (PATH kadang belum ter-refresh setelah instal) ---
$gh = $null
$cand = @(
    (Get-Command gh -ErrorAction SilentlyContinue).Source,
    "$env:ProgramFiles\GitHub CLI\gh.exe",
    "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe",
    "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
)
foreach ($c in $cand) { if ($c -and (Test-Path $c)) { $gh = $c; break } }

if (-not $gh) {
    Say '  GitHub CLI belum terpasang. Pasang dulu dengan:' Red
    Say '    winget install --id GitHub.cli' White
    Say '  Lalu tutup dan buka lagi PowerShell, jalankan skrip ini lagi.' DarkGray
    Say ''
    return
}

# --- Pemeriksaan folder ---
if (-not (Test-Path (Join-Path $root '.git'))) { Say '  Repositori git belum ada di folder ini.' Red; return }
if (-not (Test-Path (Join-Path $root 'docs\index.html'))) {
    Say '  Dashboard belum dibuat. Jalankan dulu:' Yellow
    Say '    .\Run-Screener.ps1' White
    Say ''
    return
}

# --- 1. Cek login ---
Say '  [1/4] Memeriksa login GitHub...' Cyan
& $gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say ''
    Say '  Anda belum login ke GitHub.' Yellow
    Say ''
    Say '  Jalankan perintah ini dulu (sekali saja):' White
    Say ''
    Say '      gh auth login' Green
    Say ''
    Say '  Saat ditanya, pilih jawaban berikut:' White
    Say '      What account do you want to log into?  -> GitHub.com' DarkGray
    Say '      What is your preferred protocol?       -> HTTPS' DarkGray
    Say '      Authenticate Git with your credentials?-> Yes' DarkGray
    Say '      How would you like to authenticate?    -> Login with a web browser' DarkGray
    Say ''
    Say '  Nanti muncul kode 8 karakter (contoh ABCD-1234). Salin kode itu,' DarkGray
    Say '  tekan Enter, lalu tempel di browser yang terbuka. Selesai.' DarkGray
    Say ''
    Say '  Setelah itu jalankan lagi: .\Setup-GitHub.ps1' Cyan
    Say ''
    return
}

$user = (& $gh api user --jq .login 2>$null)
if ([string]::IsNullOrWhiteSpace($user)) { Say '  Gagal membaca akun GitHub Anda.' Red; return }
Say "        Login sebagai: $user" Green

# --- 2. Buat repositori kalau belum ada ---
Say '  [2/4] Menyiapkan repositori...' Cyan
$full = "$user/$RepoName"
& $gh repo view $full 2>&1 | Out-Null
$repoExists = ($LASTEXITCODE -eq 0)

if ($repoExists) {
    Say "        Repositori $full sudah ada, dipakai ulang." DarkGray
} else {
    $vis = '--public'
    if ($Private) { $vis = '--private' }
    & $gh repo create $RepoName $vis --description 'Screener saham IDX: analisa fundamental dan teknikal otomatis' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Say "        Gagal membuat repositori $full." Red; return }
    Say "        Repositori $full dibuat." Green
}

# --- Pasang remote ---
$existing = ''
try { $existing = (git remote get-url origin 2>$null) } catch { }
$want = "https://github.com/$full.git"
if ($existing -ne $want) {
    if (-not [string]::IsNullOrWhiteSpace($existing)) { git remote remove origin 2>&1 | Out-Null }
    git remote add origin $want 2>&1 | Out-Null
}

# --- 3. Unggah ---
Say '  [3/4] Mengunggah file...' Cyan
git add -A 2>&1 | Out-Null
$dirty = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    git commit -q -m ("Perbarui screener " + (Get-Date -Format 'yyyy-MM-dd HH:mm')) 2>&1 | Out-Null
}
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
git push -u origin $branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say '        Unggah gagal. Coba jalankan manual untuk lihat pesannya:' Red
    Say "          git push -u origin $branch" White
    Say ''
    return
}
Say "        Terunggah ke branch $branch." Green

# --- 4. Nyalakan GitHub Pages ---
Say '  [4/4] Menyalakan situs web (GitHub Pages)...' Cyan
$body = '{"source":{"branch":"' + $branch + '","path":"/docs"}}'
$tmp = Join-Path $env:TEMP 'idx-pages.json'
[System.IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding $false))

$out = & $gh api -X POST "repos/$full/pages" --input $tmp 2>&1
$code = $LASTEXITCODE

if ($code -ne 0 -and "$out" -match '409|already exists') {
    # Pages sudah pernah dinyalakan. Belum tentu foldernya benar - kalau
    # sumbernya bukan /docs, situsnya akan 404. Jadi perbaiki lewat PUT.
    $cur = & $gh api "repos/$full/pages" --jq '.source.path' 2>$null
    if ("$cur".Trim() -ne '/docs') {
        Say "        Sumber situs masih '$cur', diperbaiki ke /docs..." Yellow
        & $gh api -X PUT "repos/$full/pages" --input $tmp 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Say '        Sumber situs diperbaiki.' Green; $code = 0 }
    } else {
        Say '        Situs sudah aktif dengan folder yang benar.' DarkGray
        $code = 0
    }
}
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

if ($code -ne 0) {
    Say '        Otomatis gagal. Nyalakan manual (sekali saja):' Yellow
    Say "          https://github.com/$full/settings/pages" White
    Say '          Source: Deploy from a branch' DarkGray
    Say "          Branch: $branch   Folder: /docs   -> Save" DarkGray
} elseif ("$out" -notmatch '409|already exists') {
    Say '        Situs dinyalakan.' Green
}

# --- Selesai ---
$site = "https://$user.github.io/$RepoName/"
Head 'SELESAI'
Say '  Alamat situs Anda:' Cyan
Say "     $site" Green
Say ''
Say '  Situs butuh 1-2 menit untuk aktif pertama kali.' DarkGray
Say '  Kalau masih 404, tunggu sebentar lalu muat ulang.' DarkGray
Say ''
Say '  Buka alamat itu di HP, lalu pasang seperti aplikasi:' Cyan
Say '     Android (Chrome) : menu titik tiga -> Add to Home screen' DarkGray
Say '     iPhone (Safari)  : tombol Share    -> Add to Home Screen' DarkGray
Say ''
Say '  Agar situs ikut diperbarui otomatis tiap hari bursa:' Cyan
Say '     .\Install-Schedule.ps1 -Publish' White
Say ''
