import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import 'sync_api.dart';

/// Senkron motoru (DECISIONS): giden kutusunu sunucuya iter (push) ve delta/snapshot çeker (pull).
/// İki işçi tek sınıfta toplanır; ağ tetiği (connectivity) ve zamanlayıcı bunları çağırır.
///
/// Çakışma (istemci tarafı): pull bir varlık değişikliği getirdiğinde, o varlık için GÖNDERİLMEMİŞ
/// (pending) daha yeni occurred_at'li bir outbox düzenlemesi varsa YERELİ KORU (o push sunucuda
/// kazanacak). Defter/olay tabloları append: id/client_event_id ile "yoksa ekle" — asla ezme.
class SyncEngine {
  SyncEngine(this.db, this.api);
  final AppDatabase db;
  final SyncApi api;

  /// Bekleyen outbox olaylarını gönderir. Sonuç: sunucunun yanıtladığı olay sayısı.
  /// applied/duplicate/stale/noop → acked (retry durur). rejected → rejected (elle inceleme).
  Future<int> pushPending({int batchSize = 500}) async {
    final pending = await (db.select(db.outbox)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(batchSize))
        .get();
    if (pending.isEmpty) return 0;

    final events = pending
        .map((r) => <String, Object?>{
              'client_event_id': r.clientEventId,
              'entity_type': r.entityType,
              'op': r.op,
              'occurred_at': r.occurredAt,
              'device_id': r.deviceId,
              'payload': jsonDecode(r.payload),
            })
        .toList();

    final resp = await api.push(events);
    await _applyServerTime(resp.serverTime);
    await _applySubscription(resp.subscription);
    await _applyTeam(resp.team);

    final byId = {for (final res in resp.results) res.clientEventId: res};
    await db.transaction(() async {
      for (final row in pending) {
        final res = byId[row.clientEventId];
        if (res == null) continue; // sunucu yanıtlamadıysa pending kalsın (sonraki retry)
        final rejected = res.status == 'rejected';
        await (db.update(db.outbox)..where((t) => t.id.equals(row.id))).write(
          OutboxCompanion(
            status: Value(rejected ? 'rejected' : 'acked'),
            attempts: Value(row.attempts + 1),
            lastError: Value(rejected ? 'sunucu reddetti' : null),
          ),
        );
      }
    });

    return pending.length;
  }

  /// Sunucudaki değişiklikleri çeker ve yerele uygular. İlk çağrı snapshot, sonrası delta.
  /// has_more olduğu sürece sayfalar (maxPages emniyet sınırı).
  Future<void> pull({int limit = 500, int maxPages = 100}) async {
    for (var page = 0; page < maxPages; page++) {
      final meta = await db.syncState();
      final resp = await api.pull(since: meta.lastPulledSeq, limit: limit);
      await _applyServerTime(resp.serverTime);
      await _applySubscription(resp.subscription);
      await _applyTeam(resp.team);

      if (resp.mode == 'snapshot') {
        await _applySnapshot(resp);
      } else {
        await _applyDelta(resp);
      }
      if (!resp.hasMore) break;
    }
  }

  Future<void> _applySnapshot(PullResponse resp) async {
    await db.transaction(() async {
      for (final entry in resp.entities.entries) {
        for (final row in entry.value) {
          await _applyEntity(entry.key, row);
        }
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        SyncMetaCompanion(lastPulledSeq: Value(resp.cursor), snapshotDone: const Value(true)),
      );
    });
  }

  Future<void> _applyDelta(PullResponse resp) async {
    await db.transaction(() async {
      for (final change in resp.changes) {
        final type = change['entity_type'] as String;
        final payload = (change['payload'] as Map).cast<String, dynamic>();
        await _applyEntity(type, payload, checkConflict: true, changeOccurredAt: change['occurred_at'] as String?);
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(lastPulledSeq: Value(resp.cursor)));
    });
  }

  /// LWW varlıkları için çakışma kuralı uygulanan tipler.
  static const _conflictTypes = {
    'customer',
    'customer_phone',
    'customer_address',
    'product',
    'order',
    'exempt_number',
    'call_log',
  };

  Future<void> _applyEntity(
    String type,
    Map<String, dynamic> m, {
    bool checkConflict = false,
    String? changeOccurredAt,
  }) async {
    if (checkConflict && _conflictTypes.contains(type)) {
      if (await _newerPending(type, m['id'], changeOccurredAt)) {
        return; // yerelde daha yeni gönderilmemiş düzenleme var → sunucu satırını uygulama
      }
    }

    switch (type) {
      case 'customer':
        await db.into(db.customers).insertOnConflictUpdate(CustomersCompanion(
              id: Value(_s(m['id'])),
              name: Value(_s(m['name'])),
              note: Value(_sN(m['note'])),
              // Kodu SUNUCU üretir; istemci hiç göndermez (bkz. Customers.code). Eski sunucu
              // sürümü alanı hiç göndermezse `null` yazılır ve arayüz kodsuz gösterir —
              // uydurma bir numara asla yazılmaz.
              code: Value(_iN(m['code'])),
              balanceKurus: Value(_i(m['balance_kurus'] ?? 0)),
              blacklistedAt: Value(_sN(m['blacklisted_at'])),
              updatedOccurredAt: Value(_s(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'customer_phone':
        await db.into(db.customerPhones).insertOnConflictUpdate(CustomerPhonesCompanion(
              id: Value(_s(m['id'])),
              customerId: Value(_s(m['customer_id'])),
              phoneE164: Value(_s(m['phone_e164'])),
              phoneLast10: Value(_s(m['phone_last10'])),
              label: Value(_sN(m['label'])),
              isPrimary: Value(_b(m['is_primary'])),
              updatedOccurredAt: Value(_s(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'customer_address':
        await db.into(db.customerAddresses).insertOnConflictUpdate(CustomerAddressesCompanion(
              id: Value(_s(m['id'])),
              customerId: Value(_s(m['customer_id'])),
              label: Value(_sN(m['label'])),
              addressText: Value(_s(m['address_text'])),
              region: Value(_sN(m['region'])),
              lat: Value(_dN(m['lat'])),
              lng: Value(_dN(m['lng'])),
              isPrimary: Value(_b(m['is_primary'])),
              updatedOccurredAt: Value(_s(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'product':
        await db.into(db.products).insertOnConflictUpdate(ProductsCompanion(
              id: Value(_s(m['id'])),
              name: Value(_s(m['name'])),
              unitPriceKurus: Value(_i(m['unit_price_kurus'])),
              unit: Value(_s(m['unit'])),
              barcode: Value(_sN(m['barcode'])),
              imageUrl: Value(_sN(m['image_url'])),
              // imageLocalPath BİLEREK yazılmaz: cihaz-yerel alandır, sunucu payload'ında yoktur;
              // buraya null yazmak kullanıcının bu cihazdaki görselini silerdi.
              isActive: Value(_b(m['is_active'])),
              updatedOccurredAt: Value(_s(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'order':
        await db.into(db.orders).insertOnConflictUpdate(OrdersCompanion(
              id: Value(_s(m['id'])),
              customerId: Value(_sN(m['customer_id'])),
              code: Value(_iN(m['code'])), // sunucu atar (bkz. Orders.code)
              assignedUserId: Value(_sN(m['assigned_user_id'])),
              status: Value(_s(m['status'])),
              totalKurus: Value(_i(m['total_kurus'])),
              paymentType: Value(_sN(m['payment_type'])),
              note: Value(_sN(m['note'])),
              sortIndex: Value(_iN(m['sort_index'])),
              occurredAt: Value(_s(m['occurred_at'])),
              createdDeviceId: Value(_sN(m['created_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'order_line':
        await db.into(db.orderLines).insertOnConflictUpdate(OrderLinesCompanion(
              id: Value(_s(m['id'])),
              orderId: Value(_s(m['order_id'])),
              productId: Value(_sN(m['product_id'])),
              productName: Value(_s(m['product_name'])),
              unitPriceKurus: Value(_i(m['unit_price_kurus'])),
              unit: Value(_sN(m['unit'])),
              isCustom: Value(_b(m['is_custom'])),
              qty: Value(_i(m['qty'])),
              lineTotalKurus: Value(_i(m['line_total_kurus'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'order_event':
        await _insertOrderEventIfAbsent(m);
      case 'ledger_entry':
        await _insertLedgerIfAbsent(m);
      case 'cash_handover':
        await _insertCashHandoverIfAbsent(m);
      case 'exempt_number':
        await db.into(db.exemptNumbers).insertOnConflictUpdate(ExemptNumbersCompanion(
              id: Value(_s(m['id'])),
              phoneE164: Value(_s(m['phone_e164'])),
              phoneLast10: Value(_s(m['phone_last10'])),
              label: Value(_sN(m['label'])),
              updatedOccurredAt: Value(_s(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'call_log':
        await db.into(db.callLogs).insertOnConflictUpdate(CallLogsCompanion(
              id: Value(_s(m['id'])),
              customerId: Value(_sN(m['customer_id'])),
              phoneE164: Value(_s(m['phone_e164'])),
              phoneLast10: Value(_s(m['phone_last10'])),
              direction: Value(_s(m['direction'])),
              outcome: Value(_sN(m['outcome'])),
              relatedOrderId: Value(_sN(m['related_order_id'])),
              occurredAt: Value(_s(m['occurred_at'])),
              deviceId: Value(_sN(m['device_id'])),
              updatedOccurredAt: Value(_s(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
              deletedAt: Value(_sN(m['deleted_at'])),
            ));
      case 'tenant_settings':
        // Sunucuda anahtar tenant_id; cihazda TEK SATIR (id=1) — istemci tek kiracıdır.
        await db.into(db.tenantSettings).insertOnConflictUpdate(TenantSettingsCompanion(
              id: const Value(1),
              businessName: Value(_sN(m['business_name'])),
              ownerName: Value(_sN(m['owner_name'])),
              phone: Value(_sN(m['phone'])),
              whatsapp: Value(_sN(m['whatsapp'])),
              addressText: Value(_sN(m['address_text'])),
              taxOffice: Value(_sN(m['tax_office'])),
              taxNumber: Value(_sN(m['tax_number'])),
              opensAt: Value(_sN(m['opens_at'])),
              closesAt: Value(_sN(m['closes_at'])),
              receiptNote: Value(_sN(m['receipt_note'])),
              // Sunucu alanı göndermezse (eski sürüm) varsayılana düşülür — `Value(null)`
              // yazmak NOT NULL kolonu bozardı.
              orderCodeDisplay: Value(_sN(m['order_code_display']) ?? 'musteri'),
              updatedOccurredAt: Value(_sN(m['updated_occurred_at'])),
              updatedDeviceId: Value(_sN(m['updated_device_id'])),
            ));
      case 'day_closing':
        await _insertDayClosingIfAbsent(m);
    }
  }

  Future<void> _insertOrderEventIfAbsent(Map<String, dynamic> m) async {
    final cid = _s(m['client_event_id']);
    final exists = await (db.select(db.orderEvents)..where((t) => t.clientEventId.equals(cid))).getSingleOrNull();
    if (exists != null) return;

    final payload = m['payload'];
    await db.into(db.orderEvents).insert(OrderEventsCompanion.insert(
          id: _s(m['id']),
          orderId: _s(m['order_id']),
          eventType: _s(m['event_type']),
          payload: Value(payload == null ? null : (payload is String ? payload : jsonEncode(payload))),
          clientEventId: cid,
          occurredAt: _s(m['occurred_at']),
          deviceId: Value(_sN(m['device_id'])),
        ));
  }

  Future<void> _insertLedgerIfAbsent(Map<String, dynamic> m) async {
    final id = _s(m['id']);
    final exists = await (db.select(db.ledgerEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (exists != null) return;

    await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: id,
          customerId: Value(_sN(m['customer_id'])),
          entryType: _s(m['entry_type']),
          amountKurus: _i(m['amount_kurus']),
          paymentType: Value(_sN(m['payment_type'])),
          collectedByUserId: Value(_sN(m['collected_by_user_id'])),
          relatedOrderId: Value(_sN(m['related_order_id'])),
          reversesEntryId: Value(_sN(m['reverses_entry_id'])),
          note: Value(_sN(m['note'])),
          occurredAt: _s(m['occurred_at']),
          deviceId: Value(_sN(m['device_id'])),
          clientEventId: _s(m['client_event_id']),
        ));
  }

  Future<void> _insertCashHandoverIfAbsent(Map<String, dynamic> m) async {
    final id = _s(m['id']);
    final exists = await (db.select(db.cashHandovers)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (exists != null) return;

    await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
          id: id,
          fromUserId: _s(m['from_user_id']),
          toUserId: Value(_sN(m['to_user_id'])),
          countedCashKurus: _i(m['counted_cash_kurus']),
          expectedCashKurus: _i(m['expected_cash_kurus']),
          diffKurus: _i(m['diff_kurus']),
          periodStart: Value(_sN(m['period_start'])),
          occurredAt: _s(m['occurred_at']),
          deviceId: Value(_sN(m['device_id'])),
          note: Value(_sN(m['note'])),
        ));
  }

  /// Kapanış arşivi APPEND'dir (cash_handover deseni): "yoksa ekle", asla ezme.
  Future<void> _insertDayClosingIfAbsent(Map<String, dynamic> m) async {
    final id = _s(m['id']);
    final exists = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (exists != null) return;

    await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
          id: id,
          scope: _s(m['scope']),
          userId: Value(_sN(m['user_id'])),
          periodStart: Value(_sN(m['period_start'])),
          deliveryCount: Value(_i(m['delivery_count'] ?? 0)),
          totalCollectedKurus: Value(_i(m['total_collected_kurus'] ?? 0)),
          cashNakitKurus: Value(_i(m['cash_nakit_kurus'] ?? 0)),
          cashKartKurus: Value(_i(m['cash_kart_kurus'] ?? 0)),
          cashHavaleKurus: Value(_i(m['cash_havale_kurus'] ?? 0)),
          openCreditKurus: Value(_i(m['open_credit_kurus'] ?? 0)),
          expectedCashKurus: Value(_i(m['expected_cash_kurus'] ?? 0)),
          countedCashKurus: Value(_iN(m['counted_cash_kurus'])),
          diffKurus: Value(_i(m['diff_kurus'] ?? 0)),
          cashHandoverId: Value(_sN(m['cash_handover_id'])),
          note: Value(_sN(m['note'])),
          occurredAt: _s(m['occurred_at']),
          deviceId: Value(_sN(m['device_id'])),
        ));
  }

  Future<bool> _newerPending(String type, dynamic entityId, String? changeAt) async {
    if (entityId is! String || changeAt == null) return false;
    final serverT = DateTime.tryParse(changeAt);
    if (serverT == null) return false;

    final rows = await (db.select(db.outbox)
          ..where((t) => t.status.equals('pending') & t.entityType.equals(type) & t.entityId.equals(entityId)))
        .get();
    return rows.any((r) {
      final localT = DateTime.tryParse(r.occurredAt);
      return localT != null && localT.isAfter(serverT);
    });
  }

  /// Abonelik durumunu sync_meta'ya önbellekle (FAZ 5a — DECISIONS: tek doğru kaynak sunucu).
  /// İstemci kilit/grace kararını bu önbellek + ileri-sadece saatle verir (SubscriptionState).
  Future<void> _applySubscription(SubscriptionInfo? sub) async {
    if (sub == null) return;
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(
      validUntilIso: Value(sub.validUntil),
      lockedAtIso: Value(sub.lockedAt),
      subscriptionStatus: Value(sub.status),
      // Sunucu sahipli alanlar: yalnız sunucu GÖNDERDİYSE yazılır (eski sunucu null yollarsa
      // mevcut önbellek korunur — team bloğundaki "null'a dokunma" ilkesinin aynısı).
      tenantCode: sub.tenantCode == null ? const Value.absent() : Value(sub.tenantCode),
      routeCredits: sub.routeCredits == null ? const Value.absent() : Value(sub.routeCredits!),
      routeCreditsMonthly: sub.routeCreditsMonthly == null
          ? const Value.absent()
          : Value(sub.routeCreditsMonthly!),
    ));
  }

  /// Ekip listesini yerel `users` aynasına TOPTAN yaz (FAZ 4b Dilim 4 — team bloğu önbelleği).
  /// team NULL ise (eski sunucu anahtarı hiç göndermedi) tabloya DOKUNMA — yoksa mevcut ekip
  /// listesi kaybolur ve kurye adımları yanlışlıkla gizlenir (KRİTİK, architect §7). team boş
  /// liste ([]) ise tablo boşaltılır (bayinin gerçekten kullanıcısı yok/hepsi başka tenant değil).
  /// LWW/tombstone yok: sunucu tam listeyi her seferinde verir → delete-all + insert-all.
  Future<void> _applyTeam(List<Map<String, dynamic>>? team) async {
    if (team == null) return;
    await db.transaction(() async {
      await db.delete(db.users).go();
      for (final u in team) {
        await db.into(db.users).insert(UsersCompanion.insert(
              id: _s(u['id']),
              name: _s(u['name']),
              role: _s(u['role']),
              status: _s(u['status']),
              phone: Value(_sN(u['phone'])),
            ));
      }
    });
  }

  /// server_time'dan saat offset'i türet (DECISIONS: istemci offset tutar).
  Future<void> _applyServerTime(String? iso) async {
    if (iso == null) return;
    final server = DateTime.tryParse(iso);
    if (server == null) return;
    final offset = server.toUtc().difference(DateTime.now().toUtc()).inMilliseconds;
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
      SyncMetaCompanion(serverTimeOffsetMs: Value(offset), lastServerTimeIso: Value(iso)),
    );
  }

  // ---- JSON tip yardımcıları (sunucu attributesToArray çıktısını güvenli çevir) ----
  static int _i(dynamic v) => (v as num).toInt();
  static int? _iN(dynamic v) => v == null ? null : (v as num).toInt();
  static double? _dN(dynamic v) => v == null ? null : (v as num).toDouble();
  static String _s(dynamic v) => v as String;
  static String? _sN(dynamic v) => v as String?;
  static bool _b(dynamic v) => v == true || v == 1;
}
