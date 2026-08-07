// Müşteri listesinin SIRA SÖZLEŞMESİ (kullanıcı isteği 2026-08-06): "en son kaydedilen en üstte".
//
// Bu dosya eski ALFABETİK sıranın geri gelmesini de engeller: SQLite'ın BINARY collation'ında
// Türkçe harfler (Ç Ğ İ Ö Ş Ü) çok baytlı UTF-8 olduğu için tüm ASCII harflerden sonra dizilirdi —
// kullanıcıya "rasgele" görünen buydu. Sıra kuralı watchCustomers ve watchCustomerRows'ta AYNIDIR;
// ikisi de burada ayrı ayrı kilitlenir.
//
// Sorgular saf async testle sınanır (widget-test sahte zamanı drift akışlarında güvenilmez).

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';

void main() {
  late AppDatabase db;
  late CustomerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CustomerRepository(db);
  });

  tearDown(() => db.close());

  /// Sunucudan kod gelmiş müşteriyi taklit eder: `repo.create` kod ATAMAZ (kodu sunucu verir),
  /// senkron cevabı satırı sonradan günceller.
  Future<void> kodAta(String id, int code) =>
      (db.update(db.customers)..where((t) => t.id.equals(id)))
          .write(CustomersCompanion(code: Value(code)));

  Future<List<String>> adlar([String q = '']) async =>
      (await watchCustomers(db, q).first).map((c) => c.name).toList();

  Future<List<String>> satirAdlari([String q = '']) async =>
      (await watchCustomerRows(db, q).first).map((r) => r.customer.name).toList();

  group('Sıra: en son kaydedilen en üstte', () {
    test('kodsuz müşteriler kaydetme sırasının TERSİNE dizilir', () async {
      await repo.create(name: 'Birinci');
      await repo.create(name: 'İkinci');
      await repo.create(name: 'Üçüncü');

      // rowid tie-break'i sınar: UUIDv7 aynı milisaniyede sırasız olabilir, rowid olamaz —
      // bu iddia bu yüzden yazı-tura değildir.
      expect(await adlar(), ['Üçüncü', 'İkinci', 'Birinci']);
      expect(await satirAdlari(), ['Üçüncü', 'İkinci', 'Birinci']);
    });

    test('sunucu kodu varsa BÜYÜK kod üstte — kod, kayıt sırasını EZER', () async {
      // Bilerek ters kurgu: 'Once' daha önce eklendi ama kodu büyük (sunucu ona sonra kod verdi).
      final once = await repo.create(name: 'Once');
      final sonra = await repo.create(name: 'Sonra');
      await kodAta(once, 102);
      await kodAta(sonra, 100);

      expect(await adlar(), ['Once', 'Sonra']);
      expect(await satirAdlari(), ['Once', 'Sonra']);
    });

    test('kodsuz müşteri kodluların ÜSTÜNDE — henüz senkronlanmamış olan en yenidir', () async {
      // Ters kurgu: kodsuz olan ÖNCE eklendi, yani rowid onu üste taşımaz; üste taşıyan tek şey
      // `code IS NULL DESC` terimidir.
      await repo.create(name: 'Kodsuz Yeni');
      final kodlu = await repo.create(name: 'Kodlu Eski');
      await kodAta(kodlu, 999);

      expect(await adlar(), ['Kodsuz Yeni', 'Kodlu Eski']);
      expect(await satirAdlari(), ['Kodsuz Yeni', 'Kodlu Eski']);
    });

    test('düzenleme sırayı DEĞİŞTİRMEZ (updated_occurred_at sıra ölçütü değildir)', () async {
      final eski = await repo.create(name: 'Eski Musteri');
      await repo.create(name: 'Yeni Musteri');

      await repo.rename(eski, name: 'Eski Musteri'); // adı düzeltmek onu başa fırlatmamalı

      expect(await adlar(), ['Yeni Musteri', 'Eski Musteri']);
    });
  });

  group('Türkçe harfler: alfabetik sıra ARTIK YOK', () {
    test('sonradan eklenen "Şükrü", "Ahmet"in ÜSTÜNDE', () async {
      await repo.create(name: 'Ahmet');
      await repo.create(name: 'Şükrü');

      // Alfabetik olsaydı (BINARY collation) 'Ahmet' üstte kalırdı — 'Ş' çok baytlı UTF-8
      // olduğu için ASCII 'A'dan sonra sıralanır. Sözleşme artık kayıt sırasıdır.
      expect(await adlar(), ['Şükrü', 'Ahmet']);
      expect(await satirAdlari(), ['Şükrü', 'Ahmet']);
    });

    test('sonradan eklenen "Ahmet", "Şükrü"nün ÜSTÜNDE — sıra ada bakmıyor', () async {
      await repo.create(name: 'Şükrü');
      await repo.create(name: 'Ahmet');

      expect(await adlar(), ['Ahmet', 'Şükrü']);
    });
  });

  group('Arama sonuçları da aynı kuralla dizilir', () {
    test('ad araması', () async {
      await repo.create(name: 'Ali Veli');
      await repo.create(name: 'Ali Can');

      expect(await adlar('Ali'), ['Ali Can', 'Ali Veli']);
      expect(await satirAdlari('Ali'), ['Ali Can', 'Ali Veli']);
    });

    test('telefon araması (JOIN dalı)', () async {
      await repo.create(
          name: 'Telefonlu Eski',
          phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);
      await repo.create(
          name: 'Telefonlu Yeni',
          phones: [PhoneInput(phoneE164: '+905321112244', isPrimary: true)]);

      expect(await adlar('532111'), ['Telefonlu Yeni', 'Telefonlu Eski']);
      expect(await satirAdlari('532111'), ['Telefonlu Yeni', 'Telefonlu Eski']);
    });
  });

  test('birincil telefon/adres seçimi sıra değişikliğinden ETKİLENMEDİ', () async {
    // watchCustomerRows'un JOIN çarpımını tekilleştirmesi "ilk gelen satır kazanır" der; hangi
    // satırın ilk geleceğini `isPrimary DESC` terimleri belirler. Yeni sıra terimleri onların
    // ÖNÜNE eklendiği için bu seçim bozulmamalı — bozulsaydı müşterinin yanlış telefonu çizilirdi.
    await repo.create(
      name: 'Cok Kayitli',
      phones: [
        PhoneInput(phoneE164: '+905321110001'), // ikincil ÖNCE eklendi
        PhoneInput(phoneE164: '+905321110002', isPrimary: true),
      ],
      addresses: [
        AddressInput(addressText: 'Ikincil Sokak 1'),
        AddressInput(addressText: 'Birincil Cadde 2', isPrimary: true),
      ],
    );
    await repo.create(name: 'Sonraki'); // liste başında durur; satır eşleşmesi ada göre aranır

    final satirlar = await watchCustomerRows(db, '').first;
    final cok = satirlar.firstWhere((r) => r.customer.name == 'Cok Kayitli');

    expect(cok.phone, '+905321110002', reason: 'birincil telefon gösterilmeli');
    expect(cok.adres?.addressText, 'Birincil Cadde 2', reason: 'birincil adres gösterilmeli');
    expect(satirlar.first.customer.name, 'Sonraki', reason: 'sıra kuralı yine geçerli');
  });
}
