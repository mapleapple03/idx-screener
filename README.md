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

Proses memindai ~193 saham dan memakan waktu sekitar **8–10 menit** (mengambil data
harian dan mingguan untuk tiap saham). Setelah selesai, dashboard terbuka otomatis
di browser.

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

Repositori git lokal **sudah disiapkan** beserta folder `docs\` (ikon, manifest,
dan dashboard). Tinggal 4 langkah yang **harus Anda lakukan sendiri** karena
menyangkut login akun GitHub:

### 1. Buat repositori kosong di GitHub

Buka <https://github.com/new>, isi nama misalnya `idx-screener`, lalu **Create
repository**. Jangan centang "Add a README" - repositori harus kosong.

> **Penting soal privasi:** GitHub Pages untuk akun gratis hanya jalan di
> repositori **public**, artinya situs dan kode bisa dilihat siapa saja yang tahu
> alamatnya. Isinya hanya data pasar publik dan hasil hitungan - tidak ada data
> akun, portofolio, atau saldo Anda. Kalau tetap ingin privat, GitHub Pages di
> repositori private butuh langganan GitHub Pro.

### 2. Hubungkan ke repositori lokal

Ganti `USERNAME` dengan username GitHub Anda:

```bash
git -C "C:\Users\siaha\Claude\idx-screener" remote add origin https://github.com/USERNAME/idx-screener.git
```

### 3. Unggah pertama kali

```bash
git -C "C:\Users\siaha\Claude\idx-screener" push -u origin main
```

Saat diminta login, akan muncul jendela **Git Credential Manager** - masuk lewat
browser di situ. Kredensial Anda tidak pernah melewati skrip mana pun.

### 4. Aktifkan GitHub Pages

Di repositori GitHub: **Settings** -> **Pages** -> bagian *Build and deployment*:

- Source: **Deploy from a branch**
- Branch: **main**, folder: **/docs**
- Klik **Save**

Tunggu 1-2 menit, situs aktif di:

```
https://USERNAME.github.io/idx-screener/
```

Buka alamat itu di HP maupun laptop.

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

Rasio Risk/Reward dihitung standar: `(TP1 − Harga) / (Harga − SL)`. Sinyal BUY dengan
RR di bawah 1,3 otomatis diturunkan menjadi PANTAU.

---

## Penyesuaian

**Menambah / menghapus saham** — edit `lib\Universe.ps1`, tulis kode tanpa akhiran `.JK`:

```powershell
$Global:IDX_UNIVERSE = @(
    'BBCA','BBRI','ANTM', 'KODEBARU'
)
```

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
  Install-Schedule.ps1   Pemasang jadwal otomatis
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
