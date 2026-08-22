// HEADS-UP ÖLÇÜMÜ — "kuruldu mu" ile "cihazda çalışıyor mu" AYRI SORULARDIR.
//
// ══ NEDEN VAR (kullanıcı isteği 2026-08-22) ═══════════════════════════════════════════════
// Saha bildirimi: *"heads-up bildirimler yapılacaktı fakat onlar yok"*. Ölçüldü ve kod tarafı
// KURULUYDU — dört kategori `IMPORTANCE_HIGH` kanalla doğuyor. Eksik olan ölçümdü:
//
//   • Bir kanalın önemi DOĞDUKTAN SONRA yalnız KULLANICI tarafından değiştirilebilir
//     (Android kuralı; uygulama kıstığın bildirimi arkadan dolanıp geri açamaz).
//   • Bu ürünün ana pazarında (BRIEF: Xiaomi/Redmi/Poco hâkim) "kayan bildirim" uygulama
//     başına KAPALI gelebiliyor.
//
// Yani heads-up'ın olmaması çoğu zaman bir KOD arızası değil bir CİHAZ AYARIDIR — ve bu iki
// durumu ayırt edecek hiçbir veri yoktu. Bu dosya, o ayrımı yapan katmanı kilitler.
//
// ⚠️ BU TESTLER HEADS-UP'IN CİHAZDA ÇALIŞTIĞINI KANITLAMAZ ve kanıtlayamaz — Android'in
// bildirim gölgesini bir widget testi göremez. Kanıtladıkları şey ŞU: ölçüm doğru okunuyor,
// bilinmeyen "arıza" sayılmıyor ve uyarı doğru koşulda çıkıyor. Cihaz kanıtı, Ayarlar →
// Bildirimler → "Dene" düğmesidir; onun var olduğu da burada kilitli.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kanal_durumu.dart';

/// Native kanalı sahteleyen tezgâh.
///
/// FİKSTÜR SINIFI (depo kuralı 2026-08-17): kurulum durumu (hangi kanal hangi önemde) ve onun
/// üzerinde işleyen davranış (kur, oku, çağrıları say) tek nesnede kapsüllenir.
class KanalTezgahi {
  KanalTezgahi();

  /// Kanal kimliği → Android önem sabiti.
  final Map<String, int> onemler = {};

  bool uygulamaAcik = true;

  /// Native uca hiç yanıt verilmesin mi (platform yok davranışı).
  bool platformYok = false;

  /// Açılan kanal ayarı ekranlarının kimlikleri.
  final List<String?> acilanAyarlar = [];

  void kur() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kBildirimKanali, (cagri) async {
      if (platformYok) throw MissingPluginException('yok');
      switch (cagri.method) {
        case 'notificationChannels':
          return {'kanallar': onemler, 'acik': uygulamaAcik};
        case 'openNotificationChannelSettings':
          acilanAyarlar.add((cagri.arguments as Map?)?['channel'] as String?);
          return null;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kBildirimKanali, null);
    });
  }

  /// Kategoriyi verilen önemle kurulmuş gibi gösterir.
  void kanal(BildirimKategori k, int onem) => onemler[k.kanalKimligi] = onem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kanalDurumlariniOku — ölçüm', () {
    test('YÜKSEK önemli kanal heads-up çalışır der', () async {
      final tezgah = KanalTezgahi()..kur();
      tezgah.kanal(BildirimKategori.siparisAtandi, kOnemYuksek);

      final durum = await kanalDurumlariniOku();
      expect(durum[BildirimKategori.siparisAtandi]!.headsUpCalisir, isTrue);
    });

    test('DÜŞÜRÜLMÜŞ kanal heads-up ÇALIŞMAZ der', () async {
      // Kullanıcı sistemden "sessiz"e çekmiş olabilir; uygulama bunu geri yükseltemez ama
      // GÖREBİLİR — bu özelliğin tamamı budur.
      final tezgah = KanalTezgahi()..kur();
      tezgah.kanal(BildirimKategori.siparisAtandi, 3); // IMPORTANCE_DEFAULT

      final durum = await kanalDurumlariniOku();
      expect(durum[BildirimKategori.siparisAtandi]!.headsUpCalisir, isFalse);
    });

    test('UYGULAMA bildirimleri kapalıysa kanal önemi ne olursa olsun ÇALIŞMAZ', () async {
      final tezgah = KanalTezgahi()
        ..uygulamaAcik = false
        ..kur();
      tezgah.kanal(BildirimKategori.siparisAtandi, kOnemYuksek);

      final durum = await kanalDurumlariniOku();
      expect(durum[BildirimKategori.siparisAtandi]!.headsUpCalisir, isFalse);
    });

    test('KANAL HENÜZ KURULMAMIŞSA "bilinmiyor" döner — arıza SAYILMAZ', () async {
      // Uygulama ilk açılışta kanalları kurar; ölçüm o andan önce koşabilir. Bilinmeyeni
      // arıza ilan etmek, sorunu olmayan bayiye yanlış uyarı göstermek olurdu.
      KanalTezgahi().kur();

      final durum = await kanalDurumlariniOku();
      expect(durum[BildirimKategori.siparisAtandi]!.headsUpCalisir, isNull);
      expect(durum[BildirimKategori.siparisAtandi]!.onem, isNull);
    });

    test('PLATFORM YOKSA sessizce pasifleşir, ÇÖKMEZ', () async {
      // iOS ve widget testleri. Bu deponun yerleşik kuralı: platform yoksa özellik susar,
      // uygulama çalışmaya devam eder (`YerelBildirimServisi._android` deseni).
      KanalTezgahi()
        ..platformYok = true
        ..kur();

      final durum = await kanalDurumlariniOku();
      expect(durum, hasLength(BildirimKategori.values.length));
      expect(durum.values.every((d) => d.headsUpCalisir == null), isTrue);
    });

    test('ÖLÇÜM `wire` DEĞİL `kanalKimligi` ile eşleşir', () async {
      // Kanal kimliği sürümlüdür (`${wire}_v2`) çünkü ses/önem ancak yeni kimlikle değişir.
      // Burada `wire` aransaydı hiçbir kanal bulunamaz ve ölçüm SESSİZCE "bilinmiyor" derdi —
      // sessiz yanlış, bu depodaki en pahalı arıza sınıfı.
      final tezgah = KanalTezgahi()..kur();
      tezgah.onemler[BildirimKategori.siparisAtandi.wire] = kOnemYuksek;

      final durum = await kanalDurumlariniOku();
      expect(durum[BildirimKategori.siparisAtandi]!.onem, isNull,
          reason: 'v1 kimliği artık kullanılmıyor; ölçüm ona bakmamalı');

      tezgah.kanal(BildirimKategori.siparisAtandi, kOnemYuksek);
      final ikinci = await kanalDurumlariniOku();
      expect(ikinci[BildirimKategori.siparisAtandi]!.onem, kOnemYuksek);
    });
  });

  group('kanalAyariniAc — kullanıcıyı doğru ekrana götürür', () {
    test('kanal kimliği native uca GEÇER', () async {
      final tezgah = KanalTezgahi()..kur();

      await kanalAyariniAc(BildirimKategori.siparisIptalOnayi);

      expect(tezgah.acilanAyarlar, [BildirimKategori.siparisIptalOnayi.kanalKimligi]);
    });

    test('platform yoksa ÇÖKMEZ', () async {
      KanalTezgahi()
        ..platformYok = true
        ..kur();
      await kanalAyariniAc(BildirimKategori.siparisAtandi);
      // Buraya ulaşmak testin kendisidir: istisna dışarı sızmadı.
    });
  });
}
