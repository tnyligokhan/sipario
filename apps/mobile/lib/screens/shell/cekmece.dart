// Çekmece menü — hero zeminli, soldan açılan panel. Material `Drawer` KULLANILMAZ: tasarımın
// perde tonu, köşe yarıçapı ve alt eylem çubuğu onunla kurulamıyor.
//
// ══════════════════════════════════════════════════════════════════════════════════════════
// ÇEKMECE NE İŞE YARAR — 2026-08-13 YENİDEN TASARIMI
// ══════════════════════════════════════════════════════════════════════════════════════════
// Bu uygulamada ALT NAVİGASYON var (Ana · Müşteri · Sipariş · Gün Özeti + ekle düğmesi) ve o,
// günlük dört yüzeyi HER EKRANDAN tek dokunuşla veriyor. Dolayısıyla çekmece BİRİNCİL GEZİNME
// DEĞİLDİR ve öyle davranmamalıdır: alt barın taşıdığı hedefleri tekrarlamak, menünün alanını
// hiçbir yere götürmeyen satırlara harcamaktır (eski hâlde ilk dört satır tam olarak buydu).
//
// Çekmecenin işi ÜÇ TANEDİR ve panel bu üçe göre ÜÇ BÖLGEYE ayrılmıştır:
//
//   1. KİMLİK + DURUM (üst)  — "kimim, hangi firmadayım, verim sunucuya gitti mi, aboneliğim
//      ne durumda". Okunur, nadiren dokunulur. En üstte olması doğrudur: okuma yukarıdan başlar.
//
//   2. HEDEFLER (orta)  — alt barda OLMAYAN ekranlar. Buraya bir satır ancak "başka türlü
//      ulaşılamıyor ya da çok derinde" ise girer.
//
//   3. KİŞİSEL KONTROLLER (alt)  — sık çevrilen cihaz tercihleri ve seyrek sistem eylemleri.
//
// ⚠️ SIRALAMA GEREKÇESİ — BAŞPARMAK: çekmece tam boy bir paneldir; telefonu tek elle tutan
// başparmak ALTTA durur ve panelin üst üçte biri en zor erişilen bölgedir. Bu yüzden sık
// çevrilen anahtarlar (koyu tema, arayan tanıma) ayağa alındı; üstte yalnız OKUNAN şeyler var.
// Eski düzende tam tersiydi: en nadir ve en riskli eylem (Çıkış) en erişilebilir köşedeydi.
//
// ⚠️ TASARIM DOSYASINDAN BİLİNÇLİ SAPMA: `s-bilesenler.jsx:77-82` MENÜ bölümünü alt barın
// kopyası dört satır olarak öngörür. O prototip alt navigasyonla birlikte tasarlanmamıştı.
// Gerekçe DECISIONS.md'de.
//
// ROL KAPISI (K2 — pazarlıksız): `kurye` rolünde YÖNETİM bölümü ve lisans kartları HİÇ
// çizilmez (koşullu görünürlük değil, hiç render edilmez). Çekmece hiçbir yetki KARARI VERMEZ:
// görünürlük ölçütlerini kabuk hesaplar, burası yalnız çizer.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'cekmece_istatistik.dart';
import 'cekmece_parcalari.dart';

// ÜÇÜNCÜ BÖLGE AYRILDI (2026-08-17, 500 satır kuralı — 541 satırdı): satırı çizen atomlar
// `cekmece_satirlari.dart`ta. Özel kaldıkları için `part`tır — dışarıdan kullanılmazlar.
part 'cekmece_satirlari.dart';

/// Çekmeceden açılan tam-sayfa hedefler (sekme DEĞİL — üstüne push edilirler).
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
    this.kullaniciAdi,
    this.sonSenkron,
    this.karantina = 0,
    this.borcluSayisi,
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

  /// Oturumdaki kişinin adı — rol satırında firmanın ALTINDA yazar.
  ///
  /// NEDEN EKLENDİ: eski başlık "Yönetici · senkron 10:32" diyordu, yani kişinin KİM olduğunu
  /// hiçbir yerde söylemiyordu. Tek telefonu birden çok kişinin kullandığı bayilerde (patron
  /// sabah, operatör akşam) "ben kim olarak girmişim" günlük bir sorudur.
  final String? kullaniciAdi;

  /// `patron` | `operator` | `kurye` | null.
  final String? rol;

  final ValueChanged<CekmeceGiris> onGiris;
  final VoidCallback onCikis;
  final VoidCallback onDestek;

  final DateTime? sonSenkron;

  /// Sunucunun kabul etmediği, cihazda bekleyen kayıt sayısı — durum şeridinde uyarı olur.
  final int karantina;

  /// Borçlu müşteri sayısı; null ise sayaç çizilmez (henüz okunmadı).
  final int? borcluSayisi;

  final bool urunlerGorunur;

  /// `toplamBorclulariGorme` — kapalıysa satır HİÇ çizilmez. Kalıcı olarak kapalı bir kapıyı
  /// göstermek, kullanıcıya olmayan bir yol tarif etmektir.
  final bool borclularGorunur;

  /// `cagriGunlugu` — dükkânın çağrı günlüğü kuryeye kapatılabilir.
  final bool cagriGunluguGorunur;

  /// Geçerli tema — DEĞER değil DİNLENEBİLİR kaynak (sahibi kabuk). null ise anahtar çizilmez.
  final ValueListenable<bool>? koyuTema;
  final ValueChanged<bool>? onTema;

  /// Abonelik bitişi (SyncMeta `validUntilIso`). null iken kart "bilinmiyor" hâlinde çizilir.
  final DateTime? lisansBitisi;

  /// Oto-sıralama hakkı. Sunucu bu alanı henüz göndermiyor; null iken kart çizilmez.
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
            // ── BÖLGE 1: KİMLİK + DURUM ────────────────────────────────────────────────
            _Baslik(cekmece: c),

            // ── BÖLGE 2: HEDEFLER ──────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.x2, SipSpace.lg, SipSpace.x2, SipSpace.lg),
                children: [
                  // BÖLÜM ETİKETİ YOK ve bilinçli: eski düzende dokuz satır için dört büyük
                  // harf başlık vardı ("İŞ", "YÖNETİM", "HIZLI AYARLAR", "UYGULAMA") ve hiçbiri
                  // ayırt edici bilgi taşımıyordu — yalnız dikey alan yiyip taramayı
                  // yavaşlatıyorlardı. Ayrım artık boşluk ve ayraçla yapılıyor; tek etiket
                  // YÖNETİM'de kalıyor, çünkü o ROL sinyali taşır ("burası patron işi").
                  if (c.borclularGorunur)
                    _Satir(
                      ikon: SipIcons.wallet,
                      etiket: 'Borçlular',
                      // SAYAÇ: menüyü "nereye gidebilirim" listesinden "neye bakmam gerek"
                      // yüzeyine çeviren tek ekleme. Bayi için borçlu sayısı günün en sık
                      // sorduğu sorudur ve veri zaten var (`watchDebtCount`).
                      sayac: c.borcluSayisi,
                      onTap: () => c.onGiris(CekmeceGiris.borclular),
                    ),
                  if (c.cagriGunluguGorunur)
                    _Satir(
                      ikon: SipIcons.clock,
                      etiket: 'Çağrı Geçmişi',
                      onTap: () => c.onGiris(CekmeceGiris.cagriGunlugu),
                    ),
                  _Satir(
                    ikon: SipIcons.pin,
                    etiket: 'Sipariş Haritası',
                    onTap: () => c.onGiris(CekmeceGiris.harita),
                  ),

                  // ROL KAPISI: kuryede bu bölüm ve lisans kartları HİÇ çizilmez.
                  if (!c._kurye) ...[
                    const _Bolum('Yönetim'),
                    if (c.urunlerGorunur)
                      _Satir(
                        ikon: SipIcons.box,
                        etiket: 'Ürünler',
                        onTap: () => c.onGiris(CekmeceGiris.urunler),
                      ),
                    _Satir(
                      ikon: SipIcons.truck,
                      etiket: 'Kuryeler',
                      onTap: () => c.onGiris(CekmeceGiris.kuryeler),
                    ),
                    _Satir(
                      ikon: SipIcons.phoneOff,
                      etiket: 'Muaf Telefonlar',
                      onTap: () => c.onGiris(CekmeceGiris.muaf),
                    ),
                  ],

                  const _Ayrac(),
                  _Satir(
                    ikon: SipIcons.user,
                    etiket: 'Hesap',
                    onTap: () => c.onGiris(CekmeceGiris.hesap),
                  ),
                  _Satir(
                    ikon: SipIcons.settings,
                    etiket: 'Ayarlar',
                    onTap: () => c.onGiris(CekmeceGiris.ayarlar),
                  ),

                ],
              ),
            ),

            // ── BÖLGE 3: KİŞİSEL KONTROLLER (başparmak bölgesi) ────────────────────────
            _AltCubuk(cekmece: c),
          ],
        ),
      ),
    );
  }
}

/// CSS `.cek-head` — logo + işletme + rol/kullanıcı + kapat, ALTINDA durum şeridi ve lisans.
///
/// LİSANS KARTLARI BURAYA TAŞINDI (2026-08-13): eskiden gezinme satırlarının ORTASINDA,
/// Muaf Telefonlar ile Ayarlar arasında duruyorlardı. İki büyük kart, bir hedef listesinin
/// içinde tarama akışını kesiyordu — oysa onlar bir HEDEF değil DURUMDUR ("aboneliğim ne
/// oldu"). Kartların kendisi değişmedi; yalnız ait oldukları bölgeye alındılar.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.cekmece});

  final SipCekmece cekmece;

  @override
  Widget build(BuildContext context) {
    final c = cekmece;
    final ad = (c.kullaniciAdi ?? '').trim();
    final altSatir =
        ad.isEmpty ? SipCekmece.rolAdi(c.rol) : '${SipCekmece.rolAdi(c.rol)} · $ad';

    return Container(
      padding: EdgeInsets.fromLTRB(
        SipSpace.govde,
        SipSpace.x4 + MediaQuery.paddingOf(context).top,
        SipSpace.govde,
        SipSpace.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SipTokens.onHeroLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.sip.accent,
                  borderRadius: BorderRadius.circular(SipSpace.x2),
                ),
                child: SipIcon(SipIcons.phoneCall,
                    boyut: 21, kalinlik: 2.2, renk: context.sip.accentInk),
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
                      altSatir,
                      style: SipText.cekmeceRol.copyWith(color: SipTokens.onHeroMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // ÇARPI KALDIRILDI, YERİNE ÇIKIŞ (kullanıcı kararı 2026-08-13). Çekmece zaten
              // perdeye dokununca kapanıyor (ve geri tuşuyla da) — yani "Kapat" düğmesi, var
              // olan iki yolu üçüncü kez tekrarlayıp panelin en değerli köşesini işgal
              // ediyordu. Aynı köşe artık, çekmecenin ayağında etiketsiz bir güç simgesi
              // olarak duran Çıkış'a ait: eylem hem adıyla anılıyor hem parmağın doğal
              // olarak aradığı yerde.
              SipIkonButon(
                ikon: SipIcons.power,
                cap: 34,
                ikonBoyut: 18,
                kalinlik: 2.1,
                zemin: SipTokens.heroCikisFill,
                renk: SipTokens.heroCikisInk,
                etiket: 'Çıkış Yap',
                onTap: c.onCikis,
              ),
            ],
          ),
          const SizedBox(height: SipSpace.lg),
          CekmeceDurumSeridi(sonSenkron: c.sonSenkron, karantina: c.karantina),
          // LİSANS ŞERİDİ DURUM BÖLGESİNDE (kullanıcı kararı 2026-08-13: "üstte olmaları sorun
          // değil ama bu kadar büyük olmalarına gerek yok"). Artık ~44 punto: senkron
          // şeridiyle birlikte tek bir "durum" bloğu kuruyor, hedef listesini itmiyor.
          if (!c._kurye)
            CekmeceIstatistikleri(
              lisansBitisi: c.lisansBitisi,
              otoSiralamaHakki: c.otoSiralamaHakki,
              otoSiralamaAylik: c.otoSiralamaAylik,
            ),
        ],
      ),
    );
  }
}
