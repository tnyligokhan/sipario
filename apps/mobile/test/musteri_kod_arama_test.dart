// MÜŞTERİ KODUNA GÖRE ARAMA + SİPARİŞ EKRANININ SINIRLI LİSTESİ (kullanıcı şikâyeti 2026-09-26).
//
// YAŞANAN: "Müşteri koduna göre arama çalışmıyor (Sipariş Ekleme ve Müşteriler kısmı)". Sorguda
// 3+ rakam varsa doğrudan telefon aranıyordu, azsa ad — `code` hiç sorulmuyordu. Aynı gün
// "sipariş aramada bütün veriyi getirdiği için program çok hantallaşıyor" şikâyeti geldi:
// sipariş ekranı 9.047 müşterinin hepsini belleğe alıp çiziyordu. Bu dosya ikisini kilitler.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/musteri_aramasi.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';

import 'support/musteri_arama_ortami.dart';

void main() {
  late MusteriAramaOrtami o;

  setUp(() => o = MusteriAramaOrtami());
  tearDown(() => o.kapat());

  group('MusteriAramasi — yazımın çözümü', () {
    test('yalnız rakam koddur; başta # da olabilir', () {
      expect(MusteriAramasi('105').kod, 105);
      expect(MusteriAramasi('#105').kod, 105);
      expect(MusteriAramasi(' 7 ').kod, 7);
    });

    test('harf ya da ayraç içeren yazım kod değildir', () {
      expect(MusteriAramasi('Ali 105').kod, isNull);
      expect(MusteriAramasi('0532 111 22 33').kod, isNull);
    });

    test('telefon kadar uzun rakam dizisi kod sayılmaz', () {
      expect(MusteriAramasi('05321112233').kod, isNull);
      expect(MusteriAramasi('05321112233').telefonGovdesi, '5321112233');
    });

    test('yalnız sıfırlardan oluşan yazım telefonda herkesi eşlemez', () {
      expect(MusteriAramasi('000').telefonGovdesi, isNull);
    });
  });

  group('Kod araması — iki ekranda da bulur', () {
    setUp(() async {
      await o.ekle('AHMET YILMAZ', kod: 7, telefon: '+905321112233');
      await o.ekle('MEHMET KAYA', kod: 105, telefon: '+905551051010');
      await o.ekle('AYŞE DEMİR', kod: 1105, telefon: '+905449998877');
      await o.ekle('KODSUZ KİŞİ');
    });

    test('iki haneden kısa kod bulunur (eskiden ad aramasına düşüp boş dönüyordu)', () async {
      expect(await o.satirAra('7'), ['AHMET YILMAZ']);
      expect(await o.ara('7'), ['AHMET YILMAZ']);
    });

    test('kod tam eşleşir, içinde geçen başka kod getirilmez', () async {
      final sonuc = await o.satirAra('105');
      expect(sonuc, contains('MEHMET KAYA'));
      expect(sonuc, isNot(contains('AYŞE DEMİR')),
          reason: '1105 numaralı müşteri "105" aramasında çıkmamalı');
    });

    test('3+ haneli kodda telefonu eşleşen de gelir, ama kodu tutan EN ÜSTTE', () async {
      // MEHMET'in hem kodu 105 hem numarasında 105 geçiyor; AHMET'in numarası ...1112233.
      await o.ekle('TELEFONDA 105 OLAN', telefon: '+905301059999');
      final sonuc = await o.satirAra('105');
      expect(sonuc.first, 'MEHMET KAYA');
      expect(sonuc, contains('TELEFONDA 105 OLAN'));
    });

    test('# ile yazılan kod da bulunur', () async {
      expect(await o.satirAra('#1105'), ['AYŞE DEMİR']);
    });

    test('ad ve telefon araması bozulmadı', () async {
      expect(await o.satirAra('mehmet'), ['MEHMET KAYA']);
      expect(await o.satirAra('0532 111'), ['AHMET YILMAZ']);
    });
  });

  group('Sipariş ekranının sınırlı listesi', () {
    test('limit MÜŞTERİ sayısına uygulanır, telefon satırına değil', () async {
      // Çok numaralı müşteri JOIN'de birden çok satır üretir; düz LIMIT eksik müşteri verirdi.
      for (var i = 0; i < 5; i++) {
        await o.ekle('MÜŞTERİ $i', telefon: '+90532000000$i');
      }
      // Ada göre sırada EN BAŞA düşsün diye "A" ile başlar: sınırın içinde kalmalı.
      await o.ekle('AAA ÇOK NUMARALI', telefon: '+905310000001', ekTelefonlar: [
        '+905310000002',
        '+905310000003',
        '+905310000004',
      ]);
      final sonuc = await o.satirAra('', limit: 4, sira: MusteriSirasi.ad);
      expect(sonuc.length, 4);
      expect(sonuc.toSet().length, 4, reason: 'aynı müşteri iki kez sayılmamalı');
      expect(sonuc.first, 'AAA ÇOK NUMARALI');
    });

    test('sınırsız çağrı herkesi döndürür', () async {
      for (var i = 0; i < 6; i++) {
        await o.ekle('KİŞİ $i');
      }
      expect((await o.satirAra('')).length, 6);
      expect((await o.satirAra('', limit: 3)).length, 3);
    });
  });
}
