# ExternalData.ps1 - Membaca data tambahan yang Anda ekspor sendiri dari aplikasi
# broker (BRIGHTS, dsb). Sepenuhnya opsional: kalau filenya tidak ada, screener
# jalan persis seperti biasa tanpa perubahan skor sama sekali.
#
# Letakkan file di folder  data\external\
#   foreign-flow.csv   -> net beli/jual asing per saham
#
# Format minimal (nama kolom fleksibel, lihat pemetaan di bawah):
#   Kode,NetAsing
#   BBCA,125000000000
#   ADRO,-45000000000
#
# Nilai POSITIF = asing net beli. NEGATIF = asing net jual.
# Satuan bebas (rupiah / juta / lot) asalkan konsisten - yang dipakai adalah
# peringkat relatif antar saham, bukan angka absolutnya.

function Get-ExternalDataDir {
    param([string]$Root)
    return (Join-Path $Root 'data\external')
}

function Read-FlexibleCsv {
    <# Membaca CSV lalu mencocokkan nama kolom secara longgar, supaya hasil ekspor
       dari berbagai aplikasi tetap bisa dipakai tanpa diedit manual. #>
    param([string]$Path, [string[]]$CodeNames, [string[]]$ValueNames)

    if (-not (Test-Path $Path)) { return $null }
    try { $rows = Import-Csv -Path $Path -ErrorAction Stop } catch { return $null }
    if ($null -eq $rows -or @($rows).Count -eq 0) { return $null }

    $cols = @($rows[0].PSObject.Properties.Name)
    function MatchCol($cands) {
        foreach ($c in $cols) {
            $norm = ($c -replace '[^A-Za-z]', '').ToLower()
            foreach ($cand in $cands) { if ($norm -eq $cand) { return $c } }
        }
        # Pencocokan longgar: nama kolom mengandung kata kunci.
        foreach ($c in $cols) {
            $norm = ($c -replace '[^A-Za-z]', '').ToLower()
            foreach ($cand in $cands) { if ($norm -like "*$cand*") { return $c } }
        }
        return $null
    }

    $cCode = MatchCol $CodeNames
    $cVal  = MatchCol $ValueNames
    if (-not $cCode -or -not $cVal) { return $null }

    $map = @{}
    foreach ($r in $rows) {
        $code = "$($r.$cCode)".Trim().ToUpper()
        if ([string]::IsNullOrWhiteSpace($code)) { continue }
        $code = $code -replace '\.JK$', ''
        # Bersihkan format angka Indonesia/Inggris: 1.234.567 atau 1,234,567 atau (123) untuk negatif
        $raw = "$($r.$cVal)".Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $neg = $false
        if ($raw -match '^\((.*)\)$') { $neg = $true; $raw = $Matches[1] }
        if ($raw -match '^-') { $neg = $true; $raw = $raw.TrimStart('-') }
        $clean = $raw -replace '[^0-9.,]', ''
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }

        # Angka bisa datang dalam gaya Indonesia (1.250.000.000) maupun Inggris
        # (1,250,000,000). Tentukan mana pemisah ribuan dan mana desimal.
        $dots   = ([regex]::Matches($clean, '\.')).Count
        $commas = ([regex]::Matches($clean, ',')).Count

        if ($dots -gt 0 -and $commas -gt 0) {
            # Yang muncul paling belakang adalah pemisah desimal.
            if ($clean.LastIndexOf(',') -gt $clean.LastIndexOf('.')) {
                $clean = ($clean -replace '\.', '') -replace ',', '.'
            } else {
                $clean = $clean -replace ',', ''
            }
        }
        elseif ($dots -gt 1)   { $clean = $clean -replace '\.', '' }   # 1.250.000.000
        elseif ($commas -gt 1) { $clean = $clean -replace ',', '' }    # 1,250,000,000
        elseif ($dots -eq 1) {
            # Satu titik diikuti tepat 3 digit pada nilai transaksi = pemisah ribuan.
            if ($clean -match '^\d+\.\d{3}$') { $clean = $clean -replace '\.', '' }
        }
        elseif ($commas -eq 1) {
            if ($clean -match '^\d+,\d{3}$') { $clean = $clean -replace ',', '' }
            else { $clean = $clean -replace ',', '.' }
        }

        # Selalu pakai InvariantCulture: kalau Windows-nya berlokal Indonesia,
        # TryParse bawaan akan salah menafsirkan titik dan koma.
        $val = 0.0
        $okNum = [double]::TryParse(
            $clean,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$val)
        if (-not $okNum) { continue }
        if ($neg) { $val = -$val }
        $map[$code] = $val
    }
    if ($map.Count -eq 0) { return $null }
    return $map
}

function Import-ForeignFlow {
    <# Membaca data net beli/jual asing hasil ekspor dari aplikasi broker. #>
    param([string]$Root)

    $path = Join-Path (Get-ExternalDataDir -Root $Root) 'foreign-flow.csv'
    $map = Read-FlexibleCsv -Path $path `
        -CodeNames @('kode', 'code', 'saham', 'stock', 'ticker', 'symbol', 'emiten') `
        -ValueNames @('netasing', 'asing', 'foreign', 'netforeign', 'foreignnet', 'net', 'nettrade', 'nilai')
    if ($null -eq $map) { return $null }

    # Skala relatif: dibandingkan terhadap nilai absolut terbesar dalam file,
    # supaya satuan apa pun (rupiah / juta / lot) tetap sebanding.
    $maxAbs = 0.0
    foreach ($v in $map.Values) { $a = [Math]::Abs($v); if ($a -gt $maxAbs) { $maxAbs = $a } }
    if ($maxAbs -le 0) { return $null }

    $age = $null
    try { $age = [int]((Get-Date) - (Get-Item $path).LastWriteTime).TotalDays } catch { }

    return [pscustomobject]@{
        Map      = $map
        MaxAbs   = $maxAbs
        Count    = $map.Count
        AgeDays  = $age
        Path     = $path
    }
}

function Get-ForeignFlowScore {
    <# Mengubah net asing jadi bonus/malus kecil (maksimal +/- 5 poin) plus catatan.
       Sengaja dibatasi kecil supaya tidak mendominasi analisa harga & fundamental. #>
    param($Flow, [string]$Code)

    $none = [pscustomobject]@{ Points = 0.0; Note = $null; Flag = $null; Value = $null; Rel = $null }
    if ($null -eq $Flow) { return $none }
    if (-not $Flow.Map.ContainsKey($Code)) { return $none }

    $v = [double]$Flow.Map[$Code]
    $rel = $v / $Flow.MaxAbs        # -1 .. +1
    $pts = 5.0 * $rel
    if ($pts -gt 5) { $pts = 5.0 }
    if ($pts -lt -5) { $pts = -5.0 }

    $note = $null; $flag = $null
    if ($rel -ge 0.20)      { $note = 'asing net beli cukup besar (data ekspor broker)' }
    elseif ($rel -le -0.20) { $flag = 'asing net jual cukup besar (data ekspor broker)' }

    return [pscustomobject]@{
        Points = [Math]::Round($pts, 2)
        Note   = $note
        Flag   = $flag
        Value  = $v
        Rel    = [Math]::Round($rel, 3)
    }
}
