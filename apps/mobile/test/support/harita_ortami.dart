// HARİTA EKRANI TESTLERİNİN ORTAK FİKSTÜRÜ.
//
// NEDEN AYRI DOSYA: `ui_siparis_harita_test.dart` 925 satıra çıkmıştı (500 satır kuralı) ve
// dörde bölündü; ekran tarafı da ikiye ayrılınca (pin/özet · karo ve kamera kontrolleri) ikisi
// de bu fikstüre ihtiyaç duydu. Kopyalansaydı iki ayrı "sipariş ekle" doğar ve bir gün ayrışırdı.
//
// ⚠️ `sort_index` AÇIKÇA VERİLİR: pin numaraları ondan geliyor ve aynı milisaniyede üretilen
// uuid7 kimliklerinin sırası yazı-turadır (bu depoda ölçüldü) — sıra yazılmazsa test sallanır.

import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';

/// Bir müşteri + siparişi. [lat]/[lng] null ise adres konumsuzdur.
Future<String> siparisEkle(
  AppDatabase db, {
  required String ad,
  double? lat,
  double? lng,
  bool teslim = false,
  int? sira,
  String? telefon,
  String? not,
  int tutarKurus = 4500,
}) async {
  final cid = await CustomerRepository(db).create(
    name: ad,
    phones: [
      if (telefon != null) PhoneInput(phoneE164: telefon, isPrimary: true),
    ],
    addresses: [
      AddressInput(
        addressText: '$ad sokağı No: 1',
        lat: lat,
        lng: lng,
        isPrimary: true,
      ),
    ],
  );
  final repo = OrderRepository(db);
  final oid = await repo.create(customerId: cid, note: not, lines: [
    LineInput(productName: 'Damacana', unitPriceKurus: tutarKurus, qty: 1),
  ]);
  // Pin numaraları `sort_index`ten gelir — testin beklediği sıra açıkça yazılır, aksi hâlde
  // aynı milisaniyede üretilen kimliklerin sırası yazı-tura olurdu.
  if (sira != null) await repo.setSortIndex(oid, sira);
  if (teslim) await repo.deliver(oid, paymentType: 'nakit');
  return oid;
}
