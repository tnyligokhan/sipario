// MÜŞTERİNİN ÜRÜN TERCİHLERİ — "her seferinde sormak istemeyebilir" (kullanıcı isteği 2026-08-18).
//
// NEDEN AYRI DOSYA: `customer_repository.dart` bu yüzeyle 556 satıra çıkmıştı (depo sınırı 500).
// Ayrım KONUYA göre: ana dosya müşterinin KİMLİĞİNİ yönetir (ad · telefon · adres · kara liste),
// burası onun SİPARİŞ ALIŞKANLIĞINI — favori listesinin kardeşi.
//
// NEDEN `part` (ayrı kütüphane değil): buradaki yazım `_payload`ı kullanmak ZORUNDA. O fonksiyon
// `customer` upsert yükünün TEK üretim noktasıdır ve öyle kalmalı — public yapmak, başka bir
// yerin kendi müşteri yükünü kurmasına ve bir alanı unutup sunucudaki değeri silmesine kapı
// açardı (bu depoda favori listesinde bir kez ödenmiş hata sınıfı). `part` aynı kütüphanede
// kalmayı ve `_` gizliliğini korur; çağrı yerleri DEĞİŞMEZ.

part of 'customer_repository.dart';

extension MusteriUrunTercihi on CustomerRepository {
  /// Müşterinin bir ÜRÜNE dair sabit tercihini yazar ("Ayşe Hanım: dürüm soğansız").
  ///
  /// [secim] BOŞSA tercih SİLİNİR — ayrı bir "sil" fonksiyonu yok, çünkü "hiçbir şey değiştirme"
  /// zaten tercihin yokluğudur. İki ayrı yol olsaydı biri er geç ötekinden farklı davranırdı.
  ///
  /// Favori listesiyle AYNI desen: müşterinin bir ALANI, ayrı senkron varlığı değil; çakışma
  /// LWW ile çözülür. Ad/not/kara liste/favori OKUNUP GERİ GÖNDERİLİR — payload tam satırdır.
  Future<void> urunTercihiKaydet(
    String customerId,
    String productId,
    SecenekSecimi secim,
  ) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      final mevcut = await (db.select(db.customers)..where((t) => t.id.equals(customerId)))
          .getSingleOrNull();
      if (mevcut == null) return;

      final tercihler = Map<String, SecenekSecimi>.from(
          musteriTercihleriniCoz(mevcut.productOptionsJson));
      if (secim.bos) {
        tercihler.remove(productId);
      } else {
        tercihler[productId] = secim;
      }
      final metin = musteriTercihleriniYaz(tercihler);

      await (db.update(db.customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          productOptionsJson: Value(metin),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: customerId,
          occurredAt: at,
          deviceId: device,
          payload: CustomerRepository._payload(customerId, mevcut.name, mevcut.note, mevcut.blacklistedAt,
              favoriIdleriCoz(mevcut.favoriteProductIds), metin));
    });
  }

  /// Müşterinin tüm ürün tercihleri (tek atış). Bozuk/eski metinde boş harita.
  Future<Map<String, SecenekSecimi>> urunTercihleriniOku(String customerId) async {
    final m =
        await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
    return musteriTercihleriniCoz(m?.productOptionsJson);
  }

  /// TEK bir ürün için tercih — sipariş eklerken sorulan sorunun tam karşılığı.
  ///
  /// [secenekler] verilirse tercih ürünün BUGÜNKÜ listesiyle uyumlulaştırılır: aylar önce
  /// kaydedilmiş bir tercih, o günden beri menüden kalkmış bir malzemeyi taşıyor olabilir
  /// (gerekçe `SecenekSecimi.urunleUyumlu`).
  Future<SecenekSecimi> urunTercihi(
    String customerId,
    String productId, {
    List<UrunSecenegi> secenekler = const [],
  }) async {
    final tercihler = await urunTercihleriniOku(customerId);
    final secim = tercihler[productId] ?? const SecenekSecimi();
    return secenekler.isEmpty ? secim : secim.urunleUyumlu(secenekler);
  }

}
