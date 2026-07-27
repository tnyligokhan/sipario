// Müşteri formunun YAZMA işlemleri — ekran (customer_form_screen.dart) yalnız alan toplar,
// kalıcılık burada. Böylece form dosyası 500 satırın altında kalır ve yazma yolu tek yerden
// okunur.
//
// Yazma daima repo → outbox. Adres güncelleme artık repo'nun `updateAddress`'i üzerinden gider
// (backend ajanı ekledi). Telefon silme (`removePhone`) repo'da HENÜZ YOK — onun için aşağıda
// geçici bir köprü var; yerel yazma + outbox olayını AYNI transaction'da yapar (Faz 2 atomikliği)
// ve repo'daki `_insertPhone` yüküyle simetrik payload üretir. Repo metodu gelince silinecek.

import 'package:drift/drift.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../data/app_database.dart';
import '../../data/ids.dart';
import '../../data/outbox.dart';
import '../../repo/customer_repository.dart';

/// Formun topladığı alanlar. Telefonlar E.164 ("+905321112233"), para yok, konum opsiyonel.
class MusteriFormVerisi {
  const MusteriFormVerisi({
    required this.ad,
    required this.telefonlar,
    this.adres,
    this.bolge,
    this.not,
    this.lat,
    this.lng,
  });

  final String ad;
  final List<String> telefonlar;
  final String? adres;
  final String? bolge;
  final String? not;
  final double? lat;
  final double? lng;
}

/// Yeni müşteri — ilk telefon birincil, adres varsa birincil "Ev".
Future<String> musteriOlustur(AppDatabase db, MusteriFormVerisi v) {
  final adres = v.adres?.trim();
  return CustomerRepository(db).create(
    name: v.ad,
    note: v.not,
    phones: [
      for (var i = 0; i < v.telefonlar.length; i++)
        PhoneInput(
          phoneE164: v.telefonlar[i],
          label: i == 0 ? 'Cep' : 'Telefon ${i + 1}',
          isPrimary: i == 0,
        ),
    ],
    addresses: [
      if (adres != null && adres.isNotEmpty)
        AddressInput(
          addressText: adres,
          label: 'Ev',
          region: v.bolge,
          lat: v.lat,
          lng: v.lng,
          isPrimary: true,
        ),
    ],
  );
}

/// Mevcut müşteriyi güncelle: ad/not, telefon listesi (ekle/sil) ve birincil adres.
Future<void> musteriGuncelle(
  AppDatabase db, {
  required String customerId,
  required MusteriFormVerisi v,
  required List<CustomerPhone> eskiTelefonlar,
  CustomerAddressesData? eskiAdres,
}) async {
  final repo = CustomerRepository(db);
  await repo.rename(customerId, name: v.ad, note: v.not);

  // Telefonlar: numara bazında diff. Kalanlar dokunulmaz (id'leri korunur), yeniler eklenir,
  // formdan çıkarılanlar tombstone'lanır.
  final yeni = v.telefonlar.toSet();
  final eski = {for (final p in eskiTelefonlar) p.phoneE164: p};
  for (final p in eskiTelefonlar) {
    if (!yeni.contains(p.phoneE164)) await telefonSil(db, p.id);
  }
  for (var i = 0; i < v.telefonlar.length; i++) {
    final no = v.telefonlar[i];
    if (eski.containsKey(no)) continue;
    await repo.addPhone(customerId,
        PhoneInput(phoneE164: no, label: i == 0 ? 'Cep' : 'Telefon ${i + 1}', isPrimary: i == 0));
  }

  final adres = v.adres?.trim();
  if (adres == null || adres.isEmpty) return;
  final girdi = AddressInput(
    addressText: adres,
    label: eskiAdres?.label ?? 'Ev',
    region: v.bolge,
    lat: v.lat,
    lng: v.lng,
    isPrimary: true,
  );
  if (eskiAdres == null) {
    await repo.addAddress(customerId, girdi);
  } else if (adres != eskiAdres.addressText ||
      v.bolge != eskiAdres.region ||
      v.lat != eskiAdres.lat ||
      v.lng != eskiAdres.lng) {
    await repo.updateAddress(eskiAdres.id, customerId, girdi);
  }
}

/// Müşterinin birincil adresine konum yazar (detaydaki "Konum Al" akışı). Adres metni, bölge ve
/// etiket OLDUĞU GİBİ geri yazılır — bu akış yalnız koordinat ekler.
Future<void> konumKaydet(AppDatabase db, CustomerAddressesData adres, double lat, double lng) =>
    CustomerRepository(db).updateAddress(
      adres.id,
      adres.customerId,
      AddressInput(
        addressText: adres.addressText,
        label: adres.label,
        region: adres.region,
        lat: lat,
        lng: lng,
        isPrimary: adres.isPrimary,
      ),
    );

/// Bu numara BAŞKA bir müşteride kayıtlı mı? Kayıtlıysa o müşterinin adını döner (CSS `.ym-err`
/// mükerrer uyarısı). Eşleşme kuralı arayan-tanımayla aynı: son 10 hane.
Future<String?> mukerrerTelefonSahibi(
  AppDatabase db,
  String phoneE164, {
  String? haricCustomerId,
}) async {
  final last10 = phoneLast10(phoneE164);
  if (last10.length < 10) return null;
  final q = db.select(db.customerPhones).join([
    innerJoin(db.customers, db.customers.id.equalsExp(db.customerPhones.customerId)),
  ])
    ..where(db.customerPhones.phoneLast10.equals(last10) &
        db.customerPhones.deletedAt.isNull() &
        db.customers.deletedAt.isNull());
  final rows = await q.get();
  for (final r in rows) {
    final c = r.readTable(db.customers);
    if (c.id != haricCustomerId) return c.name;
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// SESLİ GİRİŞ — bayi isteği: "inputların yanında mikrofon işareti olabilir"
// ═══════════════════════════════════════════════════════════════════════════════════════════
//
// Esnafın klavye toleransı düşük; ad ve adres yazmak siparişin en yavaş adımı. Mikrofon
// alanların YANINDA durur (SipInput'un içine gömülmez — o widget tema katmanının ve trailing
// yuvası yok).
//
// KURALLAR:
//  • Dil DAİMA Türkçe. Cihaz dilinde bırakmak yanlış tanıma demektir; cihazda Türkçe yoksa
//    özellik KAPALI sayılır ve kullanıcıya söylenir (sessizce İngilizce dinlemez).
//  • Çevrimdışı: Android tanımayı cihaza göre bulutta ya da cihaz içinde yapar. Zorla cihaz-içi
//    (`onDevice: true`) İSTENMEZ — Türkçe çevrimdışı modeli yüklü olmayan telefonlarda özellik
//    hiç çalışmazdı. Bunun yerine ağ hatası DÜRÜSTÇE söylenir: "internet gerekiyor, elle yazın".
//    Offline-first kırmızı çizgisi korunur, çünkü sesli giriş bir KOLAYLIKTIR: kapalıyken form
//    elle doldurulur, hiçbir iş akışı bloklanmaz.
//  • Ekran bu sınıfın ötesindeki hiçbir eklenti tipini görmez — widget testleri platform kanalı
//    olmadan koşabilsin diye [sesliGirisUret] dikişinden sahte verilir.

/// Sesli girişin ekrana anlattığı durum.
enum SesDurumu {
  /// Henüz hazırlanmadı (ilk dokunuşta izin istenecek).
  bilinmiyor,

  /// Kullanılabilir — dokunulunca dinler.
  hazir,

  /// Dinliyor.
  dinliyor,

  /// Kullanılamaz (izin yok / cihazda tanıma yok / Türkçe yok). Sebep [SesliGiris.gerekce]de.
  kapali,
}

/// Sesli giriş motorunun ekrana bakan yüzü. Testler [sesliGirisUret] ile sahtesini verir.
abstract class SesliGiris {
  SesDurumu get durum;

  /// Kapalıysa kullanıcıya gösterilecek Türkçe gerekçe.
  String? get gerekce;

  /// İzin ister ve motoru kurar. `true` → dinlemeye hazır.
  Future<bool> hazirla();

  /// Dinlemeye başlar. [onMetin] her (kısmi ve nihai) tanımada çağrılır — ekran alanı canlı
  /// tazeler. [onBitis] dinleme durduğunda çağrılır; gerekçe null değilse kullanıcıya söylenir.
  Future<void> dinle({
    required void Function(String metin) onMetin,
    required void Function(String? gerekce) onBitis,
  });

  Future<void> durdur();

  void birak();
}

/// Uygulamanın kullandığı üretici. Widget testleri bunu sahte bir [SesliGiris] ile değiştirir
/// (`uriAcici` / `tutamacDeposu` deseninin aynısı — eklenti çağrısı tek dikiş yerinden geçer).
SesliGiris Function() sesliGirisUret = SpeechSesliGiris.new;

/// `speech_to_text` üzerine ince sarmalayıcı.
class SpeechSesliGiris implements SesliGiris {
  SpeechSesliGiris();

  final stt.SpeechToText _motor = stt.SpeechToText();

  SesDurumu _durum = SesDurumu.bilinmiyor;
  String? _gerekce;
  String? _yerelKod;

  /// Dinleme bittiğinde bir KEZ çağrılır; motor hem `onStatus` hem `onResult(final)` yolundan
  /// bitiş bildirebiliyor, iki kez haber vermek ekranı yanlış duruma sokardı.
  void Function(String? gerekce)? _bitisKancasi;

  @override
  SesDurumu get durum => _durum;

  @override
  String? get gerekce => _gerekce;

  @override
  Future<bool> hazirla() async {
    if (_durum == SesDurumu.hazir) return true;
    try {
      final acildi = await _motor.initialize(
        onError: (e) => _bitir(_hataMetni(e.errorMsg)),
        onStatus: (s) {
          // 'done' / 'notListening' — kullanıcı sustu ya da sistem kapattı.
          if (s == 'done' || s == 'notListening') _bitir(null);
        },
      );
      if (!acildi) {
        return _kapat('Mikrofon izni verilmedi ya da bu telefonda ses tanıma yok');
      }
      // Türkçe YOKSA hiç dinlemeyiz: cihaz dilinde tanıma "Ayşe Kaya"yı "I shall car" yapar.
      final yereller = await _motor.locales();
      final tr = yereller.where((l) => l.localeId.toLowerCase().startsWith('tr'));
      if (tr.isEmpty) {
        return _kapat('Türkçe ses tanıma bu telefonda yüklü değil');
      }
      _yerelKod = tr.first.localeId;
      _durum = SesDurumu.hazir;
      _gerekce = null;
      return true;
    } on Object {
      // Eklenti yok (test/masaüstü) ya da platform patladı: ÇÖKME YOK, özellik kapalı.
      return _kapat('Ses tanıma bu cihazda kullanılamıyor');
    }
  }

  bool _kapat(String neden) {
    _durum = SesDurumu.kapali;
    _gerekce = neden;
    return false;
  }

  @override
  Future<void> dinle({
    required void Function(String metin) onMetin,
    required void Function(String? gerekce) onBitis,
  }) async {
    if (!await hazirla()) {
      onBitis(_gerekce);
      return;
    }
    _bitisKancasi = onBitis;
    _durum = SesDurumu.dinliyor;
    try {
      await _motor.listen(
        onResult: (r) => onMetin(r.recognizedWords),
        listenOptions: stt.SpeechListenOptions(
          localeId: _yerelKod,
          // Kısmi sonuç AÇIK: kullanıcı konuşurken metnin alana düştüğünü görür — sessizce
          // dinleyen mikrofon hem güven sorunudur hem "çalışıyor mu?" sorusunu doğurur.
          partialResults: true,
          // Ad/adres/not tek komut değil, serbest metindir.
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          // Sürekli açık mikrofon YOK: 30 sn üst sınır, 3 sn sessizlikte kapanır.
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } on Object {
      _bitir('Ses tanıma başlatılamadı');
    }
  }

  @override
  Future<void> durdur() async {
    if (_durum != SesDurumu.dinliyor) return;
    try {
      await _motor.stop();
    } on Object {
      // yut — durum aşağıda zaten toparlanıyor
    }
    _bitir(null);
  }

  void _bitir(String? neden) {
    if (_durum == SesDurumu.dinliyor) _durum = SesDurumu.hazir;
    if (neden != null && neden == _izinGerekce) _kapat(neden);
    final kanca = _bitisKancasi;
    _bitisKancasi = null;
    kanca?.call(neden);
  }

  @override
  void birak() {
    _bitisKancasi = null;
    try {
      _motor.cancel();
    } on Object {
      // yut
    }
  }

  static const String _izinGerekce = 'Mikrofon izni verilmedi — telefon ayarlarından açın';

  /// Motorun ham hata kodunu kullanıcının anlayacağı tek cümleye çevirir. Ağ hataları
  /// ÖZELLİKLE ayrılır: bu uygulama offline-first, kullanıcı "neden çalışmadı"yı bilmeli.
  static String _hataMetni(String kod) => switch (kod) {
        'error_network' || 'error_network_timeout' || 'error_server' =>
          'Ses tanıma için internet gerekiyor — çevrimdışıyken elle yazın',
        'error_permission' || 'error_insufficient_permissions' => _izinGerekce,
        'error_no_match' || 'error_speech_timeout' => 'Anlaşılmadı, tekrar deneyin',
        'error_language_not_supported' || 'error_language_unavailable' =>
          'Türkçe ses tanıma bu telefonda yüklü değil',
        'error_busy' => 'Mikrofon şu an başka bir uygulamada',
        _ => 'Ses tanıma başarısız oldu',
      };
}

/// Tanınan metni alana yazarken kullanılan birleştirme.
///
/// KURAL: alan doluysa metin SONUNA eklenir, ÜZERİNE YAZILMAZ. Gerekçe: tanıma yanılabilir ve
/// kullanıcının elle yazdığını sessizce silmek geri alınamaz bir kayıptır; fazladan kelimeyi
/// silmek ise tek dokunuş. Bu, projenin "kayıt ezilmez, düzeltme eklenerek yapılır"
/// disiplininin arayüz karşılığıdır.
///
/// [taban] dinleme BAŞLARKEN alanda duran metindir — her kısmi sonuçta yeniden birleştirilir,
/// böylece konuşma sürerken alan büyür ama önceki içerik tekrarlanmaz.
String sesMetniBirlestir(String taban, String taninan) {
  final t = taban.trimRight();
  final y = taninan.trim();
  if (y.isEmpty) return taban;
  return t.isEmpty ? y : '$t $y';
}

// ── Geçici köprü (bkz. dosya başlığı) ──────────────────────────────────────────────────────

/// Telefonu tombstone'lar (fiziksel silme YOK — LWW/senkron için deleted_at işaretlenir).
Future<void> telefonSil(AppDatabase db, String phoneId) async {
  final meta = await db.syncState();
  final at = correctedNowIso(meta.serverTimeOffsetMs);
  await db.transaction(() async {
    await (db.update(db.customerPhones)..where((t) => t.id.equals(phoneId))).write(
      CustomerPhonesCompanion(
        deletedAt: Value(at),
        updatedOccurredAt: Value(at),
        updatedDeviceId: Value(meta.deviceId),
      ),
    );
    await enqueueOutbox(db,
        entityType: 'customer_phone',
        op: 'delete',
        entityId: phoneId,
        occurredAt: at,
        deviceId: meta.deviceId,
        payload: {'id': phoneId});
  });
}
