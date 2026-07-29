// HARİTA EKRANININ VERİ KATMANI — açık siparişlerin durakları.
//
// NEDEN AYRI DOSYA: iki kural birden. (1) SQL EKRANA GÖMÜLMEZ — harita ekranı ve durak özeti
// sorgu bilmez, yalnız bu dosyanın döndürdüğü tipleri okur. (2) 500 SATIR sınırı: bu bölüm
// `order_queries.dart`ta doğdu ve o dosyayı 742 satıra taşırdı; sipariş listesinin sorgularıyla
// hiçbir şey paylaşmadığı için ayrılması bir bölünme değil, doğru yerine konması.
//
// Sipariş listesinin ORTAK yardımcıları (`OrderListItem`, `siparisleriSirala`, `satirKodu`,
// `AdresBilgi`) hâlâ `order_queries.dart`tan gelir: harita kendi kopyasını tutsaydı liste ile
// aynı siparişi farklı sırada/farklı kodla gösterebilirdi.

import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import 'order_queries.dart';

/// Haritadaki tek durak. Numarası YOK: sıra listenin kendisidir ([HaritaVerisi.duraklar]),
/// pin numarasını ekran indeksten yazar — iki yerde ayrı sayı tutulursa ayrışırlar.
///
/// Pine dokununca açılan ÖZET sayfasının ihtiyacı olan her şeyi taşır: kurye haritada bir pine
/// dokunduğunda "burada ne var" sorusunun cevabını tek okumada almalı, ikinci bir sorgu turu
/// beklememeli.
class HaritaDuragi {
  const HaritaDuragi({
    required this.orderId,
    required this.baslik,
    required this.adres,
    required this.tutarKurus,
    required this.occurredAt,
    this.kod,
    this.not,
    this.telefon,
  });

  final String orderId;

  /// Müşteri adı (tezgâh satışında sabit metin) — özet sayfasının başlığı.
  final String baslik;

  /// Birincil adres. [AdresBilgi.konumVar] BU TİPTE GARANTİDİR: sorgu koordinatsız durağı hiç
  /// üretmez (koordinatsızlar [HaritaVerisi.konumsuz] sayacına gider). "Yol Tarifi" eylemi
  /// `konumuHaritadaAc` ile aynı nesneyi paylaşsın diye ham lat/lng yerine bu tutulur.
  final AdresBilgi adres;

  final int tutarKurus;

  /// ISO8601 — özet sayfası bekleme süresini ve saati bundan yazar (liste satırının aynısı).
  final String occurredAt;

  /// Satırda görünen kod rozeti ("#248" ya da "102") — bayi ayarı (`order_code_display`)
  /// hangisini seçiyorsa o. Kod yoksa null ve rozet HİÇ çizilmez (uydurma numara yasağı).
  final String? kod;

  final String? not;

  /// Müşterinin birincil telefonu. Yoksa "Ara" düğmesi çizilmez.
  final String? telefon;

  double get lat => adres.lat!;
  double get lng => adres.lng!;
}

/// Haritanın tek okuması: çizilecek duraklar + haritaya GİREMEYEN açık sipariş sayısı.
class HaritaVerisi {
  const HaritaVerisi({required this.duraklar, required this.konumsuz});

  /// Rota sırasında (oto sıralama sonrası `sort_index` bu sıradır).
  final List<HaritaDuragi> duraklar;

  /// Koordinatı olmadığı için haritada GÖRÜNMEYEN açık sipariş sayısı. Kullanıcıya söylenir:
  /// "haritada 5 pin var" deyip 8 açık siparişten üçünü sessizce yutmak, kuryenin eksik rota
  /// koşmasına yol açardı.
  final int konumsuz;
}

/// Harita ekranının verisi — YALNIZ açık siparişler, müşterinin BİRİNCİL adresinin koordinatıyla.
///
/// Birincil adres kuralı `watchBirincilAdresler` ile AYNIDIR (isPrimary önce, sonra id): harita
/// başka bir adresi seçseydi listedeki adres metni ile haritadaki pin farklı yerleri gösterirdi.
/// Birincil adreste koordinat yoksa sipariş KONUMSUZ sayılır — ikincil adrese düşmek, kullanıcının
/// listede gördüğü adresin dışında bir kapıya pin koymak olurdu.
///
/// Sıra: `siparisleriSirala(..., elle)` — yani kalıcı `sort_index`. Oto sıralamadan sonra bu sıra
/// rotanın kendisidir; hiç sıralanmamış siparişler (sortIndex null) sona düşer.
Stream<HaritaVerisi> watchHaritaDuraklari(AppDatabase db) {
  final q = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
    leftOuterJoin(
      db.customerAddresses,
      db.customerAddresses.customerId.equalsExp(db.orders.customerId) &
          db.customerAddresses.deletedAt.isNull(),
    ),
    leftOuterJoin(
      db.customerPhones,
      db.customerPhones.customerId.equalsExp(db.orders.customerId) &
          db.customerPhones.deletedAt.isNull(),
    ),
    // Kod tercihi TEK SATIRLIK bir ayar (`tenant_settings` id=1). Ayrı akış olarak taşınıp
    // ekranda birleştirilseydi harita iki akışın buluşmasını bekler, kod rozeti bir tik geç
    // gelirdi. Tek satır olduğu için birleşim satır sayısını çoğaltmaz.
    leftOuterJoin(db.tenantSettings, db.tenantSettings.id.equals(1)),
  ]);
  q.where(db.orders.deletedAt.isNull() & db.orders.status.equals('open'));
  // İlk iki terim siparişlerin taban sırası (`watchOrders` ile aynı); kalanlar AYNI siparişin
  // adres/telefon satırları arasında birincili öne alır — böylece her sipariş için ilk gelen
  // satır birincil adres + birincil telefondur (`watchBirincilAdresler` kuralının aynısı).
  q.orderBy([
    OrderingTerm.desc(db.orders.occurredAt),
    OrderingTerm.desc(db.orders.id),
    OrderingTerm.desc(db.customerAddresses.isPrimary),
    OrderingTerm.asc(db.customerAddresses.id),
    OrderingTerm.desc(db.customerPhones.isPrimary),
    OrderingTerm.asc(db.customerPhones.id),
  ]);

  return q.watch().map((rows) {
    final siparisler = <String, OrderListItem>{};
    final adresler = <String, CustomerAddressesData>{};
    final telefonlar = <String, String>{};
    var kodTercihi = 'musteri';
    for (final r in rows) {
      final o = r.readTable(db.orders);
      final musteri = r.readTableOrNull(db.customers);
      siparisler.putIfAbsent(
        o.id,
        () => OrderListItem(
          order: o,
          customerName: musteri?.name,
          customerCode: musteri?.code,
        ),
      );
      final a = r.readTableOrNull(db.customerAddresses);
      if (a != null) adresler.putIfAbsent(o.id, () => a);
      final tel = r.readTableOrNull(db.customerPhones);
      if (tel != null) telefonlar.putIfAbsent(o.id, () => tel.phoneE164);
      kodTercihi = r.readTableOrNull(db.tenantSettings)?.orderCodeDisplay ?? kodTercihi;
    }

    final duraklar = <HaritaDuragi>[];
    var konumsuz = 0;
    for (final e in siparisleriSirala(siparisler.values.toList(), OrderSort.elle)) {
      final a = adresler[e.order.id];
      if (a?.lat == null || a?.lng == null) {
        konumsuz++;
        continue;
      }
      duraklar.add(HaritaDuragi(
        orderId: e.order.id,
        baslik: e.customerName ?? 'Tezgâh satışı',
        adres: AdresBilgi(metin: a!.addressText, bolge: a.region, lat: a.lat, lng: a.lng),
        tutarKurus: e.order.totalKurus,
        occurredAt: e.order.occurredAt,
        // Rozet kuralı liste satırıyla TEK fonksiyondan okunur — harita başka bir numara
        // gösterseydi bayi aynı siparişi iki farklı kodla anardı.
        kod: satirKodu(
          tercih: kodTercihi,
          musteriCode: e.customerCode,
          siparisCode: e.order.code,
        ),
        not: e.order.note,
        telefon: telefonlar[e.order.id],
      ));
    }
    return HaritaVerisi(duraklar: duraklar, konumsuz: konumsuz);
  });
}
