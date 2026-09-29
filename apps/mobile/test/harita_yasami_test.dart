// HARİTA YAŞAM DÖNGÜSÜ — MapKit onStart/onStop kuralı (saha arızası 2026-09-29).
//
// "Yandex haritası geldi ama sadece boş karolar görünüyor": başlatma, kurulum sonucu kaydedilmeden
// deneniyordu ve onStart HİÇ çağrılmıyordu. MapKit onStart görmeden karo indirmez. Widget testleri
// bunu göremezdi (sahte tuval kullanıyorlar); kural bu yüzden ayrı bir sınıfta ve burada kilitli.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/orders/harita_yandex.dart';

/// Yaşam döngüsü + çağrı sayaçları. Fikstür sınıfı: her test kendi sayacını okur.
class _Dongu {
  int baslat = 0;
  int durdur = 0;
  late final HaritaYasami yasam = HaritaYasami(
    basla: () => baslat++,
    bitir: () => durdur++,
  );
}

void main() {
  test('KURULUM BİTİNCE MapKit BAŞLAR — sahadaki boş karo arızası', () {
    final d = _Dongu();
    expect(d.baslat, 0, reason: 'kurulum bitmeden başlatılmaz');
    d.yasam.hazirlandi(true);
    expect(d.baslat, 1);
    expect(d.yasam.basladi, isTrue);
  });

  test('anahtar yok (kurulamadı) → HİÇ başlamaz', () {
    final d = _Dongu();
    d.yasam
      ..hazirlandi(false)
      ..gorunurluk(true);
    expect(d.baslat, 0);
    expect(d.yasam.hazir, isFalse);
  });

  test('arka plan durdurur, ön plan yeniden başlatır', () {
    final d = _Dongu();
    d.yasam
      ..hazirlandi(true)
      ..gorunurluk(false);
    expect(d.durdur, 1);
    d.yasam.gorunurluk(true);
    expect(d.baslat, 2);
  });

  test('kurulum arka plandayken biterse başlamaz, öne gelince başlar — sıra önemsiz', () {
    final d = _Dongu();
    d.yasam
      ..gorunurluk(false)
      ..hazirlandi(true);
    expect(d.baslat, 0);
    d.yasam.gorunurluk(true);
    expect(d.baslat, 1);
  });

  test('aynı olay tekrarlanırsa ikinci kez başlatılmaz (sayaç kaymaz)', () {
    final d = _Dongu();
    d.yasam
      ..hazirlandi(true)
      ..gorunurluk(true)
      ..gorunurluk(true);
    expect(d.baslat, 1);
  });

  test('kapanınca durur, sonra hiçbir olay yeniden başlatmaz', () {
    final d = _Dongu();
    d.yasam
      ..hazirlandi(true)
      ..kapat();
    expect(d.durdur, 1);
    d.yasam.gorunurluk(true);
    expect(d.baslat, 1);
  });

  test('hiç başlamamış harita kapanırken durdurma çağrılmaz', () {
    final d = _Dongu();
    d.yasam.kapat();
    expect(d.durdur, 0);
  });
}
