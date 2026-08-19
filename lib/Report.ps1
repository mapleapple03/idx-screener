# Report.ps1 - Membangun dashboard HTML mandiri (tanpa koneksi internet saat dibuka).

function New-ScreenerReport {
    param($Payload, [string]$OutputPath)

    $json = $Payload | ConvertTo-Json -Depth 6 -Compress
    # Cegah string "</script>" di dalam data merusak halaman.
    $json = $json.Replace('</', '<\/')

    # Here-string literal: tanda $ di dalam CSS/JS tidak diinterpolasi PowerShell.
    $template = @'
<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Screener Saham IDX</title>
<meta name="description" content="Screener saham IDX: analisa fundamental dan teknikal otomatis.">
<meta name="theme-color" content="#0b0f17">
<!-- Supaya bisa dipasang di layar utama ponsel (Add to Home Screen) -->
<link rel="manifest" href="manifest.json">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="icon" type="image/png" href="icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Screener IDX">
<style>
:root{
  --bg:#0b0f17; --panel:#121826; --panel2:#171f30; --line:#243149;
  --tx:#e6edf7; --tx2:#9aa8bf; --tx3:#66748e;
  --green:#22c55e; --greenbg:#0d2c1b; --red:#ef4444; --redbg:#2c1113;
  --amber:#f59e0b; --amberbg:#2e2109; --blue:#3b82f6; --bluebg:#0e1d38;
  --cyan:#06b6d4; --violet:#8b5cf6;
}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--tx);font:14px/1.5 "Segoe UI",system-ui,-apple-system,sans-serif;padding:20px}
.wrap{max-width:1500px;margin:0 auto}

header{border-bottom:1px solid var(--line);padding-bottom:16px;margin-bottom:18px}
h1{font-size:21px;font-weight:650;letter-spacing:-.3px}
h1 span{color:var(--cyan)}
.sub{color:var(--tx3);font-size:12.5px;margin-top:4px}

.stats{display:flex;gap:10px;flex-wrap:wrap;margin-top:14px}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:9px;padding:9px 14px;min-width:104px}
.stat .k{font-size:10.5px;color:var(--tx3);text-transform:uppercase;letter-spacing:.6px}
.stat .v{font-size:19px;font-weight:650;margin-top:2px}

.controls{display:flex;gap:9px;flex-wrap:wrap;align-items:center;margin:16px 0 6px}
input[type=text],select{background:var(--panel);border:1px solid var(--line);color:var(--tx);
  padding:8px 11px;border-radius:8px;font-size:13px;outline:none}
input[type=text]{min-width:210px}
input[type=text]:focus,select:focus{border-color:var(--blue)}
.chips{display:flex;gap:6px;flex-wrap:wrap}
.chip{background:var(--panel);border:1px solid var(--line);color:var(--tx2);padding:7px 13px;
  border-radius:999px;font-size:12.5px;cursor:pointer;user-select:none;transition:.13s}
.chip:hover{border-color:var(--blue);color:var(--tx)}
.chip.on{background:var(--blue);border-color:var(--blue);color:#fff;font-weight:600}
.count{color:var(--tx3);font-size:12.5px;margin:10px 0 14px}

.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(430px,1fr));gap:14px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:13px;padding:16px;
  display:flex;flex-direction:column;gap:12px}
.card.buy{border-color:#1d5f38}
.card.strong{border-color:var(--green);box-shadow:0 0 0 1px rgba(34,197,94,.14)}
.card.avoid{opacity:.62}

.chead{display:flex;justify-content:space-between;align-items:flex-start;gap:10px}
.code{font-size:19px;font-weight:700;letter-spacing:-.2px}
.cname{color:var(--tx3);font-size:11.5px;margin-top:1px;max-width:250px;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.csec{color:var(--tx3);font-size:10.5px;margin-top:3px}
.pr{text-align:right;white-space:nowrap}
.px{font-size:19px;font-weight:650}
.chg{font-size:12px;font-weight:600;margin-top:1px}
.up{color:var(--green)} .down{color:var(--red)} .flat{color:var(--tx3)}

.badges{display:flex;gap:6px;flex-wrap:wrap}
.b{padding:4px 10px;border-radius:6px;font-size:11px;font-weight:700;letter-spacing:.3px}
.b-strong{background:var(--green);color:#04140a}
.b-buy{background:var(--greenbg);color:var(--green);border:1px solid #1d5f38}
.b-akum{background:var(--bluebg);color:#60a5fa;border:1px solid #1e3a6b}
.b-spek{background:var(--amberbg);color:var(--amber);border:1px solid #6b4a09}
.b-pantau{background:var(--panel2);color:var(--tx2);border:1px solid var(--line)}
.b-hindari{background:var(--redbg);color:var(--red);border:1px solid #6b1d20}
.b-style{background:var(--panel2);color:var(--violet);border:1px solid #3b2d63}
.b-baru{background:var(--amberbg);color:var(--amber);border:1px solid #6b4a09}

.scores{display:flex;gap:14px}
.sc{flex:1}
.sc .lbl{display:flex;justify-content:space-between;font-size:10.5px;color:var(--tx3);
  text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px}
.sc .lbl b{color:var(--tx);font-size:12px}
.bar{height:6px;background:var(--panel2);border-radius:3px;overflow:hidden}
.bar i{display:block;height:100%;border-radius:3px}

.plan{background:var(--panel2);border:1px solid var(--line);border-radius:10px;padding:12px}
.plan .ttl{font-size:10.5px;color:var(--tx3);text-transform:uppercase;letter-spacing:.7px;
  margin-bottom:9px;display:flex;justify-content:space-between;align-items:center}
.plan .ttl em{font-style:normal;color:var(--violet);font-weight:600}
.lv{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.lv div{background:var(--bg);border:1px solid var(--line);border-radius:7px;padding:7px 9px}
.lv .n{font-size:9.5px;color:var(--tx3);text-transform:uppercase;letter-spacing:.5px}
.lv .p{font-size:14.5px;font-weight:650;margin-top:2px}
.lv .d{font-size:10px;margin-top:1px}
.sl .p{color:var(--red)} .tp .p{color:var(--green)} .en .p{color:var(--tx)}
.rr{display:flex;gap:14px;margin-top:9px;padding-top:9px;border-top:1px solid var(--line);
  font-size:11.5px;color:var(--tx2);flex-wrap:wrap}
.rr b{color:var(--tx)}
.basis{font-size:10.5px;color:var(--tx3);margin-top:7px;line-height:1.45}

.why{display:flex;flex-direction:column;gap:7px}
.wsec .h{font-size:10.5px;text-transform:uppercase;letter-spacing:.6px;margin-bottom:4px;font-weight:600}
.h-t{color:var(--cyan)} .h-f{color:var(--green)} .h-r{color:var(--amber)}
.wsec ul{list-style:none;display:flex;flex-direction:column;gap:3px}
.wsec li{font-size:12px;color:var(--tx2);padding-left:13px;position:relative;line-height:1.45}
.wsec li:before{content:"";position:absolute;left:3px;top:7px;width:4px;height:4px;border-radius:50%;background:currentColor;opacity:.5}
.wsec.t li{color:#9fd8e6} .wsec.f li{color:#9fd9b4} .wsec.r li{color:#e0c08a}

.mets{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line);
  border:1px solid var(--line);border-radius:9px;overflow:hidden}
.mets div{background:var(--panel);padding:7px 8px;text-align:center}
.mets .n{font-size:9.5px;color:var(--tx3);text-transform:uppercase;letter-spacing:.4px}
.mets .v{font-size:12.5px;font-weight:600;margin-top:2px}

footer{margin-top:26px;padding:15px;background:var(--panel);border:1px solid var(--line);
  border-radius:10px;color:var(--tx3);font-size:11.5px;line-height:1.65}
footer b{color:var(--amber)}
.empty{text-align:center;padding:50px;color:var(--tx3)}
.more{display:none;width:100%;margin:16px 0 4px;padding:14px;background:var(--panel);
  border:1px solid var(--line);border-radius:10px;color:var(--tx);font-size:14px;
  font-weight:600;cursor:pointer;font-family:inherit;transition:.13s}
.more:hover{border-color:var(--blue);background:var(--panel2)}
.more:active{transform:scale(.995)}

/* ---------- Tampilan ponsel ---------- */
@media(max-width:760px){
  body{padding:11px;-webkit-text-size-adjust:100%}
  .grid{grid-template-columns:1fr;gap:11px}
  h1{font-size:18px}
  .sub{font-size:11.5px}
  .stats{gap:7px}
  .stat{flex:1 1 calc(33.333% - 5px);min-width:0;padding:7px 9px}
  .stat .k{font-size:9px}
  .stat .v{font-size:16px}

  /* Filter bisa digeser mendatar, tidak menumpuk memakan layar */
  .controls{gap:7px;margin:12px 0 4px}
  input[type=text]{min-width:0;width:100%;font-size:16px}  /* 16px cegah auto-zoom iOS */
  select{flex:1 1 calc(50% - 4px);font-size:13px;padding:9px 8px}
  .chips{flex-wrap:nowrap;overflow-x:auto;-webkit-overflow-scrolling:touch;
         scrollbar-width:none;padding-bottom:2px;width:100%}
  .chips::-webkit-scrollbar{display:none}
  .chip{white-space:nowrap;flex:0 0 auto;padding:8px 13px}

  .card{padding:13px;border-radius:11px}
  .code{font-size:17px}
  .cname{max-width:170px;font-size:11px}
  .px{font-size:17px}

  /* Sasaran sentuh lebih lega, kolom tetap 3 tapi rapat */
  .lv{gap:6px}
  .lv div{padding:6px 6px}
  .lv .n{font-size:8.5px;letter-spacing:.2px}
  .lv .p{font-size:13px}
  .lv .d{font-size:9px}
  .rr{gap:9px;font-size:11px}

  /* Metrik jadi 4 kolom rapat -> tetap terbaca di layar 360px */
  .mets div{padding:6px 4px}
  .mets .n{font-size:8.5px;letter-spacing:.2px}
  .mets .v{font-size:11.5px}
  .wsec li{font-size:11.5px}
}
@media(max-width:380px){
  .stat{flex:1 1 calc(50% - 4px)}
  .lv{grid-template-columns:repeat(2,1fr)}   /* 3 kolom terlalu sempit di layar kecil */
  .mets{grid-template-columns:repeat(2,1fr)}
  .cname{max-width:130px}
}
</style>
</head>
<body>
<div class="wrap">
<header>
  <h1>Screener Saham <span>IDX</span></h1>
  <div class="sub" id="sub"></div>
  <div class="stats" id="stats"></div>
</header>

<div class="controls">
  <input type="text" id="q" placeholder="Cari kode / nama saham...">
  <div class="chips" id="sigf"></div>
  <div class="chips" id="stylef"></div>
  <select id="sector"></select>
  <select id="sort">
    <option value="Combined">Urut: Skor Gabungan</option>
    <option value="TechScore">Urut: Skor Teknikal</option>
    <option value="FundScore">Urut: Skor Fundamental</option>
    <option value="RR">Urut: Risk/Reward</option>
    <option value="Change1D">Urut: Perubahan Harian</option>
    <option value="AvgValueBn">Urut: Likuiditas</option>
  </select>
</div>
<div class="count" id="count"></div>
<div class="grid" id="grid"></div>
<button id="more" class="more">Muat lebih banyak</button>

<footer>
  <b>PERINGATAN RISIKO.</b> Dashboard ini adalah alat bantu screening berbasis rumus,
  bukan rekomendasi atau nasihat investasi. Seluruh skor, sinyal, stop loss, dan take profit
  dihitung otomatis dari data harga historis dan rasio keuangan publik &mdash; tidak
  memperhitungkan berita, aksi korporasi, laporan keuangan terbaru, maupun kondisi keuangan Anda.
  Data bersumber dari Yahoo Finance dan dapat mengalami keterlambatan atau kesalahan.
  Lakukan riset sendiri sebelum bertransaksi. Risiko kerugian ditanggung sepenuhnya oleh Anda.
</footer>
</div>

<script>
var DATA = __DATA__;
// PowerShell membuka bungkus array yang isinya cuma 1 elemen, jadi normalkan dulu.
function arr(x) { if (x === null || x === undefined) return []; return Array.isArray(x) ? x : [x]; }
var S = arr(DATA.Stocks);
var fSig = "ALL", fStyle = "ALL";

function n(v, d) { if (v === null || v === undefined || isNaN(v)) return "-"; return Number(v).toLocaleString("id-ID", {minimumFractionDigits: d||0, maximumFractionDigits: d||0}); }
function esc(s) { return String(s === null || s === undefined ? "" : s).replace(/[&<>"]/g, function(c){ return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]; }); }

var SIGCLS = {"STRONG BUY":"strong","BUY":"buy","AKUMULASI":"akum","SPEKULATIF":"spek","PANTAU":"pantau","HINDARI":"hindari"};

function scoreColor(v) {
  if (v >= 70) return "var(--green)";
  if (v >= 55) return "var(--cyan)";
  if (v >= 40) return "var(--amber)";
  return "var(--red)";
}

function init() {
  var sub = "Diperbarui " + DATA.GeneratedAt + "  |  " + DATA.TotalScanned + " saham dipindai" +
    (DATA.BenchReturn3M !== null ? "  |  IHSG 3 bulan: " + DATA.BenchReturn3M + "%" : "");
  var subEl = document.getElementById("sub");
  subEl.textContent = sub;
  if (DATA.IsIntraday) {
    subEl.innerHTML = esc(sub) +
      '<div style="margin-top:6px;color:var(--amber)">Sesi bursa masih berjalan (' +
      DATA.SessionPct + '% berlalu). Harga dan volume hari ini belum final; ' +
      'volume sudah diproyeksikan ke satu hari penuh.</div>';
  }

  var cnt = {};
  S.forEach(function(s){ cnt[s.Signal] = (cnt[s.Signal]||0)+1; });
  var order = ["STRONG BUY","BUY","AKUMULASI","SPEKULATIF","PANTAU","HINDARI"];
  var html = '<div class="stat"><div class="k">Total</div><div class="v">' + S.length + '</div></div>';
  order.forEach(function(k){
    if (!cnt[k]) return;
    html += '<div class="stat"><div class="k">' + k + '</div><div class="v">' + cnt[k] + '</div></div>';
  });
  document.getElementById("stats").innerHTML = html;

  var sc = '<div class="chip on" data-v="ALL">Semua Sinyal</div>';
  order.forEach(function(k){ if (cnt[k]) sc += '<div class="chip" data-v="' + k + '">' + k + '</div>'; });
  document.getElementById("sigf").innerHTML = sc;

  var styles = {};
  S.forEach(function(s){ styles[s.Style] = 1; });
  var stc = '<div class="chip on" data-v="ALL">Semua Gaya</div>';
  Object.keys(styles).sort().forEach(function(k){ stc += '<div class="chip" data-v="' + k + '">' + k + '</div>'; });
  document.getElementById("stylef").innerHTML = stc;

  var secs = {};
  S.forEach(function(s){ if (s.Sector) secs[s.Sector] = 1; });
  var so = '<option value="ALL">Semua Sektor</option>';
  Object.keys(secs).sort().forEach(function(k){ so += '<option value="' + esc(k) + '">' + esc(k) + '</option>'; });
  document.getElementById("sector").innerHTML = so;

  document.getElementById("sigf").onclick = function(e){
    if (!e.target.dataset.v) return;
    fSig = e.target.dataset.v;
    [].forEach.call(this.children, function(c){ c.classList.toggle("on", c === e.target); });
    render();
  };
  document.getElementById("stylef").onclick = function(e){
    if (!e.target.dataset.v) return;
    fStyle = e.target.dataset.v;
    [].forEach.call(this.children, function(c){ c.classList.toggle("on", c === e.target); });
    render();
  };
  ["q","sector","sort"].forEach(function(id){
    var el = document.getElementById(id);
    el.addEventListener(id === "q" ? "input" : "change", render);
  });
  document.getElementById("more").onclick = function(){
    var dari = shown;
    shown += PAGE;
    paint(dari);
    // Setelah menambah kartu, geser sedikit supaya tombol tetap terlihat.
    window.scrollBy({ top: 200, behavior: "smooth" });
  };
  render();
}

// Bursa punya 800+ emiten. Menggambar semuanya sekaligus bikin HP berat
// (ratusan ribu elemen), jadi kartu ditampilkan bertahap.
var PAGE = 60;
var shown = PAGE;
var curList = [];

function render() {
  var q = document.getElementById("q").value.toLowerCase().trim();
  var sec = document.getElementById("sector").value;
  var sortKey = document.getElementById("sort").value;

  curList = S.filter(function(s){
    if (fSig !== "ALL" && s.Signal !== fSig) return false;
    if (fStyle !== "ALL" && s.Style !== fStyle) return false;
    if (sec !== "ALL" && s.Sector !== sec) return false;
    if (q && (s.Code + " " + s.Name).toLowerCase().indexOf(q) < 0) return false;
    return true;
  });

  curList.sort(function(a,b){
    var x = a[sortKey], y = b[sortKey];
    if (x === null || x === undefined) x = -9999;
    if (y === null || y === undefined) y = -9999;
    return y - x;
  });

  shown = PAGE;      // tiap ganti filter, kembali ke halaman pertama
  paint();
}

function paint(appendFrom) {
  var g = document.getElementById("grid");
  var more = document.getElementById("more");
  var cnt = document.getElementById("count");

  if (!curList.length) {
    g.innerHTML = '<div class="empty">Tidak ada saham yang cocok dengan filter.</div>';
    more.style.display = "none";
    cnt.textContent = "0 dari " + S.length + " saham";
    return;
  }
  var slice = curList.slice(0, shown);
  if (typeof appendFrom === "number" && appendFrom > 0) {
    // Saat menambah halaman, cukup sisipkan kartu baru. Menggambar ulang semua
    // kartu yang sudah tampil hanya membuang waktu dan bikin layar berkedip.
    g.insertAdjacentHTML("beforeend", curList.slice(appendFrom, shown).map(card).join(""));
  } else {
    g.innerHTML = slice.map(card).join("");
  }
  cnt.textContent = "Menampilkan " + slice.length + " dari " + curList.length +
                    " hasil filter  (total " + S.length + " saham dipindai)";

  var sisa = curList.length - slice.length;
  if (sisa > 0) {
    more.style.display = "block";
    more.textContent = "Muat " + Math.min(PAGE, sisa) + " lagi  (" + sisa + " belum tampil)";
  } else {
    more.style.display = "none";
  }
}

function lvl(cls, name, price, sub) {
  return '<div class="' + cls + '"><div class="n">' + name + '</div><div class="p">' + n(price) +
         '</div>' + (sub ? '<div class="d">' + sub + '</div>' : '') + '</div>';
}

function card(s) {
  var cls = "card";
  if (s.Signal === "STRONG BUY") cls += " strong";
  else if (s.Signal === "BUY" || s.Signal === "AKUMULASI") cls += " buy";
  else if (s.Signal === "HINDARI") cls += " avoid";

  var chgCls = s.Change1D > 0 ? "up" : (s.Change1D < 0 ? "down" : "flat");
  var chgTxt = (s.Change1D > 0 ? "+" : "") + s.Change1D.toFixed(2) + "%";

  var h = '<div class="' + cls + '">';

  h += '<div class="chead"><div>' +
       '<div class="code">' + esc(s.Code) + '</div>' +
       '<div class="cname">' + esc(s.Name) + '</div>' +
       '<div class="csec">' + esc(s.Sector) + (s.MarketCapT ? "  &middot;  Rp " + s.MarketCapT + " T" : "") + '</div>' +
       '</div><div class="pr">' +
       '<div class="px">' + n(s.Price) + '</div>' +
       '<div class="chg ' + chgCls + '">' + chgTxt + '</div>' +
       '</div></div>';

  h += '<div class="badges">' +
       '<span class="b b-' + (SIGCLS[s.Signal]||"pantau") + '">' + esc(s.Signal) + '</span>' +
       '<span class="b b-style">' + esc(s.Style) + ' &middot; ' + esc(s.HoldPeriod) + '</span>' +
       (s.DataLimited ? '<span class="b b-baru">SAHAM BARU &middot; ' + s.BarCount + ' HARI DATA</span>' : '') +
       '</div>';

  h += '<div class="scores">' +
       '<div class="sc"><div class="lbl"><span>Teknikal</span><b>' + s.TechScore + '</b></div>' +
       '<div class="bar"><i style="width:' + s.TechScore + '%;background:' + scoreColor(s.TechScore) + '"></i></div></div>' +
       '<div class="sc"><div class="lbl"><span>Fundamental</span><b>' + s.FundScore + '</b></div>' +
       '<div class="bar"><i style="width:' + s.FundScore + '%;background:' + scoreColor(s.FundScore) + '"></i></div></div>' +
       '<div class="sc"><div class="lbl"><span>Gabungan</span><b>' + s.Combined + '</b></div>' +
       '<div class="bar"><i style="width:' + s.Combined + '%;background:' + scoreColor(s.Combined) + '"></i></div></div>' +
       '</div>';

  // Rencana trading
  h += '<div class="plan"><div class="ttl"><span>Rencana Trading</span><em>' + esc(s.Style) + '</em></div>';
  h += '<div class="lv">' +
       lvl("en", "Entry", s.EntryLow, "s/d " + n(s.EntryHigh)) +
       lvl("sl", "Stop Loss", s.StopLoss, "-" + s.RiskPct + "%") +
       lvl("tp", "TP 1", s.TP1, "+" + s.RewardPct + "%") +
       '</div>';
  var tp2pct = ((s.TP2 - s.Price) / s.Price * 100).toFixed(1);
  h += '<div class="lv" style="margin-top:8px">' +
       lvl("tp", "TP 2", s.TP2, "+" + tp2pct + "%") +
       (s.TP3 ? lvl("tp", "TP 3", s.TP3, "+" + ((s.TP3 - s.Price)/s.Price*100).toFixed(1) + "%")
              : '<div style="opacity:.35"><div class="n">TP 3</div><div class="p">-</div></div>') +
       '<div><div class="n">Risk / Reward</div><div class="p" style="color:' +
       (s.RR >= 2 ? "var(--green)" : s.RR >= 1.5 ? "var(--cyan)" : "var(--amber)") + '">1 : ' + s.RR + '</div></div>' +
       '</div>';
  var wkCol = s.WeeklyTrend === "NAIK" ? "var(--green)"
            : s.WeeklyTrend === "TURUN" ? "var(--red)" : "var(--tx2)";
  h += '<div class="rr"><span>Risiko <b>' + s.RiskPct + '%</b></span>' +
       '<span>Potensi TP1 <b>' + s.RewardPct + '%</b></span>' +
       '<span>Likuiditas <b>Rp ' + s.AvgValueBn + ' M/hari</b></span>' +
       '<span>Tren mingguan <b style="color:' + wkCol + '">' + esc(s.WeeklyTrend || "-") + '</b></span>' +
       (s.SupportStr ? '<span>Kekuatan support <b>' + s.SupportStr + '%</b></span>' : '') +
       '</div>';
  // Hasil bersih setelah biaya beli+jual broker
  if (s.NetTP1 !== undefined && s.NetTP1 !== null) {
    var netCol = s.NetTP1 <= 0 ? "var(--red)" : (s.FeeBitePct >= 25 ? "var(--amber)" : "var(--green)");
    h += '<div class="rr" style="border-top:1px dashed var(--line)">' +
         '<span>Bersih TP1 <b style="color:' + netCol + '">' + s.NetTP1 + '%</b></span>' +
         '<span>Bersih TP2 <b>' + s.NetTP2 + '%</b></span>' +
         '<span>Impas di <b>' + n(s.BreakEven) + '</b></span>' +
         '<span>RR bersih <b>1 : ' + s.NetRR + '</b></span>' +
         '</div>';
  }
  h += '<div class="basis">SL: ' + esc(s.SLBasis) + '<br>TP: ' + esc(s.TPBasis) + '</div>';
  h += '</div>';

  // Alasan
  var rTech = arr(s.ReasonTech), rFund = arr(s.ReasonFund), rRisk = arr(s.Risks);
  h += '<div class="why">';
  if (rTech.length)
    h += '<div class="wsec t"><div class="h h-t">Alasan Teknikal</div><ul>' +
         rTech.map(function(r){ return "<li>" + esc(r) + "</li>"; }).join("") + '</ul></div>';
  if (rFund.length)
    h += '<div class="wsec f"><div class="h h-f">Alasan Fundamental</div><ul>' +
         rFund.map(function(r){ return "<li>" + esc(r) + "</li>"; }).join("") + '</ul></div>';
  if (rRisk.length)
    h += '<div class="wsec r"><div class="h h-r">Risiko / Catatan</div><ul>' +
         rRisk.map(function(r){ return "<li>" + esc(r) + "</li>"; }).join("") + '</ul></div>';
  h += '</div>';

  // Metrik kunci
  h += '<div class="mets">' +
       '<div><div class="n">PER</div><div class="v">' + (s.PER !== null ? s.PER + "x" : "-") + '</div></div>' +
       '<div><div class="n">PBV</div><div class="v">' + (s.PBV !== null ? s.PBV + "x" : "-") + '</div></div>' +
       '<div><div class="n">ROE</div><div class="v">' + (s.ROE !== null ? s.ROE + "%" : "-") + '</div></div>' +
       '<div><div class="n">DER</div><div class="v">' + (s.DER !== null ? s.DER + "%" : "-") + '</div></div>' +
       '<div><div class="n">RSI</div><div class="v">' + (s.RSI !== null ? s.RSI : "-") + '</div></div>' +
       '<div><div class="n">ADX</div><div class="v">' + (s.ADX !== null ? s.ADX : "-") + '</div></div>' +
       '<div><div class="n">ATR</div><div class="v">' + (s.ATRPct !== null ? s.ATRPct + "%" : "-") + '</div></div>' +
       '<div><div class="n">Vol x Avg</div><div class="v">' + (s.VolRatio !== null ? s.VolRatio + "x" : "-") + '</div></div>' +
       '</div>';

  h += '</div>';
  return h;
}

init();
</script>
</body>
</html>
'@

    $html = $template.Replace('__DATA__', $json)
    # .NET memakai working directory milik proses, yang tidak ikut berubah saat
    # PowerShell melakukan cd. Jadi path relatif harus dijadikan absolut dulu.
    if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath = Join-Path (Get-Location).Path $OutputPath
    }
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutputPath, $html, (New-Object System.Text.UTF8Encoding $false))
    return $OutputPath
}
