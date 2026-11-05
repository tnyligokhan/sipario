// 2026-11-05 SAHA LİSTESİ — dokuz maddenin kuralları (mobil 1.15.0).
//
// Veri ve saf kurallar burada; dokunuş gerektiren yüzeyler `ui_saha_listesi_test.dart`ta.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/gider_kategorileri.dart';
import 'package:sipario/data/musteri_fiyatlari.dart';
import 'package:sipario/data/satir_iskontosu.dart';
import 'package:sipario/data/telefon_numarasi.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/cagri/cagri_kuyrugu.dart';
import 'package:sipario/screens/customers/borc_hatirlatma.dart';
import 'package:sipario/screens/isletme/muaf_ekrani.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
import 'package:sipario/screens/orders/order_parts.dart';
import 'package:sipario/theme/components/bicim.dart';

/// Bellek veritabanı + son outbox yükü okuması.
class _Ortam {
  _Ortam() : db = AppDatabase(NativeDatabase.memory());

  final AppDatabase db;

  Future<Map<String, dynamic>> sonYuk(String entityType) async {
    final kayitlar = await db.select(db.outbox).get();
    final uygun = kayitlar.where((o) => o.entityType == entityType).toList();
    return jsonDecode(uygun.last.payload) as Map<String, dynamic>;
  }

  Future<void> kapat() => db.close();
}

void main() {
  group('Madde 1 — yabancı numara', () {
    test('Türkiye numarasının bütün yazımları aynı E.164\'e iner', () {
      for (final ham in [
        '05321112233',
        '5321112233',
        '905321112233',
        '+90 532 111 22 33',
        '0090 532 111 22 33',
      ]) {
        expect(TelefonNumarasi.coz(ham)?.e164, '+905321112233', reason: ham);
      }
    });

    test('ülke koduyla yazılan yabancı numara kabul edilir', () {
      expect(TelefonNumarasi.coz('+49 151 12345678')?.e164, '+4915112345678');
      expect(TelefonNumarasi.coz('0049 151 12345678')?.e164, '+4915112345678');
      expect(TelefonNumarasi.coz('+1 (202) 555-0123')?.e164, '+12025550123');
      expect(TelefonNumarasi.coz('+4915112345678')!.yabanci, isTrue);
    });

    test('ülke kodu yazılmamış uzun numara tahmin edilmez, reddedilir', () {
      expect(TelefonNumarasi.coz('4915112345678'), isNull);
      expect(TelefonNumarasi.coz('12345'), isNull);
      expect(TelefonNumarasi.coz(''), isNull);
      expect(TelefonNumarasi.coz('+49 151'), isNull, reason: 'eşleşme anahtarı dolmaz');
      expect(TelefonNumarasi.coz('+1234567890123456'), isNull, reason: 'E.164 tavanı 15 hane');
    });

    test('yabancı numara ekranda son 10 haneye kırpılmaz', () {
      // Kırpılsaydı form bu metni geri okuyup numarayı TR numarası diye kaydederdi.
      expect(sipTelefon('+4915112345678'), '+4915112345678');
      expect(TelefonNumarasi.coz(sipTelefon('+4915112345678'))?.e164, '+4915112345678');
      expect(sipTelefon('+905324152290'), '0532 415 22 90');
    });

    test('çağrı kuyruğu yabancı numarayı + ile saklar, kısa numarayı olduğu gibi bırakır', () {
      expect(CagriKuyrugu.e164('4915112345678'), '+4915112345678');
      expect(CagriKuyrugu.e164('004915112345678'), '+4915112345678');
      expect(CagriKuyrugu.e164('905321112233'), '+905321112233');
      expect(CagriKuyrugu.e164('05321112233'), '+905321112233');
      expect(CagriKuyrugu.e164('444'), '444');
    });

    test('yabancı numara aranabilir ve muaf listesine girer', () {
      expect(telefonE164('+4915112345678'), '+4915112345678');
      expect(muafNumaraHatasi('+49 151 12345678', mevcutSon10: const []), isNull);
    });
  });

  group('Madde 3 — satır iskontosu', () {
    test('yüzde adetle birlikte büyür, tutar satırı aşamaz', () {
      expect(const SatirIskontosu.yuzde(10).kurus(30000), 3000);
      expect(const SatirIskontosu.yuzde(10).kurus(60000), 6000);
      expect(const SatirIskontosu.tutar(5000).kurus(3000), 3000);
      expect(SatirIskontosu.yok.kurus(3000), 0);
    });

    test('sepet toplamı iskontoyu düşer, adet azalınca satır eksiye inmez', () {
      final satir = LineDraft(
        productId: 'u',
        name: 'Damacana',
        unitPriceKurus: 10000,
        qty: 3,
        iskonto: const SatirIskontosu.tutar(25000),
      );
      expect(toplamKurus([satir]), 5000);
      satir.qty = 2;
      expect(satir.netKurus, 0);
    });

    test('iskonto satıra, toplama ve senkron yüküne yazılır', () async {
      final o = _Ortam();
      addTearDown(o.kapat);
      final repo = OrderRepository(o.db);

      final id = await repo.create(lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 10000, qty: 3, iskontoKurus: 2500),
      ]);

      final satir = await o.db.select(o.db.orderLines).getSingle();
      expect(satir.discountKurus, 2500);
      expect(satir.lineTotalKurus, 27500);
      final siparis = await (o.db.select(o.db.orders)..where((t) => t.id.equals(id))).getSingle();
      expect(siparis.totalKurus, 27500);

      final yuk = await o.sonYuk('order');
      expect((yuk['lines'] as List).single['discount_kurus'], 2500);
    });
  });

  group('Madde 4 — müşteriye özel fiyat', () {
    test('liste katalog fiyatının yerine geçer, bozuk metinde çökmez', () {
      final f = MusteriFiyatlari.coz('{"u1":8500,"u2":0}');
      expect(f.birimFiyat('u1', 10000), 8500);
      expect(f.birimFiyat('u2', 10000), 0, reason: 'sıfır fiyat geçerlidir');
      expect(f.birimFiyat('u3', 10000), 10000);
      expect(f.ozelMi('u1'), isTrue);
      expect(f.ozelMi(null), isFalse);
      expect(MusteriFiyatlari.coz('bozuk').bosMu, isTrue);
      expect(MusteriFiyatlari.coz('[1]').bosMu, isTrue);
      expect(MusteriFiyatlari.coz(null).yaz(), isNull);
    });

    test('fiyat kaydedilir ve başka bir müşteri yazımında SİLİNMEZ', () async {
      final o = _Ortam();
      addTearDown(o.kapat);
      final repo = CustomerRepository(o.db);
      final id = await repo.create(name: 'Ayşe');

      await repo.musteriFiyatiKaydet(id, 'u1', 8500);
      expect((await o.sonYuk('customer'))['product_prices'], {'u1': 8500});

      // Payload TAM SATIRDIR: fiyatı bilmeyen her yol değeri geri göndermek zorundadır.
      await repo.rename(id, name: 'Ayşe Yılmaz');
      expect((await o.sonYuk('customer'))['product_prices'], {'u1': 8500});
      await repo.karaListe(id, ekle: true);
      expect((await o.sonYuk('customer'))['product_prices'], {'u1': 8500});
      await repo.favorileriKaydet(id, ['u1']);
      expect((await o.sonYuk('customer'))['product_prices'], {'u1': 8500});

      await repo.musteriFiyatiKaydet(id, 'u1', null);
      expect((await repo.musteriFiyatlariniOku(id)).bosMu, isTrue);
      expect((await o.sonYuk('customer'))['product_prices'], isNull);
    });
  });

  group('Madde 5 — gider kategorileri', () {
    test('düzenlenmemiş bayi varsayılan listeyi görür', () {
      expect(GiderKategorileri.coz(null).adlar, contains('Yakıt'));
      expect(GiderKategorileri.coz('bozuk').adlar, contains('Yakıt'));
      expect(GiderKategorileri.coz('["Kömür"]').adlar, ['Kömür']);
    });

    test('tekrar Türkçe harf kuralıyla yakalanır, son kategori silinemez', () {
      final k = GiderKategorileri.coz('["Işık"]');
      expect(k.eklemeHatasi('ışık'), 'Bu kategori zaten var');
      expect(k.eklemeHatasi('  '), 'Kategori adı yazın');
      expect(k.eklemeHatasi('Kömür'), isNull);
      expect(k.silinebilir, isFalse);
      expect(k.ile('Kömür').haric('Işık').adlar, ['Kömür']);
    });

    test('liste kaydedilir ve başka bir ayar yazımında korunur', () async {
      final o = _Ortam();
      addTearDown(o.kapat);
      final repo = TenantSettingsRepository(o.db);

      await repo.giderKategorileriKaydet(GiderKategorileri.varsayilan.ile('Kömür'));
      expect((await o.sonYuk('tenant_settings'))['expense_categories'], contains('Kömür'));

      await repo.save(businessName: const Value('Bayi'));
      expect((await repo.giderKategorileri()).adlar, contains('Kömür'));
      expect((await o.sonYuk('tenant_settings'))['expense_categories'], contains('Kömür'));
    });
  });

  group('Madde 8 — borç hatırlatma mesajı', () {
    String mesaj({String? sablon, String? iban = 'TR330006100519786457841326', String ad = 'Ahmet'}) =>
        borcHatirlatmaMesaji(
          musteriAd: ad,
          borcKurus: 25000,
          iban: iban,
          isletmeAdi: 'Merkez Su',
          isletmeTelefonu: '+902421234567',
          sablon: sablon,
          tarih: DateTime(2026, 11, 5),
          hesap: const HatirlatmaHesapOzeti(
            odenmemisSiparis: 3,
            sonSiparisAt: '2026-11-01T09:00:00.000Z',
            sonOdemeAt: '2026-10-20T09:00:00.000Z',
            sonOdemeKurus: 50000,
          ),
        );

    test('varsayılan metin kapsamlıdır ve kurumsal dille kapanır', () {
      final m = mesaj();
      expect(m, startsWith('Sayın Ahmet,\n\n05.11.2026 tarihi itibarıyla'));
      expect(m, contains('Güncel bakiyeniz: 250,00 ₺\n'));
      expect(m, contains('Ödenmemiş sipariş: 3 adet\n'));
      expect(m, contains('Son sipariş tarihi: 01.11.2026\n'));
      expect(m, contains('Son ödemeniz: 20.10.2026, 500,00 ₺\n'));
      expect(m, contains('TR33 0006 1005 1978 6457 8413 26'));
      expect(m, contains('0242 123 45 67 numarasından'));
      expect(m, endsWith('Saygılarımızla,\nMerkez Su'));
      expect(m.length, lessThan(hatirlatmaSablonuAzamiUzunluk));
    });

    test('bilinmeyen hesap bilgisinin satırı düşer, paragraflar birbirine yapışmaz', () {
      final m = borcHatirlatmaMesaji(
        musteriAd: 'Ahmet',
        borcKurus: 25000,
        iban: 'TR330006100519786457841326',
        isletmeAdi: 'Merkez Su',
      );
      expect(m, isNot(contains('Son ödemeniz')));
      expect(m, isNot(contains('sorularınız')));
      expect(m, contains('Güncel bakiyeniz: 250,00 ₺\n\nÖdemenizi aşağıdaki'));
      expect(m, contains('dikkate almayınız.\n\nİş birliğiniz'));
      expect(m, isNot(contains('\n\n\n')));
    });

    test('IBAN yokken ödeme cümlesi, ad yokken "Sayın ," yazılmaz', () {
      expect(mesaj(iban: null), isNot(contains('aşağıdaki hesaba')));
      expect(mesaj(ad: ' '), startsWith('Merhaba,\n'));
    });

    test('eski varsayılanı değiştirmeden kaydetmiş bayi yeni metne geçer, kendi metni kalır', () {
      const eski = 'Sayın *musteriadi*, merhaba.\n'
          '*isletmeadi* olarak hesabınızda *siparistutar* tutarında ödenmemiş bakiye görünüyor.\n'
          '\n'
          '*ibanodemebilgileri*\n'
          '\n'
          'Teşekkür ederiz.';
      expect(mesaj(sablon: eski), mesaj());
      expect(mesaj(sablon: '*musteriadi* için *sonodeme*'), 'Ahmet için 20.10.2026, 500,00 ₺');
    });
  });
}
