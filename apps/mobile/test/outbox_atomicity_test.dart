import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/ids.dart';
import 'package:sipario/data/outbox.dart';

/// DECISIONS (Senkron): "Yazma yolu outbox üzerinden — uygulama asla doğrudan API'ye yazmaz;
/// yerel SQLite + outbox aynı işlemde yazılır." Repository katmanının her mutasyonu bu deseni
/// kullanır (bkz. CustomerRepository/OrderRepository/ProductRepository — hepsi db.transaction()
/// içinde yerel yazım + enqueueOutbox). Bu dosya deseni doğrudan sınar: transaction'ın bir adımı
/// (outbox'un unique client_event_id kısıtı) başarısız olursa YEREL YAZMA da geri alınmalı —
/// yoksa "yazıldı ama kimseye bildirilmedi" sınıfı bir tutarsızlık (senkronsuz sessiz veri) doğar.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('outbox atomikliği: transaction içindeki bir adım başarısız olursa yerel yazma da geri alınır', () async {
    const dupEventId = 'CAKISAN-CLIENT-EVENT-ID';
    // Baştan bir outbox satırı — ikinci enqueue aynı client_event_id ile unique kısıtını ihlal edecek.
    await db.into(db.outbox).insert(OutboxCompanion.insert(
          clientEventId: dupEventId,
          entityType: 'customer',
          op: 'upsert',
          payload: '{}',
          occurredAt: nowIso(),
          createdAt: nowIso(),
        ));

    final customerId = newId();
    await expectLater(
      db.transaction(() async {
        // Repository'lerin yaptığı gibi: önce yerel yazım...
        await db.into(db.customers).insert(CustomersCompanion.insert(
              id: customerId,
              name: 'Yarım Kalacak Müşteri',
              updatedOccurredAt: nowIso(),
            ));
        // ...sonra AYNI transaction'da outbox — bilerek ÇAKIŞAN client_event_id ile patlar.
        await enqueueOutbox(
          db,
          entityType: 'customer',
          op: 'upsert',
          entityId: customerId,
          occurredAt: nowIso(),
          payload: {'id': customerId},
          clientEventId: dupEventId,
        );
      }),
      throwsA(anything),
    );

    // Transaction TAMAMEN geri alındı: yalnız outbox adımı değil, müşteri satırı da KALICI olmamalı.
    final cust = await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
    expect(cust, isNull, reason: 'Outbox adımı başarısız olursa aynı transaction\'daki yerel yazma da geri alınmalı.');

    // Başlangıçtaki tek outbox satırı hâlâ duruyor; ikinci deneme hiçbir iz bırakmadı.
    final outboxRows = await (db.select(db.outbox)..where((t) => t.clientEventId.equals(dupEventId))).get();
    expect(outboxRows, hasLength(1));
    final allCustomers = await db.select(db.customers).get();
    expect(allCustomers, isEmpty);
  });

  test('newId UUIDv7 formatında, versiyon/varyant doğru ve zamanla artar', () async {
    final id1 = newId();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final id2 = newId();

    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(id1, matches(re), reason: 'newId() UUIDv7 formatında olmalı (versiyon nibble 7, varyant 8/9/a/b).');
    expect(id2, matches(re));

    // DECISIONS: "Kimlikler UUIDv7 ve istemcide üretilir ... senkron sırası önemsizleşir" —
    // zaman-sıralı olması index dostu olmasının VE senkron sırasının temelidir.
    expect(
      id1.compareTo(id2),
      lessThan(0),
      reason: 'UUIDv7 zaman-sıralıdır: sonra üretilen id, string sırasında da öncekinden büyük olmalı.',
    );
  });

  test('newId üretilen her kimlik biricik (çakışma yok)', () {
    final ids = List.generate(200, (_) => newId());
    expect(ids.toSet(), hasLength(200));
  });
}
