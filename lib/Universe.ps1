# Universe.ps1 - Daftar saham IDX yang di-screen.
#
# Secara default screener memakai daftar LENGKAP hasil .\Update-Universe.ps1
# yang tersimpan di data\universe.json (semua emiten yang tercatat di BEI).
# Kalau file itu belum ada, dipakai daftar cadangan di bawah ini.
#
# Tambah/hapus kode saham di daftar cadangan sesuai kebutuhan (tanpa akhiran .JK).

$Global:IDX_UNIVERSE_FALLBACK = @(
    # --- Perbankan & Keuangan ---
    'BBCA','BBRI','BMRI','BBNI','BRIS','BBTN','BNGA','BJBR','BJTM','ARTO',
    'BTPS','BDMN','NISP','PNBN','MEGA','BBHI','AGRO','BANK','BBKP','BFIN',
    'ADMF','PNLF','PANS','AMAR',

    # --- Konsumer & Ritel ---
    'ICBP','INDF','UNVR','MYOR','KLBF','SIDO','ULTJ','CPIN','JPFA','MAIN',
    'GOOD','CMRY','ROTI','TSPC','KAEF','DVLA','ACES','MAPI','MAPA','RALS',
    'LPPF','ERAA','AMRT','MIDI','CSAP','HOKI','WIIM','GGRM','HMSP','KINO',

    # --- Kesehatan ---
    'MIKA','HEAL','SILO','PRDA','SRAJ','OMED',

    # --- Telekomunikasi, Media & Teknologi ---
    'TLKM','EXCL','ISAT','TOWR','TBIG','MTEL','GOTO','BUKA','EMTK','MNCN',
    'SCMA','DCII','MLPT','WIFI','LINK','DMMX','MTDL','ELIT',

    # --- Energi & Batubara ---
    'ADRO','PTBA','ITMG','INDY','HRUM','BUMI','BYAN','ADMR','GEMS','MBAP',
    'TOBA','DOID','PTRO','RAJA','MEDC','PGAS','ELSA','AKRA','ENRG','DSSA',
    'CUAN','BREN','RATU','CDIA','PGEO',

    # --- Logam & Pertambangan ---
    'ANTM','INCO','TINS','MDKA','NCKL','BRMS','PSAB','AMMN','HRTA','ZINC',
    'IFSH','SMMT',

    # --- Industri Dasar & Kimia ---
    'BRPT','TPIA','INTP','SMGR','SMBR','AMFG','ARNA','MARK','ESSA','AVIA',
    'TKIM','INKP','FASW','CPRO','ISSP','KRAS',

    # --- Properti & Konstruksi ---
    'BSDE','CTRA','SMRA','PWON','LPKR','ASRI','DMAS','MDLN','APLN','KIJA',
    'SSIA','WIKA','PTPP','ADHI','WTON','TOTL','JKON','PANI','BEST',

    # --- Infrastruktur & Transportasi ---
    'JSMR','CMNP','IPCC','BIRD','ASSA','SMDR','TMAS','HITS','PSSI',
    'GIAA','NELY','BULL','SOCI','TAXI',

    # --- Otomotif & Industri ---
    'ASII','AUTO','GJTL','IMAS','SMSM','BRAM','UNTR','HEXA','INTA',
    'ARNA','KOBX',

    # --- Agri & Perkebunan ---
    'AALI','LSIP','SIMP','SGRO','DSNG','TBLA','SSMS','ANJT','BWPT','CSRA',

    # --- Aneka ---
    'MLBI','SMAR','TAPG','STAA','FILM','MSIN','BOGA','NASI','BACH'
) | Select-Object -Unique

function Get-IdxUniverse {
    <# Ambil daftar lengkap dari data\universe.json kalau ada, kalau tidak pakai
       daftar cadangan. Mengembalikan array kode saham tanpa akhiran .JK. #>
    param([string]$Root)

    $path = Join-Path $Root 'data\universe.json'
    if (Test-Path $path) {
        try {
            $u = Get-Content $path -Raw | ConvertFrom-Json
            $codes = @($u.Stocks | ForEach-Object { $_.Code } | Where-Object { $_ })
            if ($codes.Count -gt 0) {
                $Global:IDX_UNIVERSE_SOURCE = "daftar lengkap ($($codes.Count) saham, diperbarui $($u.UpdatedAt))"
                return $codes
            }
        } catch { }
    }
    $Global:IDX_UNIVERSE_SOURCE = "daftar cadangan ($($Global:IDX_UNIVERSE_FALLBACK.Count) saham) - jalankan .\Update-Universe.ps1 untuk daftar lengkap"
    return $Global:IDX_UNIVERSE_FALLBACK
}

# Indeks acuan pasar (IHSG) untuk analisa kekuatan relatif.
$Global:IDX_BENCHMARK = '^JKSE'
