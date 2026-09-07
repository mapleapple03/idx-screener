<#
.SYNOPSIS
    Menyiapkan screener di laptop BARU (pindah dari laptop lama).

.DESCRIPTION
    Jalankan skrip ini SETELAH meng-clone repositori di laptop baru.
    Skrip memeriksa semua prasyarat, membangun ulang data yang tidak ikut
    tersimpan di git, lalu memasang jadwal otomatis.

    Yang IKUT pindah lewat git : seluruh kode, dashboard, ikon
    Yang TIDAK ikut (dibuat ulang di sini):
      - data\universe.json  -> diambil ulang otomatis oleh skrip ini
      - data\latest.json    -> dibuat saat scan pertama
      - data\history\       -> arsip lama, tidak diperlukan
      - jadwal Windows      -> dipasang oleh skrip ini

.PARAMETER Time
    Jam scan harian (waktu lokal). Default 16:30.

.PARAMETER Extra
    Jam cadangan kedua. Disarankan mengisi ini, mis. "19:30", supaya kalau
    scan sore terputus (laptop ditutup) masih ada yang menyusul.

.EXAMPLE
    .\Setup-NewMachine.ps1
    .\Setup-NewMachine.ps1 -Time "16:30" -Extra "19:30"
#>
[CmdletBinding()]
param(
    [string]$Time = '16:30',
    [string]$Extra = '19:30'
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Say([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }
$gagal = $false

Say ''
Say '  ============================================================' DarkCyan
Say '   PENYIAPAN SCREENER DI LAPTOP BARU' Cyan
Say '  ============================================================' DarkCyan
Say ''

# --- 1. Prasyarat ---
Say '  [1/5] Memeriksa prasyarat...' Cyan

$psv = $PSVersionTable.PSVersion.Major
Say "        PowerShell $($PSVersionTable.PSVersion)" DarkGray

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) { Say '        git          : OK' Green }
else {
    Say '        git          : TIDAK ADA' Red
    Say '          Pasang dulu: winget install --id Git.Git' Yellow
    $gagal = $true
}

$gh = $null
foreach ($c in @((Get-Command gh -ErrorAction SilentlyContinue).Source,
                 "$env:ProgramFiles\GitHub CLI\gh.exe",
                 "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe",
                 "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe")) {
    if ($c -and (Test-Path $c)) { $gh = $c; break }
}
if ($gh) { Say '        GitHub CLI   : OK' Green }
else {
    Say '        GitHub CLI   : TIDAK ADA' Red
    Say '          Pasang dulu: winget install --id GitHub.cli' Yellow
    Say '          Lalu tutup & buka lagi PowerShell.' Yellow
    $gagal = $true
}

# Koneksi ke sumber data
try {
    Invoke-WebRequest -Uri 'https://query1.finance.yahoo.com/v8/finance/chart/BBCA.JK?range=1d&interval=1d' `
        -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop | Out-Null
    Say '        Data pasar    : OK' Green
} catch {
    Say '        Data pasar    : TIDAK BISA DIAKSES' Red
    Say "          $($_.Exception.Message)" DarkGray
    $gagal = $true
}

if ($gagal) {
    Say ''
    Say '  Perbaiki dulu yang bertanda TIDAK ADA, lalu jalankan ulang skrip ini.' Yellow
    Say ''
    return
}

# --- 2. Repositori ---
Say '  [2/5] Memeriksa repositori...' Cyan
if (-not (Test-Path (Join-Path $root '.git'))) {
    Say '        Folder ini bukan hasil clone git.' Red
    Say '        Clone dulu di laptop baru:' Yellow
    Say '          git clone https://github.com/mapleapple03/idx-screener.git' White
    Say ''
    return
}
$remote = ''
try { $remote = (git remote get-url origin) } catch { }
Say "        remote: $remote" DarkGray

# --- 3. Login GitHub ---
Say '  [3/5] Memeriksa login GitHub...' Cyan
& $gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say ''
    Say '        Belum login. Jalankan dulu (sekali saja):' Yellow
    Say ''
    Say '            gh auth login' Green
    Say ''
    Say '        Pilih: GitHub.com -> HTTPS -> Yes -> Login with a web browser' DarkGray
    Say '        Lalu jalankan lagi skrip ini.' Cyan
    Say ''
    return
}
$user = (& $gh api user --jq .login 2>$null)
Say "        Login sebagai: $user" Green
git config --global credential.helper manager 2>$null | Out-Null

# --- 4. Bangun ulang daftar saham ---
Say '  [4/5] Mengambil daftar saham (tidak ikut tersimpan di git)...' Cyan
$uni = Join-Path $root 'data\universe.json'
if (Test-Path $uni) {
    $u = Get-Content $uni -Raw | ConvertFrom-Json
    Say "        Sudah ada: $($u.Count) saham (diperbarui $($u.UpdatedAt))" DarkGray
} else {
    & (Join-Path $root 'Update-Universe.ps1') | Out-Null
    if (Test-Path $uni) {
        $u = Get-Content $uni -Raw | ConvertFrom-Json
        Say "        Terambil: $($u.Count) saham" Green
    } else {
        Say '        GAGAL mengambil daftar saham.' Red
        return
    }
}

# --- 5. Pasang jadwal ---
Say '  [5/5] Memasang jadwal otomatis...' Cyan
# Jangan pakai nama $args - itu variabel otomatis PowerShell dan splatting-nya
# tidak bekerja seperti yang diharapkan.
$schedArgs = @{ Publish = $true; Time = $Time }
if ($Extra) { $schedArgs['Extra'] = $Extra }
& (Join-Path $root 'Install-Schedule.ps1') @schedArgs | Out-Null
$t = Get-ScheduledTask -TaskName 'IDX Screener*' -ErrorAction SilentlyContinue
if ($t) {
    foreach ($x in $t) {
        $i = $x | Get-ScheduledTaskInfo
        Say ("        {0} -> berikutnya {1}" -f $x.TaskName, $i.NextRunTime) Green
    }
} else {
    Say '        Jadwal gagal dipasang.' Red
}

# --- Selesai ---
Say ''
Say '  ============================================================' DarkCyan
Say '   SIAP DIPAKAI' Green
Say '  ============================================================' DarkCyan
Say ''
Say '  Scan pertama (sekitar 20-50 menit, biarkan sampai selesai):' Cyan
Say '     .\Run-Screener.ps1 -Publish' White
Say ''
Say '  PENTING - matikan jadwal di LAPTOP LAMA:' Yellow
Say '     .\Install-Schedule.ps1 -Remove' White
Say ''
Say '  Kalau dua laptop sama-sama menjalankan jadwal, keduanya akan' DarkGray
Say '  mengunggah ke repositori yang sama dan salah satu push akan ditolak.' DarkGray
Say ''
if (Test-Path (Join-Path $root 'data\external\foreign-flow.csv')) {
    Say '  Data net asing ikut terbawa.' DarkGray
} else {
    Say '  Catatan: kalau di laptop lama ada data\external\foreign-flow.csv,' DarkGray
    Say '  salin manual ke sini - file itu sengaja tidak masuk git.' DarkGray
}
Say ''
