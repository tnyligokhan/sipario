import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/phase0/local_db.dart';
import 'package:sipario/phase0/measurements.dart';

String _log(List<Map<String, dynamic>> entries) => jsonEncode(entries);

Map<String, dynamic> _m({
  int ms = 300,
  bool matched = true,
  bool simulated = false,
  String path = 'overlay',
  bool locked = false,
  String direction = 'in',
}) =>
    {
      'ms': ms,
      'matched': matched,
      'simulated': simulated,
      'path': path,
      'locked': locked,
      'dir': direction,
      'at': 1700000000000,
    };

/// Kilit ekranında geçerli sayılan tek yol.
Map<String, dynamic> _locked({int ms = 300}) =>
    _m(ms: ms, path: 'fullscreen', locked: true);

void main() {
  group('telefon normalizasyonu', () {
    test('aynı numaranın üç yazımı aynı anahtara düşer', () {
      expect(LocalDb.last10('+905321112233'), '5321112233');
      expect(LocalDb.last10('05321112233'), '5321112233');
      expect(LocalDb.last10('5321112233'), '5321112233');
    });

    test('boşluk ve ayraçlar temizlenir', () {
      expect(LocalDb.last10('0532 111 22 33'), '5321112233');
      expect(LocalDb.last10('(0532) 111-22-33'), '5321112233');
    });

    test('sabit hat numarası da 10 haneye iner', () {
      expect(LocalDb.last10('+902422223344'), '2422223344');
    });

    test('eksik numara olduğu gibi döner, eşleşme aranmaz', () {
      expect(LocalDb.last10('112'), '112');
    });
  });

  group('kilit ekranı', () {
    test('kilitliyken overlay GÖSTERİM SAYILMAZ — pencere keyguard altında kalır', () {
      final m = Measurement.fromJson(_m(path: 'overlay', locked: true));
      expect(m.shown, isFalse,
          reason: 'çizildi ve onDraw tetiklendi ama kullanıcı göremedi');
    });

    test('kilitliyken yalnız tam ekran yolu gösterim sayılır', () {
      expect(Measurement.fromJson(_locked()).shown, isTrue);
    });

    test('kilitsizken overlay gösterim sayılır', () {
      expect(Measurement.fromJson(_m(path: 'overlay')).shown, isTrue);
    });

    test('kilitliyken bildirime düşmek gösterim sayılmaz', () {
      final m = Measurement.fromJson(_m(path: 'notification', locked: true));
      expect(m.shown, isFalse);
    });

    test('locked alanı olmayan eski kayıtlar kilitsiz varsayılır', () {
      final m = Measurement.fromJson({
        'ms': 300,
        'matched': true,
        'simulated': false,
        'path': 'overlay',
        'at': 1700000000000,
      });
      expect(m.locked, isFalse);
      expect(m.direction, 'in');
      expect(m.shown, isTrue);
    });
  });

  group('giden aramalar', () {
    test('giden arama go/no-go sayımına girmez — hedef 20 GELEN aramadır', () {
      final entries = [
        ...List.generate(15, (_) => _m(ms: 250)),
        ...List.generate(5, (_) => _locked()),
        ...List.generate(10, (_) => _m(ms: 250, direction: 'out')),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.total, 20, reason: 'giden aramalar hariç');
      expect(v.outgoing.length, 10);
      expect(v.pass, isTrue);
    });

    test('yalnız giden aramalarla GO alınamaz', () {
      final v = Verdict(
        Measurement.parse(_log(List.generate(25, (_) => _m(direction: 'out')))),
      );
      expect(v.total, 0);
      expect(v.pass, isFalse);
    });
  });

  group('go/no-go kararı', () {
    test('20 hızlı arama + yeterli kilitli örnek GO verir', () {
      final entries = [
        ...List.generate(15, (_) => _m(ms: 250)),
        ...List.generate(5, (_) => _locked(ms: 400)),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.total, 20);
      expect(v.missed, 0);
      expect(v.lockedShown, 5);
      expect(v.pass, isTrue);
      expect(v.label, 'GO');
    });

    test('kilit ekranı hiç sınanmadıysa GO verilmez — sahada telefon çoğu zaman kilitli', () {
      final v = Verdict(Measurement.parse(_log(List.generate(20, (_) => _m(ms: 250)))));
      expect(v.enoughSamples, isTrue);
      expect(v.enoughLocked, isFalse);
      expect(v.pass, isFalse);
      expect(v.label, contains('Kilit ekranı sınanmadı'));
    });

    test('kilitli aramalarda overlay çizilmişse bunlar kaçırılmış sayılır', () {
      final entries = [
        ...List.generate(15, (_) => _m(ms: 250)),
        ...List.generate(5, (_) => _m(ms: 60, path: 'overlay', locked: true)),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.lockedCalls.length, 5);
      expect(v.lockedShown, 0);
      expect(v.missed, 5, reason: 'hızlı çizildiler ama görünmediler');
      expect(v.pass, isFalse);
      expect(v.label, 'NO-GO');
    });

    test('20 aramadan biri hedefi aşarsa NO-GO', () {
      final entries = [
        ...List.generate(14, (_) => _m(ms: 250)),
        ...List.generate(5, (_) => _locked(ms: 300)),
        _m(ms: 1400),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.withinTarget, 19);
      expect(v.pass, isFalse);
      expect(v.label, 'NO-GO');
    });

    test('tek bir kaçırılan çağrı NO-GO — bayi telefonu açtığında ekran boşsa vaat çökmüştür', () {
      final entries = [
        ...List.generate(14, (_) => _m(ms: 250)),
        ...List.generate(5, (_) => _locked()),
        _m(ms: -1, path: 'failed'),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.missed, 1);
      expect(v.pass, isFalse);
    });

    test('simüle çağrılar sayıma girmez — süreç ayakta olduğu için asıl maliyeti ölçmez', () {
      final entries = [
        ...List.generate(30, (_) => _m(ms: 80, simulated: true)),
        ...List.generate(5, (_) => _m(ms: 250)),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.total, 5);
      expect(v.simulated.length, 30);
      expect(v.enoughSamples, isFalse);
      expect(v.pass, isFalse, reason: 'simülasyonla GO alınamaz');
      expect(v.label, contains('5/20'));
    });

    test('yetersiz örnekle GO verilmez', () {
      final v = Verdict(Measurement.parse(_log(List.generate(19, (_) => _m(ms: 100)))));
      expect(v.pass, isFalse);
      expect(v.label, 'Ölçüm sürüyor — 19/20 arama');
    });

    test('tam hedef sınırı (1000 ms) geçerli sayılır', () {
      final entries = [
        ...List.generate(15, (_) => _m(ms: 1000)),
        ...List.generate(5, (_) => _locked(ms: 1000)),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.pass, isTrue);
    });

    test('gösterilemeyen ölçüm medyan ve en kötü hesabına karışmaz', () {
      final entries = [
        _m(ms: 100),
        _m(ms: 200),
        _m(ms: 300),
        _m(ms: -1, path: 'failed'),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.median, 200);
      expect(v.worst, 300);
    });

    test('overlay, tam ekran ve bildirim yolları ayrı sayılır', () {
      final entries = [
        ...List.generate(3, (_) => _m(path: 'overlay')),
        ...List.generate(4, (_) => _locked()),
        ...List.generate(2, (_) => _m(path: 'notification')),
      ];
      final v = Verdict(Measurement.parse(_log(entries)));
      expect(v.viaOverlay, 3);
      expect(v.viaFullScreen, 4);
      expect(v.viaNotification, 2);
    });
  });
}
