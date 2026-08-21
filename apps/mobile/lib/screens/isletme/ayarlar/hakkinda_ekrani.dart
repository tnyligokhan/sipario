// AYARLAR → HAKKINDA — sürüm · sunucu · lisans · yenilikler.
//
// ══ MAĞAZA KURALI (pazarlıksız) ════════════════════════════════════════════════════════════
// Bu sayfada abonelik / ödeme / satın alma / fiyat / üyelik bağlantısı OLAMAZ. Lisans yalnız
// NÖTR bir bilgi satırı olarak durur ("N gün kaldı"); hiçbir eyleme bağlanmaz. Yasaklı sözcük
// testleri (`Abone`, `Satın al`, `Üye ol`, `Kaydol`) ayarların BEŞ sayfasını da tarar.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../data/app_database.dart';
import '../../../theme/components/states.dart';
import '../../../theme/tokens.dart';
import '../isletme_atomlari.dart';
import '../surum_notlari_ekrani.dart';

/// Uygulama sürümü — APK'nın KENDİSİNDEN okunur, elle yazılmaz.
///
/// Eskiden burada `'Sipario 3.2'` sabiti duruyordu ve APK'daki gerçek sürümle HİÇBİR bağı
/// yoktu: 2026-07-27'de dört ayrı APK derlendi, dördü de aynı sürümü gösteriyordu ve sahadaki
/// bayi hangisini test ettiğini söyleyemiyordu. İki yerde ayrı yazılan bir sayı, biri
/// güncellenip diğeri unutulduğunda sessizce yalan söyler.
///
/// `package_info_plus` Android'de `PackageManager`dan okur — yani `build.gradle.kts`in git
/// commit sayısından türettiği yapı numarası ne ise bayi onu görür. YEREL bir sorgudur, ağ
/// kullanmaz; offline-first çizgisi korunur.
///
/// YAPI NUMARASI GÖSTERİLMEK ZORUNDA: saha testinde "hangi APK?" sorusunu tek başına o
/// cevaplıyor. Sürüm adı iki derleme arasında aynı kalabilir, yapı numarası kalamaz.
Future<String> siparioSurumunuOku() async {
  try {
    final bilgi = await PackageInfo.fromPlatform();
    final ad = bilgi.version.trim();
    final yapi = bilgi.buildNumber.trim();
    if (ad.isEmpty) return 'Sipario';
    return yapi.isEmpty ? 'Sipario $ad' : 'Sipario $ad ($yapi)';
  } catch (_) {
    // Platform kanalı yoksa (test ortamı, iOS'ta eksik kayıt) ÇÖKME — nötr metne düş.
    // Sayfanın tamamı bir sürüm satırı yüzünden açılamaz hâle gelemez.
    return 'Sipario';
  }
}

class HakkindaEkrani extends StatelessWidget {
  const HakkindaEkrani({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Hakkında', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              // BÖLÜM BAŞLIĞI YOK ve bilinçli: sayfa başlığı zaten "Hakkında" ve kartın ilk
              // satırı "Sürüm". Araya bir "Sürüm" başlığı koymak aynı kelimeyi iki kez üst
              // üste yazıyordu — ekranda tekrar, testte de belirsizlik (hangi "Sürüm"?).
              child: SipGovde(children: [
                const SizedBox(height: 18),
                HakkindaKarti(db: db),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sürüm + lisans kartı. Lisans NÖTR bilgidir: gün sayısı ve kalan oto-sıralama hakkı
/// gösterilir, hiçbir eyleme bağlanmaz (mağaza kuralı).
///
/// Veri AKIŞTAN okunur, tek atıştan DEĞİL: `validUntilIso` ve `routeCredits` SUNUCU SAHİPLİ
/// alanlardır, senkron sırasında değişirler. `syncState()` tek atışıyla okunduğunda ekran
/// senkrondan sonra bayat değerde kalıyordu (bir vardiyada iki kez görüldü).
class HakkindaKarti extends StatelessWidget {
  const HakkindaKarti({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncMetaData>(
      stream: db.watchSyncState(),
      builder: (context, snap) {
        final meta = snap.data;
        return AyarKarti(satirlar: [
          // Sürüm APK'dan okunuyor (asenkron); gelene kadar satır yerini korur ve nötr
          // 'Sipario' yazar — yer değiştiren/zıplayan bir satır yerine sabit bir satır.
          FutureBuilder<String>(
            future: siparioSurumunuOku(),
            builder: (context, surum) => AyarSatiri(
              baslik: 'Sürüm',
              altBaslik: surum.data ?? 'Sipario',
            ),
          ),
          AyarSatiri(baslik: 'Sunucu', altBaslik: sunucuSurumuMetni(meta)),
          AyarSatiri(baslik: 'Lisans', altBaslik: lisansMetni(meta)),
          // "Yenilikler" AYRI VE ETİKETLİ bir satır; "Sürüm" satırını dokunulabilir yapmak
          // daha az yer kaplardı ama keşfedilebilir olmazdı — bir bayi bilgi satırına
          // dokunmayı denemez. Chevron `onTap` verildiği için kendiliğinden çizilir.
          AyarSatiri(
            baslik: 'Yenilikler',
            altBaslik: 'Bu güncellemede ne değişti?',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SurumNotlariEkrani()),
            ),
          ),
        ]);
      },
    );
  }
}

/// "Sunucu" satırının metni — son senkron turunda görülen API sözleşme sürümü.
///
/// NEDEN "Sürüm"ÜN YANINDA AYRI BİR SATIR: uygulama sürümü ile API sürümü İKİ AYRI HATTIR ve
/// birbirine eşitlenmez (kural: CLAUDE.md → "Sürümleme"). İkisini tek satırda birleştirmek —
/// "Sipario 0.10.0 / 1.0.0" gibi — okuyanı bir numaranın diğerini takip ettiğine inandırırdı;
/// bu depoda daha önce ödenmiş bir hata sınıfı: **anlamı farklı iki sayıyı aynı kelimeyle
/// taşımak.** Ayrı etiket, ayrı hat.
///
/// Ekran metni İDDİA ETMEZ (aynı yazılı kural): satır "sunucu güncel" ya da "uyumlu" demez —
/// yalnız en son GÖRÜLEN numarayı yazar. Değer önbellekten okunur, o yüzden ağ yokken de
/// doludur; hiç senkron olmamış cihazda ise uydurmak yerine bilinmediğini söyler.
///
/// Ekrandan BAĞIMSIZ (saf testle sınanır).
String sunucuSurumuMetni(SyncMetaData? meta) {
  final surum = meta?.apiVersion;
  if (surum == null || surum.trim().isEmpty) return 'Henüz bağlanılmadı';
  return 'API ${surum.trim()}';
}

/// Lisans satırının metni — tasarım `s-ayarlar.jsx:50` "248 gün kaldı · oto sıralama 34 hak".
///
/// Ekrandan BAĞIMSIZ (saf testle sınanır). Oto sıralama parçası yalnız özellik AÇIKKEN
/// (`routeCreditsMonthly > 0`) yazılır — kapalı bayide "0 hak" görünmesi yanlış olurdu.
/// [simdi] yalnız test içindir.
String lisansMetni(SyncMetaData? meta, {DateTime? simdi}) {
  final parcalar = <String>[_kalanSureMetni(meta, simdi: simdi)];
  if (meta != null && meta.routeCreditsMonthly > 0) {
    parcalar.add('oto sıralama ${meta.routeCredits} hak');
  }
  return parcalar.join(', ');
}

String _kalanSureMetni(SyncMetaData? meta, {DateTime? simdi}) {
  final bitis = meta?.validUntilIso;
  if (bitis == null) return 'Durum bilinmiyor';
  final t = DateTime.tryParse(bitis);
  if (t == null) return 'Durum bilinmiyor';
  final kalan = t.difference(simdi ?? DateTime.now()).inDays;
  if (kalan < 0) return 'Süre doldu, yeni kayıt eklenemiyor';
  return '$kalan gün kaldı';
}
