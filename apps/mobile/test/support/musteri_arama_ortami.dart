// MÜŞTERİ ARAMASI TESTLERİNİN FİKSTÜRÜ — bellek içi veritabanı + kodlu/telefonlu müşteri ekleme
// + iki arama yüzeyi (liste satırları ve düz müşteri akışı).
//
// Kod SUNUCUDA atanır; testte senkron yok, bu yüzden kayıttan sonra doğrudan yazılır.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';

class MusteriAramaOrtami {
  MusteriAramaOrtami() : db = AppDatabase(NativeDatabase.memory());

  final AppDatabase db;

  late final CustomerRepository _repo = CustomerRepository(db);

  /// Müşteri ekler; [kod] verilirse sunucunun atayacağı kodu taklit eder.
  /// [ekTelefonlar] birincil olmayan ek numaralardır (JOIN'de satır çoğaltan müşteri için).
  Future<String> ekle(
    String ad, {
    int? kod,
    String? telefon,
    List<String> ekTelefonlar = const [],
    String? adres,
  }) async {
    final id = await _repo.create(
      name: ad,
      phones: [
        if (telefon != null) PhoneInput(phoneE164: telefon, isPrimary: true),
        for (final t in ekTelefonlar) PhoneInput(phoneE164: t),
      ],
      addresses: [if (adres != null) AddressInput(addressText: adres, isPrimary: true)],
    );
    if (kod != null) {
      await (db.update(db.customers)..where((t) => t.id.equals(id)))
          .write(CustomersCompanion(code: Value(kod)));
    }
    return id;
  }

  /// Müşteriler listesi / sipariş ekranı yüzeyi — dönen adlar sıralı.
  Future<List<String>> satirAra(
    String q, {
    int? limit,
    MusteriSirasi sira = MusteriSirasi.eklenme,
  }) async =>
      (await watchCustomerRows(db, q, limit: limit, sira: sira).first)
          .map((r) => r.customer.name)
          .toList();

  /// Düz müşteri akışı yüzeyi (arama sözleşmesinin ikinci kapısı).
  Future<List<String>> ara(String q) async =>
      (await watchCustomers(db, q).first).map((c) => c.name).toList();

  /// Kaydın kendisi (satır bileşenini doğrudan çizmek için).
  Future<Customer> getir(String id) =>
      (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();

  Future<void> kapat() => db.close();
}
