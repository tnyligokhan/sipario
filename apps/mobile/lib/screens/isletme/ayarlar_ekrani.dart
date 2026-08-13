// AYARLAR — kategori HUB'ı. Her satır kendi sayfasını açar.
//
// ══ NEDEN BÖLÜNDÜ (kullanıcı isteği 2026-08-13) ═══════════════════════════════════════════
// Bu ekran tek uzun bir listeydi ve BEŞ FARKLI TÜRDEN şeyi yan yana koyuyordu: cihaz tercihi
// (tema), özellik anahtarı (arayan tanıma), İŞ VERİSİ EKRANI (çağrı geçmişi), işletme
// yapılandırması (profil, sipariş kodu) ve künye (sürüm/lisans). Kullanıcının tespiti şuydu:
// "çağrı geçmişi sayfası ayarlarda olmamalı, bu çok saçma" — doğruydu ve tek örnek değildi;
// sorun kategorisizlikti. Çağrı geçmişi ARTIK ÇEKMECEDE (bir iş kaydıdır, bir tercih değil).
//
// Yeni yapı beş sayfadır: Hesap · İşletme · Uygulama · Bildirimler · Hakkında.
//
// ⚠️ TASARIM DOSYASINDAN BİLİNÇLİ SAPMA: `s-ayarlar.jsx` dört bölümlük tek liste öngörür
// (Görünüm · Arayan Tanıma · İşletme · Hakkında). O prototip bildirimler, sipariş kodu, kurye
// yetkileri ve hesap kavramı yokken çizilmişti; uygulama onu çoktan aştı. Gerekçe DECISIONS.md'de.
//
// ══ MAĞAZA KURALI (pazarlıksız) ═══════════════════════════════════════════════════════════
// Ayarların HİÇBİR sayfasında abonelik / ödeme / satın alma / fiyat / üyelik bağlantısı OLAMAZ.
// Lisans yalnız NÖTR bir bilgi satırıdır (Hakkında) ve hiçbir eyleme bağlanmaz. Yasaklı sözcük
// testi (`Abone`, `Satın al`, `Üye ol`, `Kaydol`) BEŞ SAYFAYI DA taramalıdır — bölünme, taramanın
// kapsamını daraltmak için bir bahane değildir.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart' show RolYetkileri;
import 'ayarlar/bildirim_ayarlari_ekrani.dart';
import 'ayarlar/hakkinda_ekrani.dart';
import 'ayarlar/hesap_ekrani.dart';
import 'ayarlar/isletme_ayarlari_ekrani.dart';
import 'ayarlar/uygulama_ayarlari_ekrani.dart';
import 'isletme_atomlari.dart';

// Sürüm/lisans metinleri Hakkında sayfasına taşındı ama BU DOSYADAN ERİŞİLEBİLİR KALIR:
// `isletme_kurallari_test.dart` ve `api_surumu_test.dart` onları buradan import ediyor ve
// bölünme testlerin import yollarını kırmak için bir sebep değil (aynı desen:
// `day_end_screen.dart` veri katmanını böyle yeniden dışa veriyor).
export 'ayarlar/hakkinda_ekrani.dart'
    show lisansMetni, sunucuSurumuMetni, siparioSurumunuOku, HakkindaKarti;

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({
    super.key,
    required this.db,
    required this.yetki,
    this.rol,
    this.session,
    this.onCikis,
    this.writable = true,
    this.onSihirbaz,
    this.onCagriSimulasyonu,
    this.onOlcumler,
    this.koyuTema,
    this.onTema,
  });

  final AppDatabase db;

  /// Rol + kurye izinlerinden türeyen yetki kümesi (kabuktan gelir).
  ///
  /// ⚠️ 2026-08-13'TE ZORUNLU OLDU. Eskiden nullable'dı ve doc "verilmezse kısıtlama uygulanmaz
  /// (test/önizleme yolu)" diyordu — o geçirgen varsayılan, bu ekrandan açılan müşteri kartına
  /// sızıyor ve orada bir yetki genişlemesine dönüşüyordu. Önizleme yine mümkün: çağıran
  /// `yetkiler(rol: ..., kuryeVar: ...)` geçer.
  final RolYetkileri yetki;

  /// `patron|operator|kurye`. İŞLETME satırının kapısı budur ve doğrudan `patron` string'ine
  /// bakar (operatör dahil DEĞİL) — matristeki `isletmeAbonelikAyarlari` alanı tanımlı ama bu
  /// yüzeyde hiç kullanılmadı; iki ölçütü birden canlı tutmak birinin sessizce ayrışması demek.
  final String? rol;

  /// Hesap sayfası için — verilmezse HESAP satırı çizilmez (çekmeceden zaten ulaşılıyor).
  final Session? session;
  final VoidCallback? onCikis;

  final bool writable;

  /// Kurulum sihirbazını yeniden çalıştırır (Uygulama sayfasına geçer).
  final VoidCallback? onSihirbaz;

  /// Verilen numarayla çağrı kartını açar (Uygulama sayfasındaki deneme akışı).
  final ValueChanged<String>? onCagriSimulasyonu;

  /// Faz 0 gecikme ölçüm ekranını açar; null → satır hiç çizilmez.
  final VoidCallback? onOlcumler;

  /// Geçerli tema — DEĞER değil DİNLENEBİLİR kaynak (sahibi kabuk, kalıcılık
  /// `lib/theme/tema_deposu.dart`; çağrı kartının native tarafı da aynı kaynağı okur).
  final ValueListenable<bool>? koyuTema;
  final ValueChanged<bool>? onTema;

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  Future<void> _cagriDene() async {
    final numara = await sipSheet<String>(
      context,
      baslik: 'Çağrı Simülasyonu',
      govde: (ctx) => const _SimulasyonListesi(),
    );
    if (numara == null || !mounted) return;
    final geriCagri = widget.onCagriSimulasyonu;
    if (geriCagri == null) {
      SipToast.goster(context, 'Çağrı ekranı bu görünümde bağlı değil.');
      return;
    }
    geriCagri(numara);
  }

  void _ac(Widget ekran) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ekran),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final patron = widget.rol == 'patron';
    final session = widget.session;
    final onCikis = widget.onCikis;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Ayarlar', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SipGovde(children: [
                const SipBolumBaslik('Ayarlar', ustBosluk: 18),
                AyarKarti(satirlar: [
                  if (session != null && onCikis != null)
                    AyarSatiri(
                      ikon: SipIcons.user,
                      baslik: 'Hesap',
                      altBaslik: 'Kullanıcı, cihazlar ve oturum',
                      onTap: () => _ac(HesapEkrani(
                        db: widget.db,
                        session: session,
                        onCikis: onCikis,
                      )),
                    ),
                  // İŞLETME YALNIZ PATRONDA: satır çizilmez, pasif de değil. Kalıcı olarak
                  // kapalı bir kapıyı göstermek kullanıcıya olmayan bir yol tarif etmektir.
                  if (patron)
                    AyarSatiri(
                      ikon: SipIcons.home,
                      baslik: 'İşletme',
                      altBaslik: 'Profil, iletişim, sipariş kodu',
                      onTap: () => _ac(IsletmeAyarlariEkrani(
                        db: widget.db,
                        writable: widget.writable,
                      )),
                    ),
                  AyarSatiri(
                    ikon: SipIcons.settings,
                    baslik: 'Uygulama',
                    altBaslik: 'Tema, arayan tanıma, sürükleme',
                    onTap: () => _ac(UygulamaAyarlariEkrani(
                      koyuTema: widget.koyuTema,
                      onTema: widget.onTema,
                      onSihirbaz: widget.onSihirbaz,
                      onCagriDene: _cagriDene,
                      onOlcumler: widget.onOlcumler,
                    )),
                  ),
                  AyarSatiri(
                    ikon: SipIcons.alert,
                    baslik: 'Bildirimler',
                    altBaslik: 'İzinler, kategoriler, sessiz saatler',
                    onTap: () => _ac(const BildirimAyarlariEkrani()),
                  ),
                  AyarSatiri(
                    ikon: SipIcons.info,
                    baslik: 'Hakkında',
                    altBaslik: 'Sürüm, lisans, yenilikler',
                    onTap: () => _ac(HakkindaEkrani(db: widget.db)),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simülasyon satırının anlamı — ikon rengini bu belirler (tasarım `s-ayarlar.jsx:6-9`).
enum _SimTuru { borclu, temiz, alacakli, kayitsiz }

/// CSS `.sr-list` + `.aday-row` — tasarımdaki dört çağrı senaryosu.
///
/// Alt satır SOMUT örnek verir (isim + tutar), genel ifade değil: kullanıcı hangi varyantı
/// açtığını kartın çıkmasından ÖNCE bilsin. Renk de satır başına ayrılır — dört satır aynı
/// renkte olunca "borçlu" ile "temiz" arasındaki fark yalnız metinde kalıyordu.
class _SimulasyonListesi extends StatelessWidget {
  const _SimulasyonListesi();

  static List<({String ad, String alt, String no, _SimTuru tur})> get _senaryolar => [
        (
          ad: 'Kayıtlı · Borçlu',
          alt: 'Ahmet Yılmaz · ${sipTutar(34000)} borç',
          no: '05324152290',
          tur: _SimTuru.borclu,
        ),
        (
          ad: 'Kayıtlı · Temiz',
          alt: 'Selin Kaya · hesap temiz',
          no: '05332207841',
          tur: _SimTuru.temiz,
        ),
        (
          ad: 'Kayıtlı · Alacaklı',
          alt: 'Murat Öz · ${sipTutar(12000)} alacak',
          no: '05429076322',
          tur: _SimTuru.alacakli,
        ),
        (
          ad: 'Kayıtsız Numara',
          alt: 'Defterde olmayan arayan',
          no: '02165550188',
          tur: _SimTuru.kayitsiz,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final senaryolar = _senaryolar;
    Color renk(_SimTuru tur) => switch (tur) {
          _SimTuru.borclu => t.danger,
          _SimTuru.temiz => t.ok,
          _SimTuru.alacakli => t.ok,
          _SimTuru.kayitsiz => t.muted,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < senaryolar.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: SipDokun(
              onTap: () => Navigator.of(context).pop(senaryolar[i].no),
              zemin: t.surface,
              basiliZemin: t.accentSoft,
              radius: SipRadius.br2,
              kenarlik: Border.all(color: t.line, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 11),
              child: Row(
                children: [
                  SipIkonKutu(
                    ikon: SipIcons.phoneCall,
                    cap: 32,
                    ikonBoyut: 15,
                    kalinlik: 2.1,
                    zemin: t.surface2,
                    renk: renk(senaryolar[i].tur),
                  ),
                  const SizedBox(width: SipSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senaryolar[i].ad,
                          style: SipText.metin(13, w: 700, h: 1.35).copyWith(color: t.ink),
                        ),
                        Text(
                          '${senaryolar[i].alt} · ${sipTelefon(senaryolar[i].no)}',
                          style: SipText.metin(11, w: 600).copyWith(color: t.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
