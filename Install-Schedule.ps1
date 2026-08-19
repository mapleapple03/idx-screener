<#
.SYNOPSIS
    Memasang jadwal otomatis agar screener memperbarui dirinya sendiri setiap hari bursa.

.DESCRIPTION
    Mendaftarkan Windows Scheduled Task yang menjalankan Run-Screener.ps1 pada
    jam tertentu, Senin sampai Jumat. Tidak butuh hak administrator karena tugas
    dijalankan atas nama pengguna yang sedang login.

.PARAMETER Time
    Jam eksekusi dalam format 24 jam (waktu LOKAL komputer). Default 16:30,
    yaitu setelah bursa IDX tutup (15:49 WIB) dan data harian sudah final.

.PARAMETER Extra
    Tambahkan jadwal kedua, misalnya sebelum pasar buka.

.PARAMETER Remove
    Hapus semua jadwal yang pernah dipasang.

.EXAMPLE
    .\Install-Schedule.ps1
    .\Install-Schedule.ps1 -Time "16:45"
    .\Install-Schedule.ps1 -Extra "08:30"
    .\Install-Schedule.ps1 -Remove
#>
[CmdletBinding()]
param(
    [string]$Time = '16:30',
    [string]$Extra = '',
    [switch]$Publish,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $root 'Run-Screener.ps1'
$taskMain  = 'IDX Screener - Update Harian'
$taskExtra = 'IDX Screener - Update Tambahan'

function Remove-IdxTask([string]$name) {
    $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($t) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Host "  Jadwal dihapus: $name" -ForegroundColor Yellow
        return $true
    }
    return $false
}

Write-Host ''
Write-Host '  === Penjadwal Otomatis Screener IDX ===' -ForegroundColor Cyan
Write-Host ''

if ($Remove) {
    $a = Remove-IdxTask $taskMain
    $b = Remove-IdxTask $taskExtra
    if (-not $a -and -not $b) { Write-Host '  Tidak ada jadwal yang terpasang.' -ForegroundColor DarkGray }
    Write-Host ''
    return
}

if (-not (Test-Path $script)) { throw "Run-Screener.ps1 tidak ditemukan di $root" }

# --- Peringatan zona waktu ---
$tz = [System.TimeZoneInfo]::Local
$offset = $tz.GetUtcOffset([DateTime]::Now).TotalHours
Write-Host "  Zona waktu komputer : $($tz.Id) (UTC$(if($offset -ge 0){'+'})$offset)"
if ([Math]::Abs($offset - 7) -gt 0.01) {
    Write-Host '  CATATAN: komputer Anda tidak di UTC+7 (WIB). Jam jadwal memakai waktu' -ForegroundColor Yellow
    Write-Host '           LOKAL komputer, jadi sesuaikan -Time agar jatuh setelah bursa tutup.' -ForegroundColor Yellow
}
Write-Host ''

$extraArgs = ''
if ($Publish) { $extraArgs = ' -Publish' }

function Register-IdxTask([string]$name, [string]$at, [string]$desc) {
    Remove-IdxTask $name | Out-Null
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -NoOpen$extraArgs" `
        -WorkingDirectory $root
    $trigger = New-ScheduledTaskTrigger -Weekly `
        -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday -At $at
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -DontStopOnIdleEnd `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 120) `
        -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
        -Settings $settings -Description $desc | Out-Null
    Write-Host "  Terpasang: $name  ->  setiap Senin-Jumat pukul $at" -ForegroundColor Green
}

try {
    Register-IdxTask $taskMain $Time 'Memperbarui screener saham IDX setelah bursa tutup.'
    if ($Extra) {
        Register-IdxTask $taskExtra $Extra 'Pembaruan tambahan screener saham IDX.'
    }

    Write-Host ''
    if ($Publish) {
        Write-Host '  Mode -Publish aktif: situs GitHub Pages ikut diperbarui tiap kali scan.' -ForegroundColor Cyan
    }
    Write-Host '  Screener akan berjalan otomatis di latar belakang.' -ForegroundColor Cyan
    Write-Host '  StartWhenAvailable aktif: kalau komputer mati saat jadwal, tugas' -ForegroundColor DarkGray
    Write-Host '  dijalankan begitu komputer menyala kembali.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Cek jadwal   : Get-ScheduledTask -TaskName "IDX Screener*"' -ForegroundColor DarkGray
    Write-Host "  Jalankan now : Start-ScheduledTask -TaskName `"$taskMain`"" -ForegroundColor DarkGray
    Write-Host '  Hapus jadwal : .\Install-Schedule.ps1 -Remove' -ForegroundColor DarkGray
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host "  GAGAL memasang jadwal: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Coba jalankan PowerShell sebagai Administrator, atau pasang manual' -ForegroundColor Yellow
    Write-Host '  lewat Task Scheduler dengan perintah:' -ForegroundColor Yellow
    Write-Host "    powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`" -NoOpen" -ForegroundColor DarkGray
    Write-Host ''
}
