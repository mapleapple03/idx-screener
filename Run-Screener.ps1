<#
.SYNOPSIS
    Screener Saham Indonesia (IDX) - analisa fundamental + teknikal otomatis.

.DESCRIPTION
    Mengambil data harga & fundamental untuk seluruh saham di lib\Universe.ps1,
    menghitung skor teknikal dan fundamental, menentukan gaya trading yang cocok
    (Day Trade / Swing Trade / Investasi), lalu menyusun rencana entry, stop loss,
    dan take profit yang sudah dibulatkan ke fraksi harga resmi IDX.

    Hasil disimpan ke data\latest.json dan dashboard output\index.html.

.PARAMETER Limit
    Batasi jumlah saham yang di-scan (untuk uji coba cepat).

.PARAMETER MinScore
    Skor gabungan minimum agar saham masuk dashboard. Default 0 (tampilkan semua).

.PARAMETER NoOpen
    Jangan buka dashboard otomatis setelah selesai.

.PARAMETER Publish
    Setelah selesai, salin dashboard ke folder docs\ lalu unggah ke GitHub
    sehingga situs web ikut diperbarui. Butuh login GitHub (lihat README).

.EXAMPLE
    .\Run-Screener.ps1
    .\Run-Screener.ps1 -Limit 20 -NoOpen
#>
[CmdletBinding()]
param(
    [int]$Limit = 0,
    [double]$MinScore = 0,
    [switch]$NoOpen,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $root 'lib\Universe.ps1')
. (Join-Path $root 'lib\MarketData.ps1')
. (Join-Path $root 'lib\Indicators.ps1')
. (Join-Path $root 'lib\Analysis.ps1')
. (Join-Path $root 'lib\ExternalData.ps1')
. (Join-Path $root 'lib\Report.ps1')

$startTime = Get-Date

Write-Host ''
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host '   SCREENER SAHAM INDONESIA (IDX)' -ForegroundColor Cyan
Write-Host '   Analisa Fundamental + Teknikal' -ForegroundColor DarkGray
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ''

# --- Siapkan sesi data ---
Write-Host '  Menyiapkan koneksi data pasar...' -NoNewline
$ok = Initialize-YahooSession
if ($ok) { Write-Host ' OK' -ForegroundColor Green }
else { Write-Host ' GAGAL (fundamental mungkin kosong)' -ForegroundColor Yellow }

# --- Ambil data IHSG sebagai pembanding kekuatan relatif ---
Write-Host '  Mengambil data IHSG (benchmark)...' -NoNewline
$benchRet3m = $null
try {
    $bh = Get-PriceHistory -Symbol $Global:IDX_BENCHMARK -Range '1y'
    if ($null -ne $bh -and $bh.Count -gt 65) {
        $benchRet3m = 100.0 * ($bh.Close[-1] - $bh.Close[-64]) / $bh.Close[-64]
        Write-Host (' OK (3 bulan: {0:N1}%)' -f $benchRet3m) -ForegroundColor Green
    } else { Write-Host ' data kurang' -ForegroundColor Yellow }
} catch { Write-Host ' gagal, kekuatan relatif dilewati' -ForegroundColor Yellow }

# --- Data tambahan hasil ekspor dari aplikasi broker (opsional) ---
$foreignFlow = Import-ForeignFlow -Root $root
if ($null -ne $foreignFlow) {
    $umur = ''
    if ($null -ne $foreignFlow.AgeDays) { $umur = " (umur data $($foreignFlow.AgeDays) hari)" }
    Write-Host "  Data net asing dimuat: $($foreignFlow.Count) saham$umur" -ForegroundColor Green
    if ($null -ne $foreignFlow.AgeDays -and $foreignFlow.AgeDays -gt 7) {
        Write-Host '  Data asing sudah lebih dari seminggu, sebaiknya diekspor ulang.' -ForegroundColor Yellow
    }
} else {
    Write-Host '  Data net asing tidak ada (opsional) - analisa jalan tanpa itu.' -ForegroundColor DarkGray
}

# Seberapa jauh sesi bursa hari ini berjalan - dipakai untuk menormalkan volume intraday.
$sessionProgress = Get-IdxSessionProgress
if ($sessionProgress -gt 0 -and $sessionProgress -lt 0.98) {
    Write-Host ('  Sesi bursa sedang berjalan ({0:N0}%). Volume hari ini diproyeksikan ke satu hari penuh.' -f ($sessionProgress * 100)) -ForegroundColor Yellow
}

$tickers = $Global:IDX_UNIVERSE
if ($Limit -gt 0 -and $Limit -lt $tickers.Count) { $tickers = $tickers[0..($Limit - 1)] }

Write-Host ''
Write-Host "  Memindai $($tickers.Count) saham..." -ForegroundColor Cyan
Write-Host ''

$results = New-Object System.Collections.ArrayList
$failed  = New-Object System.Collections.ArrayList
$idx = 0

foreach ($code in $tickers) {
    $idx++
    $sym = "$code.JK"
    $pct = [int](100 * $idx / $tickers.Count)
    Write-Progress -Activity 'Memindai saham IDX' -Status "$code ($idx/$($tickers.Count))" -PercentComplete $pct

    try {
        $hist = Get-PriceHistory -Symbol $sym -Range '2y'
        if ($null -eq $hist) { [void]$failed.Add($code); continue }

        $C = $hist.Close; $H = $hist.High; $L = $hist.Low; $V = $hist.Volume
        $n = $C.Count
        $px = $C[$n - 1]
        $barIsToday = Test-BarIsToday -UnixTs $hist.Timestamp[$n - 1]

        # ---------- Indikator ----------
        $ema20  = Get-EMA -Data $C -Period 20
        $ema50  = Get-EMA -Data $C -Period 50
        $ema200 = Get-EMA -Data $C -Period 200
        $rsi    = Get-RSI -Close $C -Period 14
        $atrA   = Get-ATR -High $H -Low $L -Close $C -Period 14
        $macd   = Get-MACD -Close $C
        $adx    = Get-ADX -High $H -Low $L -Close $C -Period 14
        $bb     = Get-Bollinger -Close $C -Period 20 -Mult 2.0
        $stoch  = Get-Stochastic -High $H -Low $L -Close $C -Period 14
        # Profil volume: dipakai agar level support/resistance yang dipilih adalah
        # level yang benar-benar ramai diperdagangkan, bukan sekadar titik pivot.
        $vprof  = Get-VolumeProfile -High $H -Low $L -Volume $V -Lookback 120 -Bins 60
        $sr     = Get-SupportResistance -High $H -Low $L -Price $px -Lookback 120 -Wing 3 -Profile $vprof

        # Konfirmasi timeframe mingguan. Bar mingguan dirangkum dari data harian
        # yang sudah diunduh, jadi tidak menambah request ke server sama sekali.
        $wk     = ConvertTo-WeeklyBars -Hist $hist
        $weekly = Get-WeeklyTrend -Weekly $wk

        $atr    = Get-LastValid $atrA
        $e20    = Get-LastValid $ema20
        $bbUp   = Get-LastValid $bb.Upper
        $bbLo   = Get-LastValid $bb.Lower

        # Volume rata-rata 20 hari + nilai transaksi harian (rupiah).
        # Bar hari ini dikecualikan dari rata-rata supaya pembandingnya adalah hari penuh.
        $volSum = 0.0; $valSum = 0.0; $cnt = 0
        $avgEnd = $n
        if ($barIsToday) { $avgEnd = $n - 1 }
        for ($i = [Math]::Max(0, $avgEnd - 20); $i -lt $avgEnd; $i++) {
            $volSum += $V[$i]; $valSum += ($V[$i] * $C[$i]); $cnt++
        }
        $avgVol = 0.0; $avgValue = 0.0
        if ($cnt -gt 0) { $avgVol = $volSum / $cnt; $avgValue = $valSum / $cnt }

        # Kalau sesi masih berjalan, volume hari ini baru sebagian. Proyeksikan ke
        # volume satu hari penuh supaya perbandingannya adil.
        $volRatio = $null
        if ($avgVol -gt 0) {
            $todayVol = $V[$n - 1]
            if ($barIsToday -and $sessionProgress -lt 0.98) {
                $todayVol = $todayVol / [Math]::Max($sessionProgress, 0.2)
            }
            $volRatio = $todayVol / $avgVol
        }

        $hi52 = Get-Highest -Data $H -Lookback 252
        $lo52 = Get-Lowest  -Data $L -Lookback 252

        # Posisi harga dalam pita Bollinger (0 = pita bawah, 1 = pita atas).
        $bbPos = $null
        if ($null -ne $bbUp -and $null -ne $bbLo -and ($bbUp - $bbLo) -gt 0) {
            $bbPos = ($px - $bbLo) / ($bbUp - $bbLo)
        }
        # Seberapa jauh harga meregang dari MA20.
        $ext = $null
        if ($null -ne $e20 -and $e20 -gt 0) { $ext = 100.0 * ($px - $e20) / $e20 }

        # Kekuatan relatif terhadap IHSG (3 bulan).
        $rel = $null
        if ($null -ne $benchRet3m -and $n -gt 65) {
            $stockRet = 100.0 * ($px - $C[$n - 64]) / $C[$n - 64]
            $rel = $stockRet - $benchRet3m
        }

        $chg1d = 0.0
        if ($n -gt 1 -and $C[$n - 2] -gt 0) { $chg1d = 100.0 * ($px - $C[$n - 2]) / $C[$n - 2] }
        $todayRangePct = 0.0
        if ($px -gt 0) { $todayRangePct = 100.0 * ($H[$n - 1] - $L[$n - 1]) / $px }

        # ---------- Fundamental ----------
        $f = $null
        try { $f = Get-Fundamentals -Symbol $sym } catch { $f = $null }
        if ($null -eq $f) {
            $f = [pscustomobject]@{
                Name = $hist.Name; ShortName = $code; Sector = $null; Industry = $null
                MarketCap = $null; PER = $null; ForwardPER = $null; PBV = $null; EPS = $null
                ROE = $null; ROA = $null; NetMargin = $null; OpMargin = $null; DER = $null
                CurrentRatio = $null; RevGrowth = $null; EarnGrowth = $null; DivYield = $null
                PayoutRatio = $null; FreeCashflow = $null; TotalCash = $null; TotalDebt = $null; Beta = $null
            }
        }

        # ---------- Rakit snapshot teknikal ----------
        $T = [pscustomobject]@{
            Price          = $px
            EMA20          = $e20
            EMA50          = Get-LastValid $ema50
            EMA200         = Get-LastValid $ema200
            RSI            = Get-LastValid $rsi
            ATR            = $atr
            ATRPct         = $(if ($null -ne $atr -and $px -gt 0) { 100.0 * $atr / $px } else { $null })
            MACD           = Get-LastValid $macd.MACD
            MACDSignal     = Get-LastValid $macd.Signal
            MACDHist       = Get-LastValid $macd.Histogram
            MACDHistPrev   = Get-LastValid $macd.Histogram -Back 1
            ADX            = Get-LastValid $adx.ADX
            PlusDI         = Get-LastValid $adx.PlusDI
            MinusDI        = Get-LastValid $adx.MinusDI
            StochK         = Get-LastValid $stoch.K
            StochD         = Get-LastValid $stoch.D
            BBUpper        = $bbUp
            BBLower        = $bbLo
            BBPos          = $bbPos
            BBWidth        = Get-LastValid $bb.Bandwidth
            VolRatio       = $volRatio
            AvgVolume      = $avgVol
            AvgValue       = $avgValue
            ExtensionPct   = $ext
            High52w        = $hi52
            Low52w         = $lo52
            PctFrom52wHigh = $(if ($hi52 -gt 0) { 100.0 * ($hi52 - $px) / $hi52 } else { $null })
            RelStrength    = $rel
            TodayLow       = $L[$n - 1]
            TodayHigh      = $H[$n - 1]
            TodayRangePct  = $todayRangePct
            SwingLow       = Get-SwingLow -Low $L -Lookback 10
            Support        = $sr.Support
            Resistance     = $sr.Resistance
            Resistance2    = $sr.Resistance2
            DivYield       = $f.DivYield
            Change1D       = $chg1d
        }

        # ---------- Skoring ----------
        $fs = Get-FundamentalScore -Fund $f -Sector $f.Sector
        $ts = Get-TechnicalScore -T $T

        # Aliran dana asing (opsional, dari ekspor aplikasi broker). Pengaruhnya
        # dibatasi maksimal +/- 5 poin supaya tidak menenggelamkan analisa utama.
        $ff = Get-ForeignFlowScore -Flow $foreignFlow -Code $code
        $techFinal = [Math]::Max(0, [Math]::Min(100, $ts.Score + $ff.Points))

        $style = Get-TradingStyle -T $T -FundScore $fs.Score
        $plan  = Get-TradePlan -T $T -Style $style.Primary
        # Di bawah 120 bar, MA50/MA200 belum terbentuk penuh sehingga gambaran
        # tren jangka panjang belum bisa diandalkan.
        $limited = ($n -lt 120)
        $sig   = Get-Signal -Tech $techFinal -Fund $fs.Score -Plan $plan -LimitedData $limited -Weekly $weekly

        # ---------- Alasan naratif ----------
        $reasonTech = @($ts.Notes) | Where-Object { $_ }
        $reasonFund = @($fs.Notes) | Where-Object { $_ }
        $risks      = @(@($ts.Flags) + @($fs.Flags)) | Where-Object { $_ }

        # Catatan tren mingguan: yang positif jadi alasan, yang negatif jadi risiko.
        if ($null -ne $weekly -and $weekly.Available -and $weekly.Note) {
            if ($weekly.Trend -eq 'NAIK') { $reasonTech = @($reasonTech) + @($weekly.Note) }
            else                          { $risks      = @($risks)      + @($weekly.Note) }
        }
        # Catatan aliran dana asing (skornya sudah dihitung di atas).
        if ($ff.Note) { $reasonTech = @($reasonTech) + @($ff.Note) }
        if ($ff.Flag) { $risks      = @($risks)      + @($ff.Flag) }

        # Support yang didukung volume tebal layak disebut.
        if ($null -ne $sr.Support -and $sr.SupportStrength -ge 55) {
            $reasonTech = @($reasonTech) + @("support {0:N0} didukung volume tebal (kekuatan {1}%)" -f $sr.Support, $sr.SupportStrength)
        }
        if ($null -ne $sr.Resistance -and $sr.ResistanceStrength -ge 65) {
            $risks = @($risks) + @("resistance {0:N0} banyak volume tertahan di situ, bisa jadi penghambat" -f $sr.Resistance)
        }
        if ($limited) {
            $risks = @($risks) + @("riwayat harga baru $n hari bursa - MA50/MA200 belum terbentuk, analisa tren jangka panjang belum bisa diandalkan")
        }

        $nameFinal = $f.Name
        if ([string]::IsNullOrWhiteSpace($nameFinal)) { $nameFinal = $hist.Name }
        if ([string]::IsNullOrWhiteSpace($nameFinal)) { $nameFinal = $code }

        $rec = [pscustomobject]@{
            Code        = $code
            Name        = $nameFinal
            Sector      = $(if ($f.Sector) { $f.Sector } else { 'Lainnya' })
            Price       = [Math]::Round($px, 2)
            Change1D    = [Math]::Round($chg1d, 2)
            Signal      = $sig.Signal
            Combined    = $sig.Combined
            TechScore   = [Math]::Round($techFinal, 1)
            ForeignRel  = $ff.Rel
            ForeignPts  = $ff.Points
            FundScore   = $fs.Score
            FundCover   = $fs.Coverage
            Style       = $style.Primary
            HoldPeriod  = $style.HoldPeriod
            BarCount    = $n
            DataLimited = $limited
            DayScore    = $style.DayScore
            SwingScore  = $style.SwingScore
            PosScore    = $style.PosScore

            EntryLow    = $plan.EntryLow
            EntryHigh   = $plan.EntryHigh
            StopLoss    = $plan.StopLoss
            TP1         = $plan.TP1
            TP2         = $plan.TP2
            TP3         = $plan.TP3
            RiskPct     = $plan.RiskPct
            RewardPct   = $plan.RewardPct
            RR          = $plan.RRRatio
            SLBasis     = $plan.SLBasis
            TPBasis     = $plan.TPBasis

            RSI         = $(if ($null -ne $T.RSI) { [Math]::Round($T.RSI, 1) } else { $null })
            ADX         = $(if ($null -ne $T.ADX) { [Math]::Round($T.ADX, 1) } else { $null })
            ATRPct      = $(if ($null -ne $T.ATRPct) { [Math]::Round($T.ATRPct, 2) } else { $null })
            MACDHist    = $(if ($null -ne $T.MACDHist) { [Math]::Round($T.MACDHist, 2) } else { $null })
            VolRatio    = $(if ($null -ne $T.VolRatio) { [Math]::Round($T.VolRatio, 2) } else { $null })
            AvgValueBn  = [Math]::Round($avgValue / 1e9, 2)
            EMA20       = $(if ($null -ne $T.EMA20) { [Math]::Round($T.EMA20, 2) } else { $null })
            EMA50       = $(if ($null -ne $T.EMA50) { [Math]::Round($T.EMA50, 2) } else { $null })
            EMA200      = $(if ($null -ne $T.EMA200) { [Math]::Round($T.EMA200, 2) } else { $null })
            Support     = $T.Support
            Resistance  = $T.Resistance
            SupportStr  = $sr.SupportStrength
            ResistStr   = $sr.ResistanceStrength
            WeeklyTrend = $(if ($null -ne $weekly -and $weekly.Available) { $weekly.Trend } else { 'TIDAK DIKETAHUI' })
            High52w     = [Math]::Round($hi52, 2)
            Low52w      = [Math]::Round($lo52, 2)
            RelStrength = $(if ($null -ne $rel) { [Math]::Round($rel, 1) } else { $null })

            PER         = $(if ($null -ne $f.PER) { [Math]::Round($f.PER, 2) } else { $null })
            PBV         = $(if ($null -ne $f.PBV) { [Math]::Round($f.PBV, 2) } else { $null })
            ROE         = $(if ($null -ne $f.ROE) { [Math]::Round($f.ROE * 100, 2) } else { $null })
            DER         = $(if ($null -ne $f.DER) { [Math]::Round($f.DER, 1) } else { $null })
            NetMargin   = $(if ($null -ne $f.NetMargin) { [Math]::Round($f.NetMargin * 100, 2) } else { $null })
            RevGrowth   = $(if ($null -ne $f.RevGrowth) { [Math]::Round($f.RevGrowth * 100, 1) } else { $null })
            EarnGrowth  = $(if ($null -ne $f.EarnGrowth) { [Math]::Round($f.EarnGrowth * 100, 1) } else { $null })
            DivYield    = $(if ($null -ne $f.DivYield) { [Math]::Round($f.DivYield * 100, 2) } else { $null })
            MarketCapT  = $(if ($null -ne $f.MarketCap) { [Math]::Round($f.MarketCap / 1e12, 2) } else { $null })

            ReasonTech  = $reasonTech
            ReasonFund  = $reasonFund
            Risks       = $risks
        }

        [void]$results.Add($rec)

        # Umpan balik ringkas di konsol.
        $col = 'Gray'
        switch ($rec.Signal) {
            'STRONG BUY' { $col = 'Green' }
            'BUY'        { $col = 'Green' }
            'AKUMULASI'  { $col = 'Cyan' }
            'SPEKULATIF' { $col = 'Yellow' }
            'PANTAU'     { $col = 'DarkGray' }
            'HINDARI'    { $col = 'DarkRed' }
        }
        $line = '   {0,-6} {1,10:N0}  T:{2,5:N1} F:{3,5:N1}  {4,-11} {5}' -f `
            $rec.Code, $rec.Price, $rec.TechScore, $rec.FundScore, $rec.Signal, $rec.Style
        Write-Host $line -ForegroundColor $col
    }
    catch {
        [void]$failed.Add($code)
        Write-Host ("   {0,-6} gagal: {1}" -f $code, $_.Exception.Message) -ForegroundColor DarkRed
    }

    Start-Sleep -Milliseconds 120   # jeda sopan agar tidak kena rate limit
}

Write-Progress -Activity 'Memindai saham IDX' -Completed

# --- Urutkan & saring ---
$sorted = $results | Where-Object { $_.Combined -ge $MinScore } | Sort-Object -Property Combined -Descending

$elapsed = ((Get-Date) - $startTime).TotalSeconds
$stamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$payload = [pscustomobject]@{
    GeneratedAt   = $stamp
    GeneratedUnix = [int][double]::Parse((Get-Date -UFormat %s))
    TotalScanned  = $results.Count
    TotalFailed   = $failed.Count
    SessionPct    = [Math]::Round($sessionProgress * 100, 0)
    IsIntraday    = ($sessionProgress -gt 0 -and $sessionProgress -lt 0.98)
    FailedTickers = @($failed)
    BenchReturn3M = $(if ($null -ne $benchRet3m) { [Math]::Round($benchRet3m, 2) } else { $null })
    ElapsedSec    = [Math]::Round($elapsed, 1)
    Stocks        = @($sorted)
}

# --- Simpan hasil ---
$dataDir = Join-Path $root 'data'
$histDir = Join-Path $dataDir 'history'
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Path $histDir -Force | Out-Null }

$json = $payload | ConvertTo-Json -Depth 6
$latestPath = Join-Path $dataDir 'latest.json'
$histPath   = Join-Path $histDir ('screener-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.json')
[System.IO.File]::WriteAllText($latestPath, $json, (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($histPath,   $json, (New-Object System.Text.UTF8Encoding $false))

# Simpan maksimal 60 snapshot terakhir.
Get-ChildItem -Path $histDir -Filter 'screener-*.json' |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 60 |
    ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }

# --- Bangun dashboard ---
$outDir = Join-Path $root 'output'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$htmlPath = Join-Path $outDir 'index.html'
New-ScreenerReport -Payload $payload -OutputPath $htmlPath

# --- Ringkasan ---
$buy = @($sorted | Where-Object { $_.Signal -eq 'STRONG BUY' -or $_.Signal -eq 'BUY' })
Write-Host ''
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ("   Selesai dalam {0:N0} detik  |  {1} saham dianalisa  |  {2} gagal" -f $elapsed, $results.Count, $failed.Count) -ForegroundColor Cyan
Write-Host ("   Sinyal BUY / STRONG BUY: {0} saham" -f $buy.Count) -ForegroundColor Green
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ''

if ($buy.Count -gt 0) {
    Write-Host '   TOP PILIHAN HARI INI' -ForegroundColor Green
    $top = $buy | Select-Object -First 10
    foreach ($s in $top) {
        Write-Host ('   {0,-6} {1,-12} skor {2,5:N1}  entry {3:N0}-{4:N0}  SL {5:N0}  TP1 {6:N0}  RR {7:N2}' -f `
            $s.Code, $s.Style, $s.Combined, $s.EntryLow, $s.EntryHigh, $s.StopLoss, $s.TP1, $s.RR) -ForegroundColor White
    }
    Write-Host ''
}

Write-Host "   Data   : $latestPath" -ForegroundColor DarkGray
Write-Host "   Laporan: $htmlPath" -ForegroundColor DarkGray
Write-Host ''

# --- Terbitkan ke web (opsional) ---
# Kegagalan publish tidak boleh membatalkan hasil scan yang sudah benar.
if ($Publish) {
    $pub = Join-Path $root 'Publish-Web.ps1'
    if (Test-Path $pub) {
        try { & $pub -Push }
        catch {
            Write-Host "   Publish ke web gagal: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host '   Hasil scan tetap tersimpan di data\ dan output\.' -ForegroundColor DarkGray
        }
    }
}

if (-not $NoOpen) { Start-Process $htmlPath }
