// UUIDv7 MONOTONLUĞU — 2026-07-27 bulgusunun regresyon kilidi.
//
// `uuid` 4.5.3'ün `v7`si zaman damgasından sonraki 74 bitin TAMAMINI rastgele dolduruyor;
// aynı milisaniyede üretilen iki id'nin sırası yazı-turaydı (ölçüldü: 20.000 çiftte %50,5
// ters). Depo ise "UUIDv7 zaman-sıralıdır" varsayımına dayanıyordu: `order_lines` tek
// transaction'da döngüyle üretiliyor, çağrı kartındaki sipariş dökümü `ORDER BY id ASC` ile
// yazılıyor. Sonuç, aynı siparişin kalemlerinin rastgele sırada çıkması ve
// "cagriSiparisOzeti: adet YALNIZ katalog satırında yazılır" testinin arada bir kırılmasıydı.
//
// Bu dosya `newId()`nin sırayı KORUDUĞUNU kilitler. Determinist üreticiler (uuid5 —
// `deliveryEventId`) bilerek DEĞİŞTİRİLMEDİ; çıktılarının iki cihazda birebir aynı kalması
// idempotensinin şartı olduğu için onlar da burada çivileniyor.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/ids.dart';

/// Zaman damgası öneki: id'nin ilk 13 karakteri (48 bit ms + ayraç) aynı milisaniyeyi gösterir.
String _msOneki(String id) => id.substring(0, 13);

void main() {
  group('newId — aynı milisaniyede bile ARTAN', () {
    test('20.000 id: aynı ms içindeki hiçbir çift ters dönmez', () {
      const adet = 20000;
      final idler = List<String>.generate(adet, (_) => newId());

      var ayniMsCift = 0;
      var tersDonen = 0;
      for (var i = 1; i < adet; i++) {
        if (_msOneki(idler[i]) != _msOneki(idler[i - 1])) continue;
        ayniMsCift++;
        if (idler[i].compareTo(idler[i - 1]) <= 0) tersDonen++;
      }

      // KORUMA: makine çok yavaşsa her id ayrı milisaniyeye düşer ve test hiçbir şey
      // kanıtlamadan yeşil yanar. Ölçümde ms başına ~1000 id üretiliyor.
      expect(ayniMsCift, greaterThan(100),
          reason: 'aynı ms içinde üretim gözlenmedi; test bu hâliyle bir şey kanıtlamaz');
      expect(tersDonen, 0, reason: 'ORDER BY id eklenme sırasını vermek ZORUNDA');
    });

    test('dizinin tamamı kesin artan ve tekil', () {
      const adet = 20000;
      final idler = List<String>.generate(adet, (_) => newId());

      final sirali = [...idler]..sort();
      expect(idler, sirali, reason: 'üretim sırası = sıralama sırası');
      expect(idler.toSet().length, adet, reason: 'çakışma olmamalı');
    });

    test('biçim hâlâ geçerli UUIDv7', () {
      final id = newId();
      expect(id.length, 36);
      expect(id[14], '7', reason: 'sürüm nibble\'ı sayaç tarafından ezilmemeli');
      expect('89ab'.contains(id[19]), isTrue, reason: 'RFC 9562 varyant bitleri');
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
      );
    });
  });

  group('sonrakiSayacDurumu — gerçek zamanla tetiklenemeyen dallar', () {
    test('yeni milisaniye sayacı sıfırlar', () {
      expect(sonrakiSayacDurumu(1000, 999, 42), (ms: 1000, sayac: 0));
    });

    test('aynı milisaniyede sayaç ilerler', () {
      expect(sonrakiSayacDurumu(1000, 1000, 0), (ms: 1000, sayac: 1));
      expect(sonrakiSayacDurumu(1000, 1000, 4094), (ms: 1000, sayac: 4095));
    });

    test('sayaç dolunca sıradaki milisaniyeden ödünç alınır', () {
      // rand_a 12 bit = ms başına 4096 id. Taşma id'leri geri sardırMAMALI.
      expect(sonrakiSayacDurumu(1000, 1000, 4095), (ms: 1001, sayac: 0));
    });

    test('sistem saati GERİ alınırsa id\'ler geri gitmez', () {
      // Kullanıcı telefonun saatini geri aldı: duvar saati 500, bizim son damgamız 1000.
      final s = sonrakiSayacDurumu(500, 1000, 7);
      expect(s.ms, 1000, reason: 'damga asla küçülmez');
      expect(s.sayac, 8, reason: 'sıra sayaçla korunur');
    });

    test('taşma zinciri monoton kalır', () {
      var ms = 1000, sayac = 4095;
      final gecmis = <(int, int)>[];
      for (var i = 0; i < 3; i++) {
        final s = sonrakiSayacDurumu(1000, ms, sayac);
        ms = s.ms;
        sayac = s.sayac;
        gecmis.add((ms, sayac));
      }
      expect(gecmis, [(1001, 0), (1001, 1), (1001, 2)]);
    });
  });

  group('uuid5 üreticileri DEĞİŞMEDİ (idempotensinin şartı)', () {
    test('deliveryEventId deterministik ve namespace sabit', () {
      // Literal, namespace'in sessizce değişmesini yakalar: değişirse iki cihazın uuid5'leri
      // ayrışır ve sunucudaki processed_events dedup'ı çift defter kaydına izin verir.
      expect(deliveryEventId('siparis-1', 'order'),
          '69a33245-3d3f-5644-84f9-b19653870abf');
      expect(deliveryEventId('siparis-1', 'order'), deliveryEventId('siparis-1', 'order'));
    });

    test('tag ve sipariş kimliği ayrı id üretir', () {
      final a = deliveryEventId('siparis-1', 'order');
      final b = deliveryEventId('siparis-1', 'debit');
      final c = deliveryEventId('siparis-2', 'order');
      expect({a, b, c}.length, 3);
      // uuid5 sürüm nibble'ı 5 kalmalı (v7 değişikliği buraya sızmamalı).
      expect(a[14], '5');
    });
  });
}
