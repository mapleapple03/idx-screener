<#
.SYNOPSIS
    Mengambil daftar LENGKAP saham yang tercatat di Bursa Efek Indonesia.

.DESCRIPTION
    Daftar diambil langsung dari Yahoo Finance screener (region Indonesia), lalu
    disimpan ke data\universe.json. Screener utama membaca file itu, sehingga
    saham yang baru IPO ikut terpindai tanpa perlu ditambahkan manual.

    Jalankan ulang sesekali (misal sebulan sekali) supaya emiten baru ikut masuk.

.PARAMETER MinMarketCap
    Saring saham dengan kapitalisasi pasar di bawah nilai ini (rupiah).
    Default 0 = ambil semua.

.EXAMPLE
    .\Update-Universe.ps1
    .\Update-Universe.ps1 -MinMarketCap 50000000000
#>
[CmdletBinding()]
param(
    [double]$MinMarketCap = 0
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $root 'lib\MarketData.ps1')

Write-Host ''
Write-Host '  Mengambil daftar lengkap saham IDX...' -ForegroundColor Cyan

if (-not (Initialize-YahooSession)) { throw 'Gagal menyiapkan sesi Yahoo.' }

$all = New-Object System.Collections.ArrayList
$offset = 0
$page = 250
$total = -1

while ($true) {
    $bodyObj = @{
        size = $page; offset = $offset
        sortField = 'intradaymarketcap'; sortType = 'DESC'; quoteType = 'EQUITY'
        query = @{ operator = 'AND'; operands = @(@{ operator = 'EQ'; operands = @('region', 'id') }) }
        userId = ''; userIdType = 'guid'
    }
    $body = $bodyObj | ConvertTo-Json -Depth 8

    $ok = $false
    for ($try = 0; $try -lt 3; $try++) {
        try {
            $resp = Invoke-WebRequest -Uri "https://query2.finance.yahoo.com/v1/finance/screener?crumb=$($Script:YCrumb)" `
                -WebSession $Script:YSession -UseBasicParsing -TimeoutSec 40 -UserAgent $Script:UA `
                -Method POST -Body $body -ContentType 'application/json' -ErrorAction Stop
            $j = $resp.Content | ConvertFrom-Json
            $res = $j.finance.result[0]
            if ($total -lt 0) { $total = [int]$res.total; Write-Host "  Total terdaftar: $total saham" -ForegroundColor Green }
            foreach ($q in $res.quotes) {
                $sym = "$($q.symbol)"
                if (-not $sym.EndsWith('.JK')) { continue }
                $code = $sym -replace '\.JK$', ''
                $mc = 0.0
                if ($null -ne $q.marketCap) { $mc = [double]$q.marketCap }
                if ($MinMarketCap -gt 0 -and $mc -gt 0 -and $mc -lt $MinMarketCap) { continue }
                [void]$all.Add([pscustomobject]@{
                    Code = $code
                    Name = "$($q.shortName)"
                    MarketCap = $mc
                })
            }
            $ok = $true
            break
        } catch {
            Start-Sleep -Milliseconds (900 * ($try + 1))
        }
    }
    if (-not $ok) { Write-Host "  Halaman offset $offset gagal, dilewati." -ForegroundColor Yellow }

    Write-Progress -Activity 'Mengambil daftar saham' -Status "$($all.Count) / $total" `
        -PercentComplete ([Math]::Min(100, [int](100 * $all.Count / [Math]::Max($total, 1))))

    $offset += $page
    if ($total -ge 0 -and $offset -ge $total) { break }
    if ($offset -gt 3000) { break }   # pengaman
    Start-Sleep -Milliseconds 250
}
Write-Progress -Activity 'Mengambil daftar saham' -Completed

# Screener Yahoo ternyata tidak selalu lengkap - beberapa emiten yang datanya
# tetap bisa diambil (mis. ZINC, WIKA) tidak muncul di sana. Jadi daftar cadangan
# ikut digabung supaya tidak ada saham yang hilang.
. (Join-Path $root 'lib\Universe.ps1')
$known = @($all | ForEach-Object { $_.Code })
$added = 0
foreach ($c in $Global:IDX_UNIVERSE_FALLBACK) {
    if ($known -notcontains $c) {
        [void]$all.Add([pscustomobject]@{ Code = $c; Name = ''; MarketCap = 0.0 })
        $added++
    }
}
if ($added -gt 0) { Write-Host "  Ditambah dari daftar cadangan: $added saham" -ForegroundColor DarkGray }

# Buang duplikat, urutkan berdasarkan kapitalisasi (besar dulu) agar saham penting
# terpindai lebih awal kalau proses dihentikan di tengah jalan.
$uniq = $all | Sort-Object Code -Unique | Sort-Object MarketCap -Descending

$payload = [pscustomobject]@{
    UpdatedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Count     = $uniq.Count
    Source    = 'Yahoo Finance screener (region=id)'
    Stocks    = @($uniq)
}

$dataDir = Join-Path $root 'data'
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$path = Join-Path $dataDir 'universe.json'
[System.IO.File]::WriteAllText($path, ($payload | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))

Write-Host ''
Write-Host "  Tersimpan: $($uniq.Count) saham -> $path" -ForegroundColor Green
$withMc = @($uniq | Where-Object { $_.MarketCap -gt 0 })
Write-Host "  Punya data kapitalisasi: $($withMc.Count)" -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Jalankan .\Run-Screener.ps1 untuk memindai semuanya.' -ForegroundColor Cyan
Write-Host ''
