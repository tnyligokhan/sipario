// Çekmece menü — s-bilesenler.jsx `Cekmece` + Sipario.html `.cek*`, `.lst-*`.
//
// Hero zeminli, soldan açılan panel; sağ köşeleri 26 yuvarlak. Material `Drawer` KULLANILMAZ:
// tasarımın perde tonu, köşe yarıçapı ve alt eylem çubuğu onunla kurulamıyor.
//
// ROL KAPISI (K2 — pazarlıksız): `kurye` rolünde YÖNETİM bölümü ve istatistik kartları HİÇ
// çizilmez (koşullu görünürlük değil, hiç render edilmez).
//
// ══ ÇEKMECE NEDEN 2026-08-13'TE YENİDEN KURULDU ═══════════════════════════════════════════
// Eski çekmecenin ilk bölümü ("MENÜ") dört satırdı: Ana Sayfa · Müşteriler · Siparişler ·
// Gün Özeti — yani ALT NAVİGASYONUN BİREBİR KOPYASI. Alt bar her ekranda görünür ve o dört
// hedefe TEK dokunuşla gider; çekmecedeki kopyaları İKİ dokunuş istiyordu (aç + seç). Menünün
// en değerli alanı, hiçbir yere götürmeyen bir tekrara ayrılmıştı.
//
// Ölçüldü: aynı çekmece, gerçekten menüden ulaşılması gereken üç iş ekranını HİÇ taşımıyordu.
// Borçlular yalnız ana ekrandaki bento kutusundan, Sipariş Haritası yalnız sipariş listesinin
// üst çubuğundan, Çağrı Geçmişi ise AYARLARIN üç kat dibinden açılıyordu (çağrı günlüğü bir iş
// kaydıdır, ayar değil). Kullanıcı tespiti buydu ve doğruydu.
//
// Yeni düzen: İŞ (alt barda olmayan günlük hedefler) → YÖNETİM (kuryede yok) → HIZLI AYARLAR
// (tema + arayan tanıma anahtarları) → Hesap/Ayarlar. Gezinme önce, anahtarlar sonra: çekmece
// bir yere GİTMEK için açılır, anahtar ikincil iştir.
//
// ⚠️ TASARIM DOSYASINDAN BİLİNÇLİ SAPMA: `s-bilesenler.jsx:77-82` MENÜ bölümünü dört satır
// olarak öngörür. Prototip alt navigasyonla birlikte tasarlanmamıştı; uygulama onu aştı.
// Gerekçe DECISIONS.md'de.
//
// TEMA VE ARAYAN TANIMA ANAHTARLARI BURADA (kullanıcı isteği 2026-08-13). Bir tur önce bunlar
// Ayarlar'a taşınmıştı ("çekmece tasarıma döndü" notuyla); karar TERSİNE ÇEVRİLDİ. Gerekçe:
// ikisi de günde birden çok kez çevrilen, tek dokunuşluk cihaz tercihleridir — üç dokunuş
// derinlikte bir ayar sayfası onlara yanlış bir ağırlık veriyordu. Kanonik yerleri Ayarlar →
// Uygulama sayfasında DURUYOR; tek kaynak (depo) aynı, yalnız iki görünümü var.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../cagri/arayan_tanima_ayari.dart';
import 'cekmece_istatistik.dart';

/// Çekmeceden açılan tam-sayfa hedefler (sekme DEĞİL — üstüne push edilirler).
///
/// `sihirbaz` DEĞERİ KALDIRILDI (2026-08-13): çekmecede onu tetikleyen hiçbir satır yoktu,
/// yani enum dalı da kabuktaki `switch` kolu da ölüydü. Sihirbaza gerçek yol Ayarlar →
/// Uygulama üzerinden ayrı bir geri çağrımla gidiyor ve öyle kalıyor. Bu depoda "çekmece ölü
/// dalı" bir kez ekranların girişini kaybettirdi; ölü dalı silmek o dersin devamıdır.
enum CekmeceGiris {
  borclular,
  cagriGunlugu,
  harita,
  urunler,
  kuryeler,
  muaf,
  hesap,
  ayarlar,
}

class SipCekmece extends StatelessWidget {
  const SipCekmece({
    super.key,
    required this.acik,
    required this.onKapat,
    required this.isletmeAdi,
    required this.rol,
    required this.onGiris,
    required this.onCikis,
    required this.onDestek,
    this.sonSenkron,
    this.urunlerGorunur = true,
    this.borclularGorunur = true,
    this.cagriGunluguGorunur = true,
    this.koyuTema,
    this.onTema,
    this.lisansBitisi,
    this.otoSiralamaHakki,
    this.otoSiralamaAylik,
  });

  final bool acik;
  final VoidCallback onKapat;

  final String isletmeAdi;

  /// `patron` | `operator` | `kurye` | null.
  final String? rol;

  final ValueChanged<CekmeceGiris> onGiris;
  final VoidCallback onCikis;
  final VoidCallback onDestek;

  final DateTime? sonSenkron;

  final bool urunlerGorunur;

  /// `toplamBorclulariGorme` — kapalıysa satır HİÇ çizilmez. Kalıcı olarak kapalı bir kapıyı
  /// göstermek, kullanıcıya olmayan bir yol tarif etmektir (bu dosyanın genel kuralı).
  final bool borclularGorunur;

  /// `cagriGunlugu` — dükkânın çağrı günlüğü kuryeye kapatılabilir.
  final bool cagriGunluguGorunur;

  /// Geçerli tema — DEĞER değil DİNLENEBİLİR kaynak; sahibi kabuktur (`theme/tema_deposu.dart`)
  /// ve çağrı kartının native tarafı da aynı kaynağı okur. Düz `bool` geçmek yetmez: çekmece
  /// kabukla birlikte yeniden çizilse bile anahtar kendi anlık kopyasında takılı kalırdı.
  /// null ise satır çizilmez (tema bağlanmamış önizleme/test yolu).
  final ValueListenable<bool>? koyuTema;

  /// Tema değişimini kabuğa bildirir; null ise satır çizilmez.
  final ValueChanged<bool>? onTema;

  /// Abonelik bitişi (SyncMeta `validUntilIso`). null iken kart "bilinmiyor" hâlinde çizilir.
  final DateTime? lisansBitisi;

  /// Oto-sıralama hakkı. Sunucu bu alanı henüz göndermiyor; null iken kart çizilmez
  /// (uydurma veri basılmaz).
  final int? otoSiralamaHakki;
  final int? otoSiralamaAylik;

  bool get _kurye => rol == 'kurye';

  static String rolAdi(String? rol) => switch (rol) {
        'patron' => 'Yönetici',
        'operator' => 'Operatör',
        'kurye' => 'Kurye',
        _ => 'Tek kişilik',
      };

  @override
  Widget build(BuildContext context) {
    final genislik = (MediaQuery.sizeOf(context).width * 0.84).clamp(240.0, 330.0);
    return IgnorePointer(
      ignoring: !acik,
      child: Stack(
        children: [
          // CSS .cek-scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onKapat,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                color: acik ? SipTokens.scrim : Colors.transparent,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            left: acik ? 0 : -genislik,
            top: 0,
            bottom: 0,
            width: genislik,
            child: _Panel(cekmece: this),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.cekmece});

  final SipCekmece cekmece;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final c = cekmece;
    return Material(
      color: t.hero,
      borderRadius: SipRadius.cekmece,
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle(
        style: TextStyle(color: SipTokens.onHero, fontFamily: sipFontBody),
        child: Column(
          children: [
            _Baslik(cekmece: c),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SipSpace.x2, SipSpace.sm, SipSpace.x2, SipSpace.x2),
                children: [
                  // ── İŞ ─────────────────────────────────────────────────────────────────
                  // Buraya YALNIZ alt navigasyonda olmayan hedefler girer. Alt bar Ana ·
                  // Müşteri · Sipariş · Gün Özeti'ni zaten tek dokunuşla veriyor; onları
                  // burada tekrarlamak menüyü uzatıp hiçbir yere götürmez.
                  const _Bolum('İş'),
                  // Borçlular BENTO KUTUSUNDAN DA açılmaya devam eder: o kutu bir RAKAM
                  // gösterir ("açık veresiye ne kadar") ve rakama dokunmak doğal. Buradaki
                  // satır ise hangi sekmede olursan ol ulaşılabilir olmasını sağlar — ikisi
                  // aynı ekranı açar ve AYNI yetki kapısından geçer (kabukta tek fonksiyon).
                  if (c.borclularGorunur)
                    _Satir(
                      ikon: SipIcons.wallet,
                      etiket: 'Borçlular',
                      git: true,
                      onTap: () => c.onGiris(CekmeceGiris.borclular),
                    ),
                  // ÇAĞRI GEÇMİŞİ ARTIK BURADA (kullanıcı tespiti 2026-08-13: "çağrı geçmişi
                  // sayfası ayarlarda olmamalı, bu çok saçma"). Doğruydu: bu bir iş kaydıdır,
                  // bir tercih değil. Ayarların içindeyken üç dokunuş derinlikteydi ve dahası,
                  // oradan açılan müşteri kartı yetkiyi taşımadığı için bir yetki açığının da
                  // taşıyıcısıydı (bkz. `CustomerDetailScreen.yetki`).
                  if (c.cagriGunluguGorunur)
                    _Satir(
                      ikon: SipIcons.clock,
                      etiket: 'Çağrı Geçmişi',
                      git: true,
                      onTap: () => c.onGiris(CekmeceGiris.cagriGunlugu),
                    ),
                  _Satir(
                    ikon: SipIcons.pin,
                    etiket: 'Sipariş Haritası',
                    git: true,
                    onTap: () => c.onGiris(CekmeceGiris.harita),
                  ),

                  // ── YÖNETİM ────────────────────────────────────────────────────────────
                  // ROL KAPISI: kuryede bu bölüm ve istatistik kartları HİÇ çizilmez.
                  if (!c._kurye) ...[
                    const _Bolum('Yönetim'),
                    if (c.urunlerGorunur)
                      _Satir(
                        ikon: SipIcons.box,
                        etiket: 'Ürünler',
                        git: true,
                        onTap: () => c.onGiris(CekmeceGiris.urunler),
                      ),
                    _Satir(
                      ikon: SipIcons.truck,
                      etiket: 'Kuryeler',
                      git: true,
                      onTap: () => c.onGiris(CekmeceGiris.kuryeler),
                    ),
                    _Satir(
                      ikon: SipIcons.phoneOff,
                      etiket: 'Muaf Telefonlar',
                      git: true,
                      onTap: () => c.onGiris(CekmeceGiris.muaf),
                    ),
                    CekmeceIstatistikleri(
                      lisansBitisi: c.lisansBitisi,
                      otoSiralamaHakki: c.otoSiralamaHakki,
                      otoSiralamaAylik: c.otoSiralamaAylik,
                    ),
                  ],

                  // ── HIZLI AYARLAR ──────────────────────────────────────────────────────
                  // İkisi de CİHAZ tercihidir (senkrona girmez) ve kuryede de açıktır: kurye
                  // kendi telefonunun temasını ve arayan tanımasını yönetir — kapatılan şey
                  // hep DÜKKÂN VERİSİDİR, kişinin kendi cihazı değil.
                  const _Bolum('Hızlı Ayarlar'),
                  if (c.koyuTema != null && c.onTema != null)
                    ValueListenableBuilder<bool>(
                      valueListenable: c.koyuTema!,
                      builder: (context, koyu, _) => _AnahtarSatiri(
                        ikon: SipIcons.moon,
                        etiket: 'Koyu Tema',
                        acik: koyu,
                        onDegis: () => c.onTema!(!koyu),
                      ),
                    ),
                  const CekmeceArayanTanimaSatiri(),

                  // ── HESAP & AYARLAR ────────────────────────────────────────────────────
                  const _Bolum('Uygulama'),
                  _Satir(
                    ikon: SipIcons.user,
                    etiket: 'Hesap',
                    git: true,
                    onTap: () => c.onGiris(CekmeceGiris.hesap),
                  ),
                  _Satir(
                    ikon: SipIcons.settings,
                    etiket: 'Ayarlar',
                    git: true,
                    onTap: () => c.onGiris(CekmeceGiris.ayarlar),
                  ),
                ],
              ),
            ),
            _AltCubuk(onDestek: c.onDestek, onCikis: c.onCikis),
          ],
        ),
      ),
    );
  }
}

/// CSS `.cek-head` — logo + işletme adı + rol/senkron + kapat.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.cekmece});

  final SipCekmece cekmece;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final c = cekmece;
    final saat = c.sonSenkron == null
        ? 'senkron bekliyor'
        : 'senkron ${_ss(c.sonSenkron!)}';
    return Container(
      padding: EdgeInsets.fromLTRB(
        SipSpace.govde,
        SipSpace.x6 + MediaQuery.paddingOf(context).top,
        SipSpace.govde,
        SipSpace.x3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SipTokens.onHeroLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(SipSpace.x2),
            ),
            child: SipIcon(SipIcons.phoneCall, boyut: 21, kalinlik: 2.2, renk: t.accentInk),
          ),
          const SizedBox(width: SipSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.isletmeAdi,
                  style: SipText.cekmeceIsletme.copyWith(color: SipTokens.onHero),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${SipCekmece.rolAdi(c.rol)} · $saat',
                  style: SipText.cekmeceRol.copyWith(color: SipTokens.onHeroMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SipIkonButon(
            ikon: SipIcons.x,
            cap: 34,
            ikonBoyut: 19,
            kalinlik: 2.2,
            zemin: SipTokens.onHeroFill,
            renk: SipTokens.onHeroStrong,
            etiket: 'Kapat',
            onTap: c.onKapat,
          ),
        ],
      ),
    );
  }

  static String _ss(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// CSS `.cek-sec` — bölüm etiketi (BÜYÜK HARF).
class _Bolum extends StatelessWidget {
  const _Bolum(this.etiket);

  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.lg, SipSpace.x3, SipSpace.lg, 7),
      child: Text(
        trBuyuk(etiket),
        style: SipText.cekmeceBolum.copyWith(color: SipTokens.onHeroSoft),
      ),
    );
  }
}

/// CSS `.cekr` — menü satırı; [git] sağda chevron gösterir.
///
/// `secili` PARAMETRESİ KALDIRILDI (2026-08-13): accent dolgulu "seçili" hâl yalnız sekme
/// kopyası satırlar için vardı ("şu an Siparişler'desin"). O satırlar alt navigasyonu
/// tekrarladıkları için kaldırılınca `secili` hiçbir yerden verilmez oldu — kalan her satır bir
/// ROTA açar ve rotalar "seçili" olmaz. Kullanılmayan bir görsel hâli bırakmak, sonraki
/// okuyucuya var olmayan bir davranış vaat ederdi.
class _Satir extends StatelessWidget {
  const _Satir({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.git = false,
  });

  final String ikon;
  final String etiket;
  final VoidCallback onTap;
  final bool git;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SipDokun(
        onTap: onTap,
        zemin: Colors.transparent,
        basiliZemin: SipTokens.onHeroFill,
        radius: BorderRadius.circular(13),
        padding: const EdgeInsets.all(SipSpace.xl),
        child: Row(
          children: [
            SipIcon(ikon, boyut: 19, kalinlik: 1.9, renk: SipTokens.onHeroMid),
            const SizedBox(width: SipSpace.xl),
            Expanded(
              child: Text(
                etiket,
                style: SipText.cekmeceSatir.copyWith(color: SipTokens.onHeroStrong),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (git)
              const SipIcon(SipIcons.chevR,
                  boyut: 16, kalinlik: 2, renk: SipTokens.onHeroFaint),
          ],
        ),
      ),
    );
  }
}

/// Çekmecedeki AÇ/KAPA satırı — `_Satir`ın kardeşi, chevron yerine anahtar taşır.
///
/// NEDEN AYRI BİR WIDGET: `_Satir`a bir `sag` yuvası açmak daha az kod olurdu ama iki satır
/// TÜRÜNÜ birbirine karıştırırdı. Chevronlu satır "seni başka bir yere götüreceğim" der ve
/// dokunuşu bir rota açar; anahtarlı satır hiçbir yere gitmez, yerinde bir durumu çevirir.
/// İkisini tek widget'ta toplamak, ileride birinin yanlışlıkla diğerinin davranışını almasına
/// açık kapı bırakırdı (bu ekranda "işaret, arkasındaki davranışın karşılığıdır" kuralı
/// zaten yazılı — `DegerSatiri.sagIkon`).
class _AnahtarSatiri extends StatelessWidget {
  const _AnahtarSatiri({
    required this.ikon,
    required this.etiket,
    required this.acik,
    required this.onDegis,
  });

  final String ikon;
  final String etiket;
  final bool acik;
  final VoidCallback onDegis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        toggled: acik,
        child: SipDokun(
          onTap: onDegis,
          zemin: Colors.transparent,
          basiliZemin: SipTokens.onHeroFill,
          radius: BorderRadius.circular(13),
          padding: const EdgeInsets.all(SipSpace.xl),
          child: Row(
            children: [
              SipIcon(ikon, boyut: 19, kalinlik: 1.9, renk: SipTokens.onHeroMid),
              const SizedBox(width: SipSpace.xl),
              Expanded(
                child: Text(
                  etiket,
                  style: SipText.cekmeceSatir.copyWith(color: SipTokens.onHeroStrong),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Kapalı rayın rengi hero zeminine göre verilir; varsayılan `line2` burada
              // arka planla neredeyse aynı tona düşüyor ve kapalı anahtar YOK gibi okunuyor.
              SipKnob(acik: acik, kapaliZemin: SipTokens.onHeroFill2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Çekmecedeki ARAYAN TANIMA anahtarı.
///
/// Kendi durumunu `arayanTanimaDeposu`ndan okur — Ayarlar'daki `ArayanTanimaSatiri` ile AYNI
/// kaynağı. İki görünüm, tek doğru kaynak: biri çevrilince diğeri açıldığında yeni değeri okur.
/// (Depo cihaz-yerel bir dosyadır, senkronla değişmez; tek atış okuma burada doğrudur.)
class CekmeceArayanTanimaSatiri extends StatefulWidget {
  const CekmeceArayanTanimaSatiri({super.key});

  @override
  State<CekmeceArayanTanimaSatiri> createState() => _CekmeceArayanTanimaSatiriState();
}

class _CekmeceArayanTanimaSatiriState extends State<CekmeceArayanTanimaSatiri> {
  /// null → tercih henüz okunmadı; anahtar varsayılan (AÇIK) çizilir ki satır zıplamasın.
  bool? _acik;

  @override
  void initState() {
    super.initState();
    unawaited(_yukle());
  }

  Future<void> _yukle() async {
    final acik = await arayanTanimaDeposu.acikMi();
    if (mounted) setState(() => _acik = acik);
  }

  Future<void> _cevir() async {
    final yeni = !(_acik ?? true);
    setState(() => _acik = yeni);
    await arayanTanimaDeposu.yaz(yeni);
  }

  @override
  Widget build(BuildContext context) => _AnahtarSatiri(
        ikon: SipIcons.phone,
        etiket: 'Arayan Tanıma',
        acik: _acik ?? true,
        onDegis: _cevir,
      );
}

/// CSS `.cek-alt` — destek düğmesi + çıkış.
class _AltCubuk extends StatelessWidget {
  const _AltCubuk({required this.onDestek, required this.onCikis});

  final VoidCallback onDestek;
  final VoidCallback onCikis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: EdgeInsets.fromLTRB(
        SipSpace.x2,
        SipSpace.lg,
        SipSpace.x2,
        SipSpace.x3 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SipTokens.onHeroLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SipDokun(
              onTap: onDestek,
              zemin: t.accent,
              basiliZemin: t.accent,
              radius: BorderRadius.circular(13),
              olcekle: true,
              padding: const EdgeInsets.all(13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SipIcon(SipIcons.chat, boyut: 17, kalinlik: 2, renk: t.accentInk),
                  const SizedBox(width: SipSpace.md),
                  // Çekmece en fazla 330 geniş; metin ölçeği büyütülmüş cihazda etiket
                  // düğmeyi taşırıyor — esnek bırakılır, kesilirse üç noktayla biter.
                  Flexible(
                    child: Text(
                      'Sipario Destek Hattı',
                      style: SipText.metin(13, w: 700).copyWith(color: t.accentInk),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Semantics(
            button: true,
            label: 'Çıkış Yap',
            child: SipDokun(
              onTap: onCikis,
              zemin: SipTokens.heroCikisFill,
              basiliZemin: SipTokens.heroCikisFill2,
              radius: BorderRadius.circular(13),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: SipIcon(SipIcons.power,
                      boyut: 18, kalinlik: 2.1, renk: SipTokens.heroCikisInk),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
