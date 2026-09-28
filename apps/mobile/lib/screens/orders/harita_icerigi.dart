// HARİTANIN İÇERİĞİ — motordan BAĞIMSIZ, saf Dart değer nesneleri (2026-09-28).
//
// NEDEN VAR: harita yerel bir motorla (Yandex MapKit) çiziliyor ve pinler Flutter widget'ı
// değil, motorun kendi nesneleri. "Ne çizilecek" sorusunun cevabı bu dosyada, "nasıl çizilecek"
// sorusunun cevabı `harita_yandex.dart`ta durur. Ayrılmasının iki kazancı var:
//  1. İçerik (numaralar, rota sırası, seçili durak, bayat kurye) widget testine gerek kalmadan
//     birim testiyle sınanır — yerel harita widget testinde çizilemez.
//  2. Motor değişirse ekran ve testler bu tipleri konuşmaya devam eder (2026-09-28'de aynı gün
//     MapLibre → Yandex geçişinde bu dosya motorla birlikte DEĞİŞMEDİ, sözleşme işe yaradı).

import 'dart:math' as math;

/// Haritadaki bir nokta. Motorun kendi `LatLng`i KULLANILMAZ: ekran ve testler motoru
/// tanımasın (bkz. dosya başlığı).
class HaritaNoktasi {
  const HaritaNoktasi(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is HaritaNoktasi && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'HaritaNoktasi($lat, $lng)';
}

/// Numaralı durak. [no] listedeki sıradır (1'den başlar) ve pinin üstünde yazan sayıdır.
class DurakIsareti {
  const DurakIsareti({
    required this.id,
    required this.no,
    required this.nokta,
    required this.ad,
  });

  /// Sipariş kimliği — dokunuş bununla geri bildirilir.
  final String id;
  final int no;
  final HaritaNoktasi nokta;

  /// Yakınlaşınca pinin altında yazan müşteri adı.
  final String ad;
}

/// Canlı kurye. [bayatlik] boş değilse konum bayattır ("7 dk önce") ve pin soluk çizilir.
class KuryeIsareti {
  const KuryeIsareti({
    required this.id,
    required this.nokta,
    required this.ad,
    required this.taze,
    this.bayatlik = '',
  });

  final String id;
  final HaritaNoktasi nokta;
  final String ad;
  final bool taze;
  final String bayatlik;

  /// Pinin altındaki yazı: taze konumda yalnız ad, bayatta ad + ne kadar eski olduğu. Bayat
  /// konum taze gibi görünseydi patron 40 dakika önceki noktaya bakıp kuryeyi orada sanırdı.
  String get etiket => taze || bayatlik.isEmpty ? ad : '$ad\n$bayatlik';
}

/// Dokunulan işaretin kimliği — katman kimliğine değil ÖNEKE bakılarak çözülür, çünkü bir
/// durağın hem dairesi hem numarası dokunulabilir.
sealed class HaritaDokunusu {
  const HaritaDokunusu(this.id);
  final String id;

  static const String durakOneki = 'd:';
  static const String kuryeOneki = 'k:';

  /// Motorun bildirdiği özellik kimliğini çözer; tanınmayan kimlik null (ör. taban haritanın
  /// kendi etiketleri).
  static HaritaDokunusu? coz(String ozellikId) {
    if (ozellikId.startsWith(durakOneki)) {
      return DurakDokunusu(ozellikId.substring(durakOneki.length));
    }
    if (ozellikId.startsWith(kuryeOneki)) {
      return KuryeDokunusu(ozellikId.substring(kuryeOneki.length));
    }
    return null;
  }
}

class DurakDokunusu extends HaritaDokunusu {
  const DurakDokunusu(super.id);
}

class KuryeDokunusu extends HaritaDokunusu {
  const KuryeDokunusu(super.id);
}

/// Kameranın gideceği yer: ya bir kutu ya da (tek nokta / çok dar küme) bir merkez + zoom.
class HaritaKadraji {
  const HaritaKadraji._({this.guneyBati, this.kuzeyDogu, this.merkez, this.zoom});

  /// Noktaları çevreleyen kadraj. Küme [darEsik] dereceden darsa kutu yerine merkez + [yakin]
  /// zoom döner: sıfır alanlı bir kutuya sığdırmak kamerayı dünyanın sonuna kadar yakınlaştırırdı.
  factory HaritaKadraji.noktalardan(
    Iterable<HaritaNoktasi> noktalar, {
    double darEsik = 0.002,
    double yakin = 16,
  }) {
    final liste = noktalar.toList();
    if (liste.isEmpty) {
      throw ArgumentError('Kadraj en az bir nokta ister');
    }
    var guney = liste.first.lat, kuzey = liste.first.lat;
    var bati = liste.first.lng, dogu = liste.first.lng;
    for (final n in liste.skip(1)) {
      guney = math.min(guney, n.lat);
      kuzey = math.max(kuzey, n.lat);
      bati = math.min(bati, n.lng);
      dogu = math.max(dogu, n.lng);
    }
    if (kuzey - guney < darEsik && dogu - bati < darEsik) {
      return HaritaKadraji._(
        merkez: HaritaNoktasi((guney + kuzey) / 2, (bati + dogu) / 2),
        zoom: yakin,
      );
    }
    return HaritaKadraji._(
      guneyBati: HaritaNoktasi(guney, bati),
      kuzeyDogu: HaritaNoktasi(kuzey, dogu),
    );
  }

  final HaritaNoktasi? guneyBati;
  final HaritaNoktasi? kuzeyDogu;
  final HaritaNoktasi? merkez;
  final double? zoom;

  bool get kutuMu => guneyBati != null;

  /// Kutunun ya da noktanın ortası — açılışta motor kutuya sığdırmadan önce buraya bakar.
  HaritaNoktasi get orta => merkez ??
      HaritaNoktasi(
        (guneyBati!.lat + kuzeyDogu!.lat) / 2,
        (guneyBati!.lng + kuzeyDogu!.lng) / 2,
      );
}

/// Haritada o an çizilen her şey. Değer nesnesidir: aynı içerik ikinci kez motora gönderilmez.
class HaritaIcerigi {
  const HaritaIcerigi({
    this.duraklar = const [],
    this.cihaz,
    this.kuryeler = const [],
    this.seciliDurakId,
  });

  /// Rota sırasında.
  final List<DurakIsareti> duraklar;

  /// Cihazın kendi konumu — numarası yok, rota çizgisinin başlangıcıdır.
  final HaritaNoktasi? cihaz;
  final List<KuryeIsareti> kuryeler;

  /// Özeti açık olan durak — pin büyür ve diğerlerinin üstüne çıkar.
  final String? seciliDurakId;

  HaritaIcerigi kopyala({String? Function()? seciliDurakId}) => HaritaIcerigi(
        duraklar: duraklar,
        cihaz: cihaz,
        kuryeler: kuryeler,
        seciliDurakId: seciliDurakId == null ? this.seciliDurakId : seciliDurakId(),
      );

  /// Cihazın rotaya dahil sayılacağı en uzak mesafe (en yakın durağa).
  static const double rotaYaricapiKm = 30;

  /// Cihaz rotanın BAŞLANGICI mı? Yalnız duraklara yakınsa (≤ [rotaYaricapiKm]). Evdeki patron
  /// ya da başka şehirdeki bir telefon rotanın başı değildir: onu çizgiye ve kadraja katmak
  /// haritayı ülke ölçeğine uzaklaştırır, rota bir nokta kadar kalırdı (emülatörde görüldü:
  /// Kaliforniya'daki cihaz Bursa rotasına çizgi çekiyordu). Cihaz noktası yine ÇİZİLİR.
  HaritaNoktasi? get rotaBaslangici {
    final c = cihaz;
    if (c == null || duraklar.isEmpty) return c;
    for (final d in duraklar) {
      if (mesafeKm(c, d.nokta) <= rotaYaricapiKm) return c;
    }
    return null;
  }

  /// İki nokta arasındaki büyük daire mesafesi (haversine), km.
  static double mesafeKm(HaritaNoktasi a, HaritaNoktasi b) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Açılış kadrajı: duraklar + (rotanın başıysa) cihaz. Kuryeler BİLEREK dahil değil — patron
  /// haritaya rotayı görmeye gelir; şehrin öbür ucundaki bir kurye kadrajı rotayı okunmaz kılardı.
  /// Durak yoksa cihaz tek başına kadrajdır.
  HaritaKadraji? get kadraj {
    final noktalar = [
      for (final d in duraklar) d.nokta,
      if (duraklar.isEmpty) ?cihaz else ?rotaBaslangici,
    ];
    return noktalar.isEmpty ? null : HaritaKadraji.noktalardan(noktalar);
  }

  // ── Çizim verisi (motordan bağımsız) ─────────────────────────────────────────────────────

  /// Durağın çizim önceliği — büyük olan üstte çizilir: seçili durak en üstte, sonra 1 numara,
  /// 2 … (küçük numara, yani sıradaki durak, üst üste binen pinlerde görünen olmalı).
  double oncelik(DurakIsareti d) =>
      d.id == seciliDurakId ? 1000000 : (duraklar.length - d.no).toDouble();

  bool seciliMi(DurakIsareti d) => d.id == seciliDurakId;

  /// Rota çizgisinin noktaları — cihazdan (yakınsa, bkz. [rotaBaslangici]) başlayıp durakları
  /// SIRAYLA bağlar. Kuş uçuşudur, yol değildir; bu yüzden kesikli çizilir. İki noktadan azsa
  /// çizgi YOKTUR (boş liste).
  List<HaritaNoktasi> get rotaNoktalari {
    final noktalar = [?rotaBaslangici, for (final d in duraklar) d.nokta];
    return noktalar.length < 2 ? const [] : noktalar;
  }
}
