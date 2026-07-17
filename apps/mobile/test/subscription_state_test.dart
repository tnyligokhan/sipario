import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/subscription/subscription_state.dart';

/// FAZ 5a — istemci abonelik erişim kararı (SAF mantık; DECISIONS "Abonelik ve kilit").
/// Grace YALNIZ istemcide (7 gün, sunucuya ulaşılamadığında); valid_until gelecekte → tam; sunucu
/// locked/suspended dediyse otorite sunucu → salt-okunur.
void main() {
  final now = DateTime.utc(2026, 7, 15, 12);

  group('SubscriptionState.evaluate', () {
    test('valid_until gelecekte → full (offline süresi önemsiz)', () {
      final level = SubscriptionState.evaluate(
          estimatedServerNow: now, validUntil: now.add(const Duration(days: 200)), status: 'active');
      expect(level, AccessLevel.full);
      expect(SubscriptionState.writable(level), isTrue);
    });

    test('valid_until NULL → full (süre/kısıt yok, sunucu kilitsiz ile simetrik)', () {
      expect(SubscriptionState.evaluate(estimatedServerNow: now, validUntil: null, status: 'trial'),
          AccessLevel.full);
    });

    test('sunucu locked → salt-okunur (grace atlanır, otorite sunucu)', () {
      final level = SubscriptionState.evaluate(
          estimatedServerNow: now, validUntil: now.subtract(const Duration(days: 1)), status: 'locked');
      expect(level, AccessLevel.readOnly);
      expect(SubscriptionState.writable(level), isFalse);
    });

    test('sunucu suspended → salt-okunur', () {
      expect(
          SubscriptionState.evaluate(estimatedServerNow: now, validUntil: null, status: 'suspended'),
          AccessLevel.readOnly);
    });

    test('valid_until 3 gün önce (7 gün içinde) → grace (yazılabilir)', () {
      final level = SubscriptionState.evaluate(
          estimatedServerNow: now, validUntil: now.subtract(const Duration(days: 3)), status: 'active');
      expect(level, AccessLevel.grace);
      expect(SubscriptionState.writable(level), isTrue, reason: 'grace yazmayı durdurmaz');
    });

    test('valid_until tam 7 gün önce → grace (sınır dahil)', () {
      expect(
          SubscriptionState.evaluate(
              estimatedServerNow: now, validUntil: now.subtract(const Duration(days: 7)), status: 'active'),
          AccessLevel.grace);
    });

    test('valid_until 8 gün önce (grace sonrası) → salt-okunur', () {
      final level = SubscriptionState.evaluate(
          estimatedServerNow: now, validUntil: now.subtract(const Duration(days: 8)), status: 'active');
      expect(level, AccessLevel.readOnly);
    });
  });

  group('SubscriptionState.estimateServerNow (ileri-sadece)', () {
    test('sistem saati geri alınırsa lastServerTime tabanına iner (grace uzatılamaz)', () {
      final wallBack = DateTime.utc(2026, 1, 1); // kullanıcı saati geriye aldı
      final lastServer = DateTime.utc(2026, 7, 15, 12).toIso8601String();
      final est = SubscriptionState.estimateServerNow(
          serverTimeOffsetMs: 0, lastServerTimeIso: lastServer, wallClockNow: wallBack);
      expect(est, DateTime.utc(2026, 7, 15, 12), reason: 'geri alınan saat tabanın altına inemez');
    });

    test('offset uygulanır, taban geçilince ileri gider', () {
      final wall = DateTime.utc(2026, 7, 15, 12);
      final est = SubscriptionState.estimateServerNow(
          serverTimeOffsetMs: 60000, lastServerTimeIso: DateTime.utc(2026, 7, 15, 11).toIso8601String(),
          wallClockNow: wall);
      expect(est, DateTime.utc(2026, 7, 15, 12, 1), reason: 'wall + 60sn offset, taban aşıldı');
    });
  });
}
