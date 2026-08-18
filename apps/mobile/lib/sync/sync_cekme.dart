// PULL TURU — sunucudaki değişiklikleri çeker ve yerele yazar.
//
// Üç iş bir arada durur çünkü üçü de TEK bir sayfayı işlemenin evreleridir ve sıraları
// pazarlıksızdır:
//   1. SAYFALAMA ([SyncCekme.pull]) — snapshot/delta ayrımı, `lastPulledSeq` ilerlemesi.
//   2. ÇAKIŞMA ([SyncCekme._newerPending]) — LWW varlıklarında yerelde daha yeni GÖNDERİLMEMİŞ
//      bir düzenleme varsa sunucu satırı UYGULANMAZ (o push sunucuda kazanacak).
//   3. SATIR YAZIMI ([SyncCekme._applyEntity]) — tip başına drift companion'ı; defter/olay
//      tabloları APPEND ("yoksa ekle", asla ezme).
//
// ⚠️ SIRA SEMANTİĞİ: çakışma kontrolü satır yazımından ÖNCE ve `_guvenliUygula` kapısının
// İÇİNDE koşar — kontrolün kendisi patlarsa da kayıp o satıra hapsedilir. Cursor yazımı
// sayfanın SONUNDA, aynı transaction içinde: satırlar yazılmadan cursor ilerlerse veri kaybolur,
// cursor hiç ilerlemezse senkron kalıcı ölür (bkz. `SyncEngine._guvenliUygula` başlığı).
//
// NEDEN `part`: gerekçenin tamamı `sync_engine.dart` başlığında.

part of 'sync_engine.dart';

/// LWW varlıkları için çakışma kuralı uygulanan tipler.
const _conflictTypes = {
  'customer',
  'customer_phone',
  'customer_address',
  'product',
  'order',
  'exempt_number',
  'call_log',
};

/// [SyncEngine]'in ÇEKME yüzeyi — sunucu → yerel.
extension SyncCekme on SyncEngine {
  /// Sunucudaki değişiklikleri çeker ve yerele uygular. İlk çağrı snapshot, sonrası delta.
  /// has_more olduğu sürece sayfalar (maxPages emniyet sınırı).
  ///
  /// DÖNÜŞ: bu çağrıda AYRIŞTIRILAMADIĞI için ATLANAN satır sayısı. Sıfırdan büyükse tur
  /// "başarılı" sayılmamalıdır (bkz. [SyncService]) — kuyruğu açık tutmanın bedeli sessiz veri
  /// kaybı olamaz.
  Future<int> pull({int limit = 500, int maxPages = 100}) async {
    var atlanan = 0;
    for (var page = 0; page < maxPages; page++) {
      final meta = await db.syncState();
      final resp = await api.pull(since: meta.lastPulledSeq, limit: limit);
      await _applyServerTime(resp.serverTime);
      await _applyApiSurumu(resp.apiSurum);
      await _applySubscription(resp.subscription);
      atlanan += await _applyTeam(resp.team);

      atlanan += resp.mode == 'snapshot' ? await _applySnapshot(resp) : await _applyDelta(resp);
      if (!resp.hasMore) break;
    }

    return atlanan;
  }

  Future<int> _applySnapshot(PullResponse resp) async {
    var atlanan = 0;
    await db.transaction(() async {
      for (final entry in resp.entities.entries) {
        for (final row in entry.value) {
          if (!await _guvenliUygula(() => _applyEntity(entry.key, row))) atlanan++;
        }
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        SyncMetaCompanion(lastPulledSeq: Value(resp.cursor), snapshotDone: const Value(true)),
      );
    });

    return atlanan;
  }

  Future<int> _applyDelta(PullResponse resp) async {
    var atlanan = 0;
    await db.transaction(() async {
      for (final change in resp.changes) {
        // Zarfın kendisi de (entity_type/payload) satır bazında korunur: bozuk bir zarf da
        // yalnız kendi satırını düşürmeli.
        final ok = await _guvenliUygula(() async {
          final type = change['entity_type'] as String;
          final payload = (change['payload'] as Map).cast<String, dynamic>();
          await _applyEntity(type, payload,
              checkConflict: true, changeOccurredAt: change['occurred_at'] as String?);
        });
        if (!ok) atlanan++;
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(lastPulledSeq: Value(resp.cursor)));
    });

    return atlanan;
  }

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
              // FAVORİ ÜRÜNLER (v18) — cihazda JSON METİN saklanır. Sunucu bu alanı ya metin
              // ya da gerçek JSON dizi olarak gönderebilir (kolon `text` mi `json` cast'li mi
              // olduğuna göre değişir) ve İKİSİ DE kabul edilir: tek biçim bekleyen bir cast,
              // sunucu tarafı kolonu bir gün `json`a çevirdiğinde satırı TypeError'a düşürür ve
              // sürüm çarpıklığı kapısı o müşteriyi sessizce ATLAR (bkz. _guvenliUygula).
              favoriteProductIds: Value(_jsonMetin(m['favorite_product_ids'])),
              // ÜRÜN TERCİHLERİ (2026-08-18) — haritalanmazsa sunucudaki tercih telefonda
              // HİÇ OLMAMIŞ sayılır ve müşteri her siparişte yeniden sorulur.
              productOptionsJson: Value(_jsonMetin(m['product_options'])),
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
              // SEÇENEK LİSTESİ (2026-08-18) — favori listesiyle AYNI hoşgörü: sunucu metin de
              // gerçek JSON dizi de gönderebilir, ikisi de kabul edilir.
              optionsJson: Value(_jsonMetin(m['options'])),
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
              // SATIR NOTU (v18) — `unit` ile birebir aynı desen: satırda saklanan, o anki gerçek.
              // Eski sunucu alanı hiç göndermezse null kalır (not yoktu, doğru başlangıç).
              note: Value(_sN(m['note'])),
              // SEÇİLEN SEÇENEKLER (2026-08-18). Not metni ekranlarda zaten görünüyor; bu alan
              // YAPILANDIRILMIŞ hâlidir ve "aynı seçimle tekrar sipariş" gibi işler ona bakar.
              // Haritalanmazsa satır başka cihazda seçimsiz görünür ve düzenleme onu SİLERDİ.
              optionsJson: Value(_jsonMetin(m['options'])),
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
              // Çağrıyı karşılayan kullanıcı (2026-08-13). BU SATIR OLMADAN özellik tek
              // cihazlık kalırdı: patron kendi telefonunda atfı görür, kuryenin telefonundan
              // senkronla inen kayıtta göremezdi — oysa özelliğin tamamı başkasının geçmişini
              // görmek üzerine.
              //
              // `_korunan` ŞART, düz `_sN` DEĞİL: alanı bilmeyen bir sunucu (canlı, henüz
              // dağıtılmamış) onu düşürür ve düz okuma cihazdaki DOĞRU atfı null'la ezer.
              // Gerçek cihazda yaşandı, gerekçenin tamamı `_korunan` başlığında.
              userId: _korunan(m, 'user_id'),
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
              iban: Value(_sN(m['iban'])),
              // IBAN alıcı adı + hatırlatma şablonu (v14). Nullable — sunucu alanı hiç
              // göndermezse (eski sürüm) null yazılır ve mesaj kurulumu eski davranışına
              // düşer: alıcı satırına işletme adı, gövdeye varsayılan metin.
              ibanOwnerName: Value(_sN(m['iban_owner_name'])),
              reminderTemplate: Value(_sN(m['reminder_template'])),
              // Kurye yetkileri — sunucu alanı göndermezse (eski sürüm) varsayılana düşülür;
              // NOT NULL kolona `Value(null)` yazmak satırı bozardı (order_code_display dersi).
              courierCanCustomers: Value(_bV(m['courier_can_customers'], true)),
              courierCanOrders: Value(_bV(m['courier_can_orders'], true)),
              courierCanCollect: Value(_bV(m['courier_can_collect'], true)),
              courierCanDiscount: Value(_bV(m['courier_can_discount'], false)),
              courierCanDayEnd: Value(_bV(m['courier_can_day_end'], false)),
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
          // İPTAL İZİ İNMEK ZORUNDA (2026-08-13): patron kendi telefonundan bir ara tahsilatı
          // iptal ederse, kuryenin telefonuna yalnız eksi tutarlı satır iner. Bu alan boş
          // gelseydi o cihaz satırı BAĞIMSIZ bir tahsilat sanar ve listeye "−400,00 ₺ tahsilat"
          // diye basardı; üstelik orijinal hâlâ iptalsiz görünüp toplama girerdi. Alan eski
          // sunucudan hiç gelmezse null kalır — davranış bugünküyle birebir aynı.
          reversesHandoverId: Value(_sN(m['reverses_handover_id'])),
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
          // ⚠️ BU SATIR OLMADAN GERİ ALMA DİĞER TELEFONDA HİÇ OLMAMIŞ SAYILIR (2026-08-18):
          // sunucu satırı doğru yazar, pull da indirir, ama alan haritalanmazsa yerelde `null`
          // kalır — kapanış hâlâ GEÇERLİ görünür ve o cihazda gün kilitli kalmaya devam eder.
          // Patronun telefonunda açılan gün, kuryenin telefonunda kapalı olurdu.
          reversesClosingId: Value(_sN(m['reverses_closing_id'])),
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
}
