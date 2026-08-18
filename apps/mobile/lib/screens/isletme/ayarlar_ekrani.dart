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
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
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
                // BÖLÜM BAŞLIĞI KALDIRILDI (kullanıcı eleştirisi 2026-08-18): sayfanın adı
                // zaten "Ayarlar" ve hemen altında ikinci kez "Ayarlar" yazıyordu. Tek kartlı
                // bir sayfada bölüm başlığı hiçbir şeyi ayırmaz, yalnız yer kaplar.
                const SizedBox(height: SipSpace.xl),
                AyarKarti(satirlar: [
                  if (session != null && onCikis != null)
                    AyarSatiri(
                      ikon: SipIcons.user,
                      baslik: 'Hesap',
                      altBaslik: 'Oturumunuz ve bağlı telefonlar',
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
                      altBaslik: 'Dükkân bilgileri ve tercihler',
                      onTap: () => _ac(IsletmeAyarlariEkrani(
                        db: widget.db,
                        writable: widget.writable,
                      )),
                    ),
                  AyarSatiri(
                    ikon: SipIcons.settings,
                    baslik: 'Uygulama',
                    altBaslik: 'Görünüm ve arayan tanıma',
                    onTap: () => _ac(UygulamaAyarlariEkrani(
                      koyuTema: widget.koyuTema,
                      onTema: widget.onTema,
                      onSihirbaz: widget.onSihirbaz,
                      onOlcumler: widget.onOlcumler,
                    )),
                  ),
                  AyarSatiri(
                    ikon: SipIcons.alert,
                    baslik: 'Bildirimler',
                    altBaslik: 'Hangi bildirimler gelsin, ne zaman sussun',
                    // Rol geçilir: kuryede yalnız ONA GELEN bildirim kategorileri listelenir.
                    // Rol bilinmiyorsa yönetici varsayılır — eksik bir anahtar göstermek,
                    // kuryenin hiç almayacağı bir anahtarı göstermekten daha az zararlı değil
                    // ama yanlış tarafa düşmemek için görünürlük tercih edildi.
                    onTap: () => _ac(BildirimAyarlariEkrani(
                      yoneticiMi: widget.rol != 'kurye',
                    )),
                  ),
                  AyarSatiri(
                    ikon: SipIcons.info,
                    baslik: 'Hakkında',
                    altBaslik: 'Sürüm bilgisi ve yenilikler',
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

