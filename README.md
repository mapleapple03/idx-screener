# Screener Saham Indonesia (IDX)

Screener saham IDX otomatis: menganalisa **fundamental + teknikal**, memberi **alasan**,
menyusun **Stop Loss & Take Profit**, dan menentukan saham itu cocok untuk
**Day Trade, Swing Trade, atau Investasi**.

Berjalan sepenuhnya di komputer Anda. Tanpa instalasi Python/Node, tanpa API key,
tanpa langganan. Cukup PowerShell bawaan Windows.

---

## Cara Pakai

### Perbarui sekarang
Klik dua kali **`Update.bat`**.

Proses memindai **seluruh saham BEI (~845 emiten)** dan memakan waktu sekitar
**25–35 menit**. Setelah selesai, dashboard terbuka otomatis di browser.

Untuk uji cepat, batasi jumlahnya:

```bash
powershell -ExecutionPolicy Bypass -File .\Run-Screener.ps1 -Limit 30
```

Lewat PowerShell:

```bash
powershell -ExecutionPolicy Bypass -File .\Run-Screener.ps1
```

Pilihan lain:

```bash
powershell -ExecutionPolicy Bypass -File .\Run-Screener.ps1 -Limit 30 -NoOpen
```

| Parameter | Fungsi |
|---|---|
| `-Limit 30` | Hanya pindai 30 saham pertama (untuk uji coba cepat) |
| `-MinScore 60` | Hanya tampilkan saham dengan skor gabungan minimal 60 |
| `-NoOpen` | Jangan buka browser otomatis setelah selesai |

### Update otomatis setiap hari

```bash
powershell -ExecutionPolicy Bypass -File .\Install-Schedule.ps1
```

Memasang jadwal Windows Task Scheduler: **Senin–Jumat pukul 16:30** waktu lokal
komputer, yaitu setelah bursa IDX tutup (15:49 WIB) dan data harian sudah final.

```bash
powershell -ExecutionPolicy Bypass -File .\Install-Schedule.ps1 -Time "16:45" -Extra "08:30"
```

`-Extra` menambah jadwal kedua, misalnya sebelum pasar buka. Untuk mencabut jadwal:

```bash
powershell -ExecutionPolicy Bypass -File .\Install-Schedule.ps1 -Remove
```

Jika komputer sedang mati saat jadwal tiba, tugas otomatis dijalankan begitu
komputer menyala kembali (`StartWhenAvailable`).

---

---

## Akses dari HP & Laptop (GitHub Pages)

Dashboard bisa diterbitkan jadi situs web yang dibuka dari mana saja, dan ikut
diperbarui otomatis setiap kali screener jalan.

### Kenapa perlu GitHub?

Saat ini dashboard cuma ada sebagai file di laptop Anda. HP tidak bisa membukanya
karena file itu tidak punya alamat internet. GitHub menyimpan file tersebut di
komputer yang menyala 24 jam dan memberinya alamat web gratis, sehingga bisa
dibuka dari perangkat mana pun.

Alurnya: **laptop bikin dashboard -> unggah ke GitHub -> GitHub tampilkan sebagai
situs -> HP & laptop tinggal buka alamatnya.**

### Hanya 2 langkah

Repositori lokal, folder `docs\`, ikon, dan manifest **sudah disiapkan**.
Yang tersisa:

**Langkah 1 - login ke GitHub (sekali seumur hidup):**

```bash
gh auth login
```

Pilih jawaban: `GitHub.com` -> `HTTPS` -> `Yes` -> `Login with a web browser`.
Akan muncul kode 8 karakter (contoh `ABCD-1234`). Salin kode itu, tekan Enter,
lalu tempel di browser yang terbuka.

Kalau belum punya akun GitHub, daftar gratis dulu di <https://github.com/signup>.

**Langkah 2 - jalankan pemandu:**

```bash
powershell -ExecutionPolicy Bypass -File .\Setup-GitHub.ps1
```

Skrip ini otomatis membuat repositori, mengunggah file, menyalakan GitHub Pages,
lalu menampilkan alamat situs Anda. Tidak perlu membuka antarmuka web GitHub
sama sekali.

Situs aktif dalam 1-2 menit di:

```
https://USERNAME.github.io/idx-screener/
```

> **Penting soal privasi:** GitHub Pages untuk akun gratis hanya jalan di
> repositori **public**, artinya situs dan kode bisa dilihat siapa saja yang tahu
> alamatnya. Isinya hanya data pasar publik dan hasil hitungan - tidak ada data
> akun, portofolio, atau saldo Anda. Kalau tetap ingin privat, GitHub Pages di
> repositori private butuh langganan GitHub Pro.

### Pasang di layar utama HP

Situs sudah dilengkapi manifest dan ikon, jadi bisa dipasang seperti aplikasi:

- **Android (Chrome):** menu tiga titik -> *Add to Home screen*
- **iPhone (Safari):** tombol Share -> *Add to Home Screen*

Setelah dipasang, tampil layar penuh tanpa address bar.

### Update otomatis situs

Supaya situs ikut diperbarui tiap kali screener jalan, pasang ulang jadwal dengan
tambahan `-Publish`:

```bash
powershell -ExecutionPolicy Bypass -File .\Install-Schedule.ps1 -Publish
```

Atau perbarui manual kapan saja:

```bash
powershell -ExecutionPolicy Bypass -File .\Run-Screener.ps1 -Publish
```

Kalau unggah gagal (misal internet mati), hasil scan tetap tersimpan di `data\`
dan `output\` - kegagalan publish tidak pernah membatalkan hasil analisa.

---

## Isi Dashboard

Tiap saham ditampilkan sebagai kartu berisi:

- **Sinyal** — STRONG BUY / BUY / AKUMULASI / SPEKULATIF / PANTAU / HINDARI
- **Gaya trading** + perkiraan lama tahan posisi
- **Tiga skor** — Teknikal, Fundamental, dan Gabungan (0–100)
- **Rencana trading** — rentang Entry, Stop Loss, TP1, TP2, TP3, Risk/Reward
- **Alasan teknikal & fundamental** — mengapa saham ini masuk daftar
- **Risiko / catatan** — hal yang perlu diwaspadai
- **Metrik kunci** — PER, PBV, ROE, DER, RSI, ADX, ATR, rasio volume

Filter tersedia berdasarkan sinyal, gaya trading, sektor, pencarian kode, dan
enam pilihan pengurutan.

---

## Cara Kerja Penilaian

### Skor Teknikal (0–100)

| Komponen | Bobot | Isi |
|---|---|---|
| Struktur tren | 30 | Posisi harga terhadap EMA20/50/200 dan susunan MA |
| Momentum | 25 | MACD (garis, sinyal, histogram) + zona RSI |
| Kekuatan tren | 15 | ADX dan arah +DI / -DI |
| Konfirmasi volume | 15 | Volume vs rata-rata 20 hari + likuiditas rupiah |
| Kualitas entry | 15 | Jarak dari MA20, posisi di Bollinger, jarak ke puncak 52 minggu |

Ditambah bonus/malus **kekuatan relatif terhadap IHSG** selama 3 bulan.

Komponen yang datanya belum tersedia **dikeluarkan dari pembagi**, bukan dihitung nol.
Saham yang baru IPO belum punya MA50/MA200, dan menghukumnya karena itu sama saja
menilai saham baru selalu jelek. Untuk saham berdata lengkap hasilnya identik dengan
perhitungan biasa.

### Konfirmasi Tren Mingguan (multi-timeframe)

Selain data harian, screener juga mengambil **data mingguan** dan menilai arah tren di
timeframe besar (EMA10/EMA30 mingguan + RSI mingguan). Sinyal harian lalu dikoreksi:

- Tren mingguan **TURUN** -> sinyal beli diturunkan satu tingkat
  (STRONG BUY jadi BUY, BUY jadi SPEKULATIF, AKUMULASI jadi PANTAU)
- Tren mingguan **NAIK** + skor teknikal & fundamental kuat -> BUY bisa naik jadi STRONG BUY

Alasannya sederhana: sinyal harian yang melawan tren mingguan jauh lebih sering gagal.
Ini penyaring sinyal palsu yang paling efektif, terutama untuk swing trade.

### Support & Resistance Berbasis Volume

Level tidak lagi diambil dari titik pivot mentah. Screener membangun **profil volume**
(volume tiap bar disebar sepanjang rentang high-low-nya, dibagi 60 bin harga), lalu:

1. Pivot dengan volume tipis **disaring** - bekas sentuhan sekilas bukan level nyata
2. Dari yang tersisa, diambil yang **terdekat** dengan harga, karena rintangan terdekat
   yang akan ditemui lebih dulu
3. Resistance kedua wajib terpisah minimal 3% supaya tidak menunjuk level yang sama

Kekuatan tiap level ditampilkan dalam persen (`SupportStr` / `ResistStr`). Contoh nyata
pada BBRI: pivot lama di 3.980 dan 3.570 tersaring karena volumenya hanya ~11-13%,
sementara level 3.130 dengan volume 49% dipakai sebagai resistance sesungguhnya.

### Skor Fundamental (0–100)

Valuasi (PER, PBV) · Profitabilitas (ROE, ROA, margin bersih) · Pertumbuhan
(pendapatan, laba) · Kesehatan neraca (DER, current ratio) · Dividen.

Penilaian **sadar sektor**: bank tidak dinilai memakai DER dan current ratio karena
struktur neracanya memang berbeda. Ambang ROA dan margin juga disesuaikan untuk bank.
Metrik yang datanya kosong **tidak menghukum skor** — bobot dinormalisasi ulang ke
metrik yang tersedia, dan persentase kelengkapan data disimpan di field `FundCover`.

### Gaya Trading

| Gaya | Syarat utama | Lama tahan |
|---|---|---|
| **Day Trade** | Likuiditas tinggi (> Rp 20 M/hari), ATR >= 2%, volume ramai | Intraday – 2 hari |
| **Swing Trade** | ADX >= 18, ATR 1,5–6%, MA20 > MA50, tidak overextended | 3 – 15 hari bursa |
| **Investasi** | Fundamental >= 58, harga di atas MA200, volatilitas rendah | 3 bulan ke atas |

### Stop Loss & Take Profit

Basis SL berbeda tiap gaya:

- **Day Trade** — di bawah low hari ini dikurangi 0,2 ATR; risiko dibatasi ~3,5%
- **Swing Trade** — di bawah swing low terakhir; risiko dibatasi ~8%
- **Investasi** — di bawah MA50 atau 3x ATR

Jarak stop **minimum** mengikuti gaya (0,6 / 1,0 / 1,5 x ATR) supaya tidak mudah kena
goyangan harga biasa. Batas risiko di atas bersifat lunak: pada saham yang sangat
volatil, 1x ATR bisa lebih lebar dari batas tersebut, dan stop tetap dilebarkan
mengikuti ATR — memasang stop lebih ketat dari volatilitas normal saham justru
hampir pasti kena. Karena itu ada saham swing dengan risiko di atas 8%; itu sinyal
bahwa sahamnya memang liar, bukan kesalahan hitung.

Target memakai kelipatan risiko (2R / 3,5R), namun bila ada **resistance terdekat**
di bawah target tersebut, TP1 dipindah ke resistance itu karena lebih realistis —
inilah sebabnya sebagian saham menampilkan RR di bawah 2.

Seluruh level dibulatkan ke **fraksi harga resmi IDX** (Rp1 / 2 / 5 / 10 / 25
tergantung rentang harga), sehingga order benar-benar bisa dipasang di pasar.

Rasio Risk/Reward dihitung standar: `(TP1 − Harga) / (Harga − SL)`.

### Biaya Transaksi (hasil bersih)

Untung yang terlihat di layar belum tentu untung di rekening. Screener ikut
menghitung **biaya transaksi Pluang untuk saham Indonesia**: **0,15% saat beli**
dan **0,25% saat jual** (sudah termasuk PPN, PPh, Levy BEI/KSEI, dan biaya KPEI).
Sumber: <https://pluang.com/biaya/id-stocks>.

Tiap saham menampilkan:

- **Bersih TP1 / TP2** — persentase untung setelah semua biaya
- **Impas** — harga jual minimum agar tidak rugi
- **RR bersih** — risk/reward sesungguhnya setelah biaya

Sinyal BUY dengan **RR bersih di bawah 1,2** otomatis diturunkan jadi PANTAU, dan
kalau biaya memakan 25% ke atas dari potensi untung TP1, muncul catatan risiko.

Ini penting terutama untuk day trade: target 4% yang kelihatan bagus bisa menyusut
jadi RR bersih di bawah 1, artinya potensi untungnya tidak lagi sepadan dengan risiko.

Pakai broker lain? Ubah `$Global:FEE_BUY_PCT` dan `$Global:FEE_SELL_PCT` di
`lib\Analysis.ps1`.

---

## Data Tambahan dari Aplikasi Broker (opsional)

Screener bisa menerima data **net beli/jual asing** yang Anda ekspor sendiri dari
aplikasi broker (BRIGHTS, dsb). Ini data yang tidak tersedia gratis di mana pun,
dan termasuk sinyal paling berguna di pasar Indonesia.

**Cara pakai:**

1. Di aplikasi broker, ekspor data net asing ke CSV atau Excel
   (kalau hasilnya Excel, simpan ulang jadi `.csv`)
2. Simpan sebagai `data\external\foreign-flow.csv`
3. Jalankan screener seperti biasa

Contoh isi file (lihat `data\external\foreign-flow.contoh.csv`):

```
Kode,NetAsing
BBCA,1.250.000.000
BBRI,(45.000.000)
ADRO,88500000
```

**Nama kolom fleksibel.** Kode saham dikenali dari `Kode`, `Code`, `Stock`,
`Ticker`, `Symbol`, atau `Emiten`. Nilainya dari `NetAsing`, `Asing`, `Foreign`,
`Net`, `Nilai`, dan sejenisnya. Akhiran `.JK`, huruf kecil, dan spasi ikut dibersihkan.

**Format angka bebas.** Gaya Indonesia (`1.250.000.000`), gaya Inggris
(`1,250,000,000`), negatif dengan minus (`-45000`) maupun kurung (`(45.000)`)
semuanya terbaca. Nilai positif = asing net beli, negatif = asing net jual.

**Satuan tidak masalah** (rupiah, juta, atau lot) asalkan konsisten di dalam satu
file, karena yang dipakai adalah peringkat relatif antar saham.

**Pengaruhnya dibatasi maksimal +/- 5 poin** pada skor teknikal, supaya tidak
menenggelamkan analisa harga dan fundamental. Saham yang tidak ada di file
**sama sekali tidak terpengaruh**, dan kalau filenya tidak ada, screener jalan
persis seperti biasa. Kalau file lebih tua dari 7 hari, muncul peringatan agar
diekspor ulang.

### Kenapa tidak otomatis ambil dari aplikasi broker?

Aplikasi BRIGHTS Easy adalah program Java dengan browser Chromium tertanam; datanya
datang dari server BRI Danareksa lewat sesi login Anda. Ada tiga penghalang:

1. Tidak ada cara mengendalikan aplikasi desktop Windows dari sini
2. Foldernya hanya berisi tata letak jendela dan konfigurasi akun, bukan data pasar
3. Jalur yang tersisa berarti mengambil token login dari aplikasi - itu penanganan
   kredensial, dan tetap tidak menyelesaikan masalah karena tugas terjadwal jam
   16:30 berjalan tanpa ada orang yang bisa login

Ekspor manual mengatasi ketiganya sekaligus. Data seperti net asing tetap berguna
berhari-hari, jadi cukup diekspor seminggu sekali.

## Penyesuaian

**Daftar saham** — secara default screener memindai **seluruh emiten BEI**
(sekitar 845 saham) dari `data\universe.json`. Perbarui daftarnya sesekali supaya
emiten yang baru IPO ikut masuk:

```bash
powershell -ExecutionPolicy Bypass -File .\Update-Universe.ps1
```

Daftar diambil dari Yahoo Finance screener (region Indonesia) lalu digabung dengan
daftar cadangan di `lib\Universe.ps1`. Penggabungan ini perlu karena screener Yahoo
ternyata melewatkan beberapa emiten (mis. ZINC, WIKA, FASW, HITS, INTA) yang datanya
sebenarnya tetap bisa diambil.

Kalau hanya ingin memindai saham berkapitalisasi besar supaya lebih cepat:

```bash
powershell -ExecutionPolicy Bypass -File .\Update-Universe.ps1 -MinMarketCap 1000000000000
```

Untuk memindai daftar pilihan sendiri, edit daftar cadangan di `lib\Universe.ps1`
lalu hapus `data\universe.json`.

**Mengubah ambang penilaian** — edit `lib\Analysis.ps1`:

- `Get-FundamentalScore` — bobot dan ambang tiap rasio
- `Get-TechnicalScore` — bobot tiap komponen teknikal
- `Get-TradingStyle` — syarat Day Trade / Swing / Investasi
- `Get-TradePlan` — rumus SL dan TP
- `Get-Signal` — ambang STRONG BUY / BUY / dst

**Mengubah tampilan** — edit CSS dan JavaScript di `lib\Report.ps1`.

---

## Struktur Berkas

```
idx-screener/
  Run-Screener.ps1       Program utama
  Update.bat             Klik dua kali untuk memperbarui
  Update-Universe.ps1    Ambil daftar lengkap emiten BEI
  Install-Schedule.ps1   Pemasang jadwal otomatis
  Setup-GitHub.ps1       Pemandu penyiapan situs web
  Publish-Web.ps1        Penerbit situs ke GitHub Pages
  docs/                  Isi situs web (dibaca GitHub Pages)
    index.html           Dashboard versi web
    manifest.json        Agar bisa dipasang di layar utama HP
    icon-*.png           Ikon aplikasi
  lib/
    Universe.ps1         Daftar saham yang dipindai
    MarketData.ps1       Pengambilan data + kalender sesi bursa
    Indicators.ps1       Matematika indikator teknikal
    Analysis.ps1         Skoring, gaya trading, rencana SL/TP
    Report.ps1           Pembuat dashboard HTML
  data/
    latest.json          Hasil terakhir (bisa dipakai program lain)
    history/             60 snapshot terakhir, untuk melacak perubahan
  output/
    index.html           Dashboard
```

`data\latest.json` sengaja dibuat rapi agar bisa diolah lebih lanjut, misalnya
dibandingkan antar hari untuk melihat saham yang sinyalnya baru berubah.

---

## Sumber Data & Keterbatasan

Data harga dan rasio keuangan diambil dari **Yahoo Finance** (endpoint publik, tanpa
API key). Yang perlu disadari:

- **Bukan data real-time.** Harga Yahoo untuk IDX umumnya terlambat ~15 menit.
- **Saat sesi masih berjalan**, harga penutupan hari itu belum final. Screener
  mendeteksi ini, memproyeksikan volume ke satu hari penuh agar perbandingan adil,
  dan menampilkan peringatan di dashboard. **Hasil paling akurat didapat setelah
  bursa tutup.**
- **Rasio fundamental bersifat trailing** (12 bulan terakhir) dan bisa tertinggal dari
  laporan keuangan terbaru. Beberapa saham lapis dua/tiga datanya tidak lengkap.
- **Aksi korporasi, berita, dan suspensi tidak diperhitungkan.** Saham yang disuspensi
  akan gagal diambil datanya dan dilewati begitu saja.
- Analisa memakai data harian. Tidak ada data intraday per menit, jadi sinyal
  "Day Trade" berarti *karakternya cocok untuk day trade* (likuid dan volatil),
  bukan sinyal masuk pada menit tertentu.

## Kenapa tidak terhubung ke Pluang atau IDX?

Keduanya sudah dicoba dan tertutup untuk skrip:

- `trade.pluang.com` adalah halaman login (judulnya "Masuk ke Pluang Web Trading"),
  dan `api.pluang.com` membalas **403 Forbidden**. Tidak ada data pasar yang bisa
  diambil tanpa masuk ke akun broker Anda.
- Endpoint resmi `idx.co.id` (`GetStockSummary`, `GetCompanyProfiles`) juga membalas
  **403** karena dilindungi proteksi bot.

Memasukkan kredensial akun broker ke dalam skrip bukan hal yang aman, jadi screener ini
memakai data pasar publik untuk analisa. Eksekusi order tetap Anda lakukan sendiri lewat
aplikasi Pluang.

**Saham baru IPO** tetap bisa dianalisa (minimal 30 hari bursa), tapi ditandai badge
"SAHAM BARU" di dashboard dan tidak pernah diberi sinyal STRONG BUY, karena tren jangka
panjangnya memang belum bisa diketahui. Contoh: BACH (IPO 8 Juli 2026).

---

## Peringatan Risiko

Alat ini adalah **screener berbasis rumus**, bukan rekomendasi atau nasihat investasi.
Seluruh skor, sinyal, stop loss, dan take profit dihitung otomatis dari data harga
historis serta rasio keuangan publik. Alat ini tidak mengetahui berita, aksi korporasi,
laporan keuangan terbaru, maupun kondisi keuangan dan toleransi risiko Anda.

Skor tinggi **tidak menjamin harga akan naik**. Gunakan sebagai penyaring awal untuk
mempersempit daftar, lalu lakukan riset sendiri sebelum bertransaksi. Selalu pakai
stop loss dan atur ukuran posisi sesuai kemampuan menanggung rugi. Risiko kerugian
ditanggung sepenuhnya oleh Anda.
