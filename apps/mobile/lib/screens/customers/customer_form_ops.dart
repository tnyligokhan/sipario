// Müşteri formunun YAZMA işlemleri — ekran (customer_form_screen.dart) yalnız alan toplar,
// kalıcılık burada. Böylece form dosyası 500 satırın altında kalır ve yazma yolu tek yerden
// okunur.
//
// Yazma daima repo → outbox. Adres güncelleme artık repo'nun `updateAddress`'i üzerinden gider
// (backend ajanı ekledi). Telefon silme (`removePhone`) repo'da HENÜZ YOK — onun için aşağıda
// geçici bir köprü var; yerel yazma + outbox olayını AYNI transaction'da yapar (Faz 2 atomikliği)
// ve repo'daki `_insertPhone` yüküyle simetrik payload üretir. Repo metodu gelince silinecek.

import 'package:drift/drift.dart';

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
