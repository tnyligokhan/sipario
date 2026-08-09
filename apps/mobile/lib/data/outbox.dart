import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'ids.dart';

/// YEREL YAZIM SİNYALİ — "outbox'a bir kayıt düştü" (2026-08-09 saha arızası).
///
/// ARIZA: patron siparişi kuryeye atıyor, kurye yenilese bile GÖREMİYOR; patron uygulamayı alta
/// alıp öne getirince görünüyor. Sebep, atamanın kaybolması değil — atama outbox'a düzgün
/// düşüyordu — sunucuya GİDECEĞİ ANIN hiçbir yerde tetiklenmemesiydi: tur yalnız dört DIŞ olayla
/// açılıyordu (2 dk zamanlayıcı · ağ değişimi · uygulamanın öne gelmesi · aşağı çekerek yenileme).
/// "Alta alıp açınca gidiyor" gözlemi tam olarak `AppLifecycleState.resumed` turudur.
///
/// NEDEN BURADA, HER YAZIM YERİNDE DEĞİL: outbox'a yazan 30 nokta var (sipariş · defter · kasa
/// devri · gün kapanışı · müşteri · ürün · kurye · çağrı günlüğü · muaf numara · işletme ayarları)
/// ve hepsi bu tek fonksiyondan geçiyor. Tetiği repo'lara tek tek eklemek 15 dosyayı değiştirir,
/// yarın eklenecek yazımda unutulur ve repo katmanını senkron servisine bağımlı kılardı — bugün
/// repo'lar senkrondan tamamen habersiz, bu iyi bir sınır.
///
/// NEDEN AKIŞ, DOĞRUDAN ÇAĞRI DEĞİL: `data/` katmanı `sync/`i TANIMAMALI. Sinyal ters yönde akar
/// — burası yalnız "oldu" der, kimin dinlediğini bilmez; `SyncService` dinler (bkz.
/// `sync_service.dart::yazimTetigiBagla`). Dinleyen yoksa olay sessizce düşer: test ve önizleme
/// ağaçlarında senkron servisi yoktur ve orada çökmek doğru davranış değildir.
final _yazimDenetleyici = StreamController<void>.broadcast();

/// Yerel yazımların akışı — her outbox kaydında bir olay. Dinleyen taraf DEBOUNCE etmelidir:
/// tek bir işlem (ör. teslim = 1 sipariş olayı + 3 defter kaydı) art arda birkaç olay üretir.
Stream<void> get outboxYazimlari => _yazimDenetleyici.stream;

/// Bir yerel yazımın outbox olayını ekler (DECISIONS: yazma yolu outbox üzerinden; yerel yazma +
/// outbox AYNI transaction'da). Payload sunucu ChangeApplier'ın beklediği şekle serialize edilir.
///
/// Sinyal INSERT'ten sonra yayılır ama çağıran bir transaction'ın İÇİNDEDİR (`db.transaction`),
/// yani commit henüz olmamıştır. Sorun değil: dinleyen taraf turu gecikmeyle açar (bkz.
/// [outboxYazimlari]) ve Drift aynı bağlantıdaki sorguları sıraya alır — en kötü hâlde push
/// sorgusu commit'i bekler, kayıt ATLANMAZ. Yayın çağıranı BLOKLAMAZ (broadcast controller
/// dinleyicilere eşzamansız dağıtır): BRIEF kırmızı çizgi #3 — yazma yolu ağa asla bağlanmaz.
Future<void> enqueueOutbox(
  AppDatabase db, {
  required String entityType,
  required String op,
  String? entityId,
  required Map<String, Object?> payload,
  required String occurredAt,
  String? deviceId,
  String? clientEventId,
}) async {
  await db.into(db.outbox).insert(
        OutboxCompanion.insert(
          clientEventId: clientEventId ?? newId(),
          entityType: entityType,
          op: op,
          entityId: Value(entityId),
          payload: jsonEncode(payload),
          occurredAt: occurredAt,
          deviceId: Value(deviceId),
          createdAt: nowIso(),
        ),
      );
  // Denetleyici hiç KAPATILMAZ (uygulama ömrü boyunca tek örnek, `guncellemeServisi` tekilinin
  // deseni) — bu yüzden burada "kapalı mı" kontrolü yok; dinleyicisi olmayan broadcast akışa
  // yayın yapmak zararsızdır, olay düşer.
  _yazimDenetleyici.add(null);
}

/// Son 10 hane — arayan tanımanın eşleşme anahtarı (Türkiye'de aynı numaranın üç yazımı da aynı).
String phoneLast10(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
}
