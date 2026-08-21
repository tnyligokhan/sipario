// HARİTANIN ÜSTÜNDEKİ KATMAN — kontrol düğmeleri ve atıf şeridi.
//
// NEDEN AYRI DOSYA: `siparis_harita.dart` haritanın VERİ ve KAMERA akışını yönetiyor; bunlar ise
// saf çizimdir (durumları yok, callback alırlar). Ayrı durunca 500 satır sınırı da korunuyor.
//
// Düğmeler tema bileşenlerinden kurulur (`SipIkonButon`): harita bir "yabancı" widget olsa da
// üstündeki arayüz uygulamanın dilini konuşmalı — Material FAB'ları buraya yamalanmış görünürdü.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Lucide `minus` — ikon SÖZLÜĞÜNDE yok, çünkü tasarımda harita hiç yoktu. `SipIcon` ham path
/// kabul eder (setin dışındaki tek seferlik şekiller için açık kapı); sözlüğe tasarımda
/// bulunmayan bir giriş eklemek, sözlüğün "tasarımın birebir kopyası" olma sözünü bozardı.
const String kHaritaEksiYolu = 'M5 12h14';

/// Lucide `scan` — dört köşe çerçevesi. "Duraklara sığdır" eyleminin evrensel işareti.
const String kHaritaSigdirYolu =
    'M8 3H5a2 2 0 0 0-2 2v3|M21 8V5a2 2 0 0 0-2-2h-3|M3 16v3a2 2 0 0 0 2 2h3|M16 21h3a2 2 0 0 0 2-2v-3';

/// Lucide `crosshair` — "Konumum". `pin` KULLANILMADI: pin bu ekranda DURAK demek, aynı şekli
/// kuryenin kendi konumu için de kullanmak iki farklı şeyi tek simgeye yüklerdi.
const String kHaritaKonumumYolu =
    'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|M22 12h-4|M6 12H2|M12 6V2|M12 22v-4';

/// Haritanın sağ altındaki dikey kontrol sütunu.
///
/// Düğmeler KARO YÜKLENMESE DE anlamlıdır: çevrimdışı gri zeminde bile pinler durur ve kamerayı
/// oynatmak (yakınlaş, duraklara sığdır) rota okumanın kendisidir.
class HaritaKontrolleri extends StatelessWidget {
  const HaritaKontrolleri({
    super.key,
    required this.onYakinlas,
    required this.onUzaklas,
    required this.onSigdir,
    required this.onKonumum,
  });

  final VoidCallback onYakinlas;
  final VoidCallback onUzaklas;
  final VoidCallback onSigdir;

  /// "Konumum" — HER ZAMAN çizilir. Konum alınamazsa düğme sessiz kalmaz, gerekçeyi söyler;
  /// bir eylemi "belki çalışmaz" diye gizlemek kullanıcıya o yeteneğin yokluğunu öğretirdi.
  final VoidCallback onKonumum;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dugme(ikon: SipIcons.plus, etiket: 'Yakınlaş', onTap: onYakinlas),
        const SizedBox(height: SipSpace.md),
        _Dugme(ikon: kHaritaEksiYolu, etiket: 'Uzaklaş', onTap: onUzaklas),
        const SizedBox(height: SipSpace.md),
        _Dugme(ikon: kHaritaSigdirYolu, etiket: 'Duraklara sığdır', onTap: onSigdir),
        const SizedBox(height: SipSpace.md),
        // Konum eylemi vurgulu: kuryenin haritada en sık sorduğu soru "ben neredeyim".
        _Dugme(
          ikon: kHaritaKonumumYolu,
          etiket: 'Konumum',
          onTap: onKonumum,
          renk: t.accent,
        ),
      ],
    );
  }
}

class _Dugme extends StatelessWidget {
  const _Dugme({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.renk,
  });

  final String ikon;
  final String etiket;
  final VoidCallback onTap;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return DecoratedBox(
      // Kenarlık zorunlu: düğmeler açık gri karoların üstünde duruyor, yüzey rengi tek başına
      // zeminden ayrılmıyordu (cihazda görüldü).
      decoration: BoxDecoration(
        borderRadius: SipRadius.brHap,
        border: Border.all(color: t.line2),
      ),
      child: SipIkonButon(
        ikon: ikon,
        etiket: etiket,
        cap: 40,
        ikonBoyut: 19,
        zemin: t.surface,
        renk: renk ?? t.ink,
        onTap: onTap,
      ),
    );
  }
}

/// Haritanın ALT ORTASINDAKİ birincil eylem — "Oto Sırala".
///
/// NEDEN BURADA (2026-08-01): eylem sıralama sheet'inin içinde duruyordu. Kullanıcı kontörlü bir
/// isteği, sonucunu göremeyeceği bir yerden tetikliyor ve listede beliren "1, 2, 3"e bakıp
/// rotanın mantıklı olup olmadığını kestiremiyordu. Haritada ise sıra ANINDA pinlere yazılır:
/// düğmeye basan kişi sonucu bastığı ekranda görür.
///
/// Düğme HER ZAMAN çizilir; kullanılamıyorsa PASİF olur ve [neden] hemen ÜSTÜNDE yazar
/// (görünürlük ≠ kullanılabilirlik — kapı korunur, yetenek gizlenmez). Gerekçe düğmenin ALTINA
/// değil üstüne konur: altta karo atfı durur ve ikisi üst üste binerdi.
class HaritaOtoDugmesi extends StatelessWidget {
  const HaritaOtoDugmesi({
    super.key,
    required this.etiket,
    required this.onTap,
    this.neden,
    this.yukleniyor = false,
  });

  final String etiket;
  final VoidCallback onTap;

  /// Kullanılamama gerekçesi. `null` = düğme etkin.
  final String? neden;

  /// İstek yolda: düğme pasifleşir ve dönen halka çizer. Kontörlü bir eylemde ikinci dokunuş
  /// ikinci hak demektir — beklerken sessiz kalmak pahalıya patlar.
  final bool yukleniyor;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final kilitli = neden != null || yukleniyor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (neden != null)
          Padding(
            padding: const EdgeInsets.only(bottom: SipSpace.md),
            child: DecoratedBox(
              // Atıf şeridiyle aynı yarı saydam yüzey: karoların üstüne doğrudan yazılan gri
              // metin açık/koyu bölgelerde kayboluyordu.
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.92),
                borderRadius: SipRadius.brHap,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 5),
                child: Text(
                  neden!,
                  textAlign: TextAlign.center,
                  style: SipText.metin(12, w: 600).copyWith(color: t.muted),
                ),
              ),
            ),
          ),
        SipButon(
          etiket: etiket,
          ikon: SipIcons.bolt,
          genisle: false,
          yukleniyor: yukleniyor,
          onTap: kilitli ? null : onTap,
        ),
      ],
    );
  }
}

/// Karo sağlayıcı atfı — HUKUKİ ZORUNLULUK, kaldırılamaz (OSM ODbL + CARTO kullanım şartları).
///
/// Metin SÖZLEŞMEDİR. Sönük ve küçüktür ama okunur: yarı saydam bir yüzeyin üstünde durur, çünkü
/// karoların üstüne doğrudan yazılan gri metin açık/koyu bölgelerde kayboluyordu.
class HaritaAtfi extends StatelessWidget {
  const HaritaAtfi({super.key});

  static const String metin = '© OpenStreetMap, © CARTO';

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.82),
        borderRadius: SipRadius.brHap,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: 3),
        child: Text(metin, style: SipText.metin(10, w: 600).copyWith(color: t.muted)),
      ),
    );
  }
}
