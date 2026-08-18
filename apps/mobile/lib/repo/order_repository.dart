import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../data/urun_secenekleri.dart';
import 'ledger_ops.dart';

// AÇIK SİPARİŞ SORGUSU BU DOSYADA DEĞİL: `screens/orders/order_queries.dart`
// (`acikSiparisler` · `watchAcikSiparisler`). Bir ara ikisinde birden tanımlıydı; sipariş formu
// bu iki dosyayı da import eder (biri `LineInput`, diğeri sorgular için) ve ortak ada dokunduğu
// anda "ambiguous import" ile DERLENMEZDİ. Okuma sorguları sorgu katmanında durur — repo yazma
// yolu içindir.

class LineInput {
  LineInput({
    required this.productName,
    required this.unitPriceKurus,
    required this.qty,
    this.productId,
    this.unit,
    this.note,
    this.isCustom = false,
    this.secim = const SecenekSecimi(),
  });
  final String? productId;
  final String productName;
  final int unitPriceKurus;
  final int qty;

  /// Birim ("adet"/"koli"/"kg") satırda saklanır — fiyat/ad ile aynı gerekçe: o anki gerçek.
  /// Opsiyonel; mevcut çağrılar aynen çalışır.
  final String? unit;

  /// SATIR NOTU ("buzlu olsun", "kapıya bırak") — siparişin NOTUYLA karıştırılmamalı: o
  /// siparişin tamamına, bu TEK KALEME aittir. Opsiyonel; mevcut çağrılar aynen çalışır.
  final String? note;

  /// "Serbest satır" (katalogda olmayan tek seferlik iş — tasarım bunları ayrı gösterir).
  /// productId'nin null olması yeterli ayırt edici değildir: silinmiş ürünün satırı da null olur.
  final bool isCustom;

  /// SEÇENEK SEÇİMİ — "soğansız, ekstra peynirli" (kullanıcı isteği 2026-08-18).
  ///
  /// ⚠️ [unitPriceKurus] EK TUTARI **İÇERMEZ**; onu depo ekler ([birimFiyat]). Çağıranın ürünün
  /// katalog fiyatını göndermesi ve ekstraları depo hesabına bırakması bilinçli: fiyat formülü
  /// tek yerde durur, yoksa her çağrı yerinde bir kez daha yazılır ve biri er geç unutulur.
  final SecenekSecimi secim;

  /// Satıra yazılacak BİRİM fiyat: katalog fiyatı + eklenen malzemelerin ek tutarı.
  ///
  /// Ekstra, ADET BAŞINA binmelidir: iki dürümün ikisine de ekstra peynir eklendiyse ücret de
  /// iki kere alınır. Satır toplamı `birim * adet` kimliğini koruduğu için gün sonu, defter ve
  /// teslim hesaplarının hiçbiri değişmez.
  int get birimFiyat => unitPriceKurus + secim.ekTutarKurus;

  /// Satırın notu: kullanıcının yazdığı not + seçim özeti ("Soğansız · + Ekstra peynir").
  ///
  /// İKİSİ BİRLEŞTİRİLİR çünkü ekranların TAMAMI bu tek alanı çiziyor (sipariş detayı, kurye
  /// görünümü, geçmiş). Seçimi ayrı bir alanda bırakıp ekranları tek tek güncellemek, bir
  /// ekranın unutulduğu gün kuryenin "soğansız"ı hiç görmemesi demekti.
  String? get satirNotu {
    final elle = (note ?? '').trim();
    final ozet = secim.ozet();
    if (elle.isEmpty) return ozet.isEmpty ? null : ozet;
    if (ozet.isEmpty) return elle;
    return '$ozet · $elle';
  }
}

/// Sipariş yerel CRUD'u. status/total YERELDE de olaylardan türer (sunucu önbelleğinin aynası).
/// Her mutasyon: order_events'e ekleme + orders/order_lines yazımı + outbox olayı, AYNI transaction.
/// order_event yerel id'si + AYNI client_event_id ile yazılır; sunucudan geri gelen olay bu
/// client_event_id ile "yoksa ekle" mantığında eşlenir (çift kayıt olmaz).
class OrderRepository {
  OrderRepository(this.db);
  final AppDatabase db;

  Future<String> create({String? customerId, String? note, required List<LineInput> lines}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final orderId = newId();
    final clientEventId = newId();

    final linePayloads = <Map<String, Object?>>[];

    await db.transaction(() async {
      await db.into(db.orders).insert(OrdersCompanion.insert(
            id: orderId,
            customerId: Value(customerId),
            note: Value(note),
            occurredAt: at,
            createdDeviceId: Value(device),
          ));

      for (final l in lines) {
        final lineId = newId();
        await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
              id: lineId,
              orderId: orderId,
              productId: Value(l.productId),
              productName: l.productName,
              unitPriceKurus: l.birimFiyat,
              unit: Value(l.unit),
              note: Value(l.satirNotu),
              optionsJson: Value(l.secim.yaz()),
              isCustom: Value(l.isCustom),
              qty: l.qty,
              lineTotalKurus: l.birimFiyat * l.qty,
            ));
        linePayloads.add(_linePayload(lineId, l));
      }

      final payload = {
        'order': {'id': orderId, 'customer_id': customerId, 'note': note},
        'lines': linePayloads,
      };
      await _appendEvent(orderId, 'created', clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'created', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });

    return orderId;
  }

  /// Teslimat parayı deftere düşürür (FAZ 3), teslim olayıyla AYNI transaction'da:
  ///  - debit(+total) HER teslimde yazılır — satış her hâlükârda borç doğurur.
  ///  - payment(−tahsil edilen, ödeme tipiyle) yalnız para alındıysa yazılır.
  ///
  /// KISMİ ÖDEME (2026-07-27, saha eksiği 7): [tahsilKurus] tahsil EDİLEN tutardır. Verilmezse
  /// eski davranış korunur (veresiye → 0, diğerleri → tutarın tamamı). Tahsil sipariş tutarından
  /// AZSA kalan fark AYRI BİR KAYIT DEĞİLDİR — ödenmemiş `debit`in kendisi borçtur ve bakiye zaten
  /// `SUM(amount_kurus)`. FAZLAYSA (müşteri önceki borcunu da kapatıyor) payment olduğu gibi yazılır
  /// ve bakiye eksiye (alacak) düşebilir: kasaya giren para deftere `payment` olarak girmezse gün
  /// sonu kasa özeti yanlış çıkar. Veresiye (tahsil 0) ve peşin (tahsil = total) bu kuralın uç
  /// noktalarıdır — yeni entry_type/olay/migration gerekmedi, append-only (kırmızı çizgi #2) aynen.
  ///
  /// TESLİM İDEMPOTENSİ (FAZ 4, DECISIONS): teslimden türeyen TÜM olayların client_event_id'si (ve
  /// ledger id'leri) sipariş id'sinden DETERMİNİSTİK uuid5 ile üretilir. İki cihaz aynı siparişi
  /// offline teslim edince AYNI id'ler → sunucu processed_events UNIQUE ile tek defter seti bırakır.
  /// Yerel çift-dokunma zaten teslim edilmiş siparişte erken döner (UI koruması; asıl garanti uuid5).
  /// Kısmi ödeme bunu BOZMAZ: id'ler tutardan değil sipariş kimliğinden türüyor.
  ///
  /// collectedByUserId nakit atfıdır (kasa devri); verilmezse oturumdaki kullanıcıdan (syncMeta) alınır.
  ///
  /// [iskontoKurus] KAPIDA KIRILAN tutardır (pozitif kuruş, kullanıcı isteği 2026-07-30: 420 ₺lik
  /// siparişten 400 ₺ alınıp kalan 20 ₺ borç YAZILMAZ). Deftere kendi tipiyle düşer —
  /// `discount(−iskonto)`, `payment_type` TAŞIMAZ:
  ///  • bakiye: iskonto borcu kapatır, müşteri borçlu GÖRÜNMEZ (bakiye = SUM(amount_kurus)),
  ///  • kasa: `payment_type` taşımadığı için `kasaOzeti` onu SAYMAZ — sayılan nakit 400 ₺ kalır.
  /// İkisini tek `payment` satırında toplamak (420 tahsil edilmiş gibi yazmak) kasayı her
  /// iskontoda şişirir ve gün sonu farkını KANIT olmaktan çıkarıp gürültüye çevirirdi.
  ///
  /// ÜST SINIR kalan borçtur (`total − alınan`): daha fazlası bakiyeyi eksiye çevirir, yani
  /// "kırdım" derken müşteriyi alacaklı yapardı. Alt sınır 0.
  Future<void> deliver(String orderId,
      {required String paymentType,
      int? tahsilKurus,
      int iskontoKurus = 0,
      String? collectedByUserId}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final collector = collectedByUserId ?? meta.userId;

    final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    if (order.status == 'delivered') return; // çift-dokunma koruması (yerel no-op)

    // Deterministik client_event_id / id'ler — iki cihazda AYNI (idempotensi inşa gereği).
    final deliverEventId = deliveryEventId(orderId, 'order');

    await db.transaction(() async {
      // 1) Teslim olayı + ödeme tipi + önbellek + outbox (mevcut sipariş akışı).
      await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
          .write(OrdersCompanion(paymentType: Value(paymentType)));
      final payload = {'order_id': orderId, 'payment_type': paymentType};
      await _appendEvent(orderId, 'delivered', deliverEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'delivered', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: deliverEventId, payload: payload);

      // 2) Para deftere düşer. total recompute sonrası aktif satır toplamıdır.
      final lines = await _activeLines(orderId);
      final total = lines.fold<int>(0, (s, l) => s + l.lineTotalKurus);
      final customerId = order.customerId;

      // Tahsil edilen. Çağıran söylemediyse eski kural: veresiye 0, diğerleri tutarın tamamı.
      // ÜST SINIR YOK — sipariş tutarını aşan tahsilat meşrudur (müşteri önceki borcunu da
      // kapatıyor). Alt sınır 0: negatif "tahsilat" diye bir şey yok, veresiye de tanımı gereği
      // sıfır tahsilattır (aksi hâlde payment_type='veresiye' taşıyan bir ödeme satırı üretir ve
      // sunucu onu haklı olarak reddeder — kasa yalnız nakit|kart|havale tanır).
      final istenen = tahsilKurus ?? (paymentType == 'veresiye' ? 0 : total);
      final alinan = (paymentType == 'veresiye' || istenen < 0) ? 0 : istenen;

      // Satışın borcu: her teslimde, TAM tutarla.
      await writeLedgerEntry(db, entryType: 'debit', amountKurus: total,
          id: deliveryEventId(orderId, 'debit'), clientEventId: deliveryEventId(orderId, 'debit'),
          customerId: customerId, relatedOrderId: orderId, occurredAt: at, deviceId: device);

      // Alınan para: yalnız gerçekten alındıysa. 0 tahsilatlı bir `payment` satırı kasayı
      // kirletir ve defterde anlamı olmayan bir hareket bırakır.
      if (alinan > 0) {
        await writeLedgerEntry(db, entryType: 'payment', amountKurus: -alinan, paymentType: paymentType,
            id: deliveryEventId(orderId, 'payment'), clientEventId: deliveryEventId(orderId, 'payment'),
            collectedByUserId: collector,
            customerId: customerId, relatedOrderId: orderId, occurredAt: at, deviceId: device);
      }

      // Kırılan tutar. `collected_by_user_id` iskontoyu KİMİN verdiği olarak yazılır (kasa devri
      // yalnız payment_type='nakit' satırlarını topladığı için beklenen nakit ETKİLENMEZ) —
      // patron gün detayında hangi kuryenin ne kadar kırdığını görebilsin.
      final kalanBorc = total - alinan;
      var iskonto = iskontoKurus < 0 ? 0 : iskontoKurus;
      if (iskonto > kalanBorc) iskonto = kalanBorc;
      if (iskonto > 0) {
        await writeLedgerEntry(db, entryType: 'discount', amountKurus: -iskonto,
            id: deliveryEventId(orderId, 'discount'),
            clientEventId: deliveryEventId(orderId, 'discount'),
            collectedByUserId: collector,
            customerId: customerId, relatedOrderId: orderId, occurredAt: at, deviceId: device);
      }
    });
  }

  /// Siparişi bir kuryeye ata (FAZ 4, olay-kaynaklı). assigned order olayı + orders.assignedUserId
  /// önbelleği + outbox, tek transaction (_statusEvent deseni). Tek kişilik bayide UI'da hiç çağrılmaz.
  Future<void> assign(String orderId, String userId) =>
      _statusEvent(orderId, 'assigned', {'order_id': orderId, 'assigned_user_id': userId},
          assignedUserId: userId, setAssignedFlag: true);

  /// Atamayı geri al (FAZ 4). unassigned olayı + orders.assignedUserId = null.
  Future<void> unassign(String orderId) =>
      _statusEvent(orderId, 'unassigned', {'order_id': orderId},
          assignedUserId: null, setAssignedFlag: true);

  Future<void> cancel(String orderId) =>
      _statusEvent(orderId, 'cancelled', {'order_id': orderId});

  Future<void> setPayment(String orderId, String paymentType) =>
      _statusEvent(orderId, 'payment_set', {'order_id': orderId, 'payment_type': paymentType}, paymentType: paymentType);

  Future<void> setNote(String orderId, String? note) =>
      _statusEvent(orderId, 'note_set', {'order_id': orderId, 'note': note}, note: note, setNoteFlag: true);

  Future<String> addLine(String orderId, LineInput l) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final clientEventId = newId();
    final lineId = newId();

    await db.transaction(() async {
      await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
            id: lineId,
            orderId: orderId,
            productId: Value(l.productId),
            productName: l.productName,
            unitPriceKurus: l.birimFiyat,
            unit: Value(l.unit),
            note: Value(l.satirNotu),
            optionsJson: Value(l.secim.yaz()),
            isCustom: Value(l.isCustom),
            qty: l.qty,
            lineTotalKurus: l.birimFiyat * l.qty,
          ));
      final payload = {'order_id': orderId, 'line': _linePayload(lineId, l)};
      await _appendEvent(orderId, 'line_added', clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'line_added', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });

    return lineId;
  }

  Future<void> removeLine(String orderId, String lineId) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final clientEventId = newId();

    await db.transaction(() async {
      await (db.update(db.orderLines)..where((t) => t.id.equals(lineId)))
          .write(OrderLinesCompanion(deletedAt: Value(at)));
      final payload = {'order_id': orderId, 'line_id': lineId};
      await _appendEvent(orderId, 'line_removed', clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'line_removed', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });
  }

  Future<void> _statusEvent(
    String orderId,
    String op,
    Map<String, Object?> payload, {
    String? paymentType,
    String? note,
    bool setNoteFlag = false,
    String? assignedUserId,
    bool setAssignedFlag = false,
    int? sortIndex,
    bool setSortFlag = false,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final clientEventId = newId();

    await db.transaction(() async {
      if (paymentType != null) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(paymentType: Value(paymentType)));
      }
      if (setNoteFlag) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(note: Value(note)));
      }
      if (setAssignedFlag) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(assignedUserId: Value(assignedUserId)));
      }
      if (setSortFlag) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(sortIndex: Value(sortIndex)));
      }
      await _appendEvent(orderId, op, clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: op, entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });
  }

  /// Elle sıralama (tasarım: sürükle-bırak rota sırası). ÖNBELLEK sütunu; kaynağı `sort_set`
  /// olayıdır (assigned deseninin ikizi) — böylece iki cihaz aynı olaylardan aynı sırayı türetir.
  Future<void> setSortIndex(String orderId, int sortIndex) =>
      _statusEvent(orderId, 'sort_set', {'order_id': orderId, 'sort_index': sortIndex},
          sortIndex: sortIndex, setSortFlag: true);

  /// Sipariş satırı payload'ının TEK üretim noktası (`created` ve `line_added` aynı şekli
  /// gönderir). Alan eklemeyi burada unutmak, satırın o alanını sunucuya HİÇ göndermemek
  /// demektir — `note` v18'de tam olarak bu yüzden buraya, satır nesnesinin İÇİNE konur
  /// (siparişin kök `note` alanı ayrı bir şeydir ve karıştırılırsa kurye yanlış ürünü teslim eder).
  static Map<String, Object?> _linePayload(String lineId, LineInput l) => {
        'id': lineId,
        'product_id': l.productId,
        'product_name': l.productName,
        // ⚠️ YEREL SATIRLA AYNI DEĞER GİTMELİ: `birimFiyat` ekstraları içerir. `unitPriceKurus`
        // gönderilirse sunucudaki toplam ekstra kadar EKSİK çıkar ve iki taraf sessizce ayrışır
        // (satır toplamı zaten `unit_price * qty`den türetiliyor).
        'unit_price_kurus': l.birimFiyat,
        'unit': l.unit,
        'note': l.satirNotu,
        'is_custom': l.isCustom,
        'qty': l.qty,
        // Yapılandırılmış seçim: JSON NESNE olarak gider (metin değil) — ürün seçenekleriyle
        // aynı gerekçe. Seçim yoksa anahtar null gider ve sunucu kolonu boş bırakır.
        'options': l.secim.bos ? null : l.secim.toJson(),
      };

  Future<void> _appendEvent(
    String orderId,
    String type,
    String clientEventId,
    Map<String, Object?> payload,
    String at,
    String? device,
  ) {
    return db.into(db.orderEvents).insert(OrderEventsCompanion.insert(
          id: newId(),
          orderId: orderId,
          eventType: type,
          payload: Value(jsonEncode(payload)),
          clientEventId: clientEventId,
          occurredAt: at,
          deviceId: Value(device),
        ));
  }

  /// Silinmemiş sipariş satırları (total buradan türer).
  Future<List<OrderLine>> _activeLines(String orderId) =>
      (db.select(db.orderLines)..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull())).get();

  /// status/total/assignedUserId'i olaylardan + aktif satırlardan türet (sunucu recompute'unun aynası).
  Future<void> _recompute(String orderId) async {
    final events = await (db.select(db.orderEvents)..where((t) => t.orderId.equals(orderId))).get();
    final hasCancelled = events.any((e) => e.eventType == 'cancelled');
    final hasDelivered = events.any((e) => e.eventType == 'delivered');
    final status = hasCancelled ? 'cancelled' : (hasDelivered ? 'delivered' : 'open');

    final lines = await _activeLines(orderId);
    final total = lines.fold<int>(0, (s, l) => s + l.lineTotalKurus);

    await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(OrdersCompanion(
      status: Value(status),
      totalKurus: Value(total),
      assignedUserId: Value(_deriveAssignedUserId(events)),
      sortIndex: Value(_deriveSortIndex(events)),
    ));
  }

  /// sort_index önbelleğini en son `sort_set` olayından türet (SUNUCU deriveSortIndex'inin aynası;
  /// aynı (occurredAt, id) ORTAK anahtarı → iki taraf aynı sırayı bulur, ıraksama yok).
  int? _deriveSortIndex(List<OrderEvent> events) {
    final sortEvents = events.where((e) => e.eventType == 'sort_set').toList()
      ..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    if (sortEvents.isEmpty) return null;
    final payload = sortEvents.last.payload;
    if (payload == null) return null;
    final value = (jsonDecode(payload) as Map<String, dynamic>)['sort_index'];
    return value is num ? value.toInt() : null;
  }

  /// assigned_user_id önbelleğini en son assigned/unassigned olayından türet (SUNUCU deseninin aynası,
  /// deriveAssignedUserId). Sıra (occurredAt, id) ASC → sonuncu = en son. id (uuid7) SON tiebreak:
  /// occurred_at eşit kalınca (aynı an) TAM determinizm sağlar; sunucuyla BİREBİR aynı zincir (yoksa
  /// türetme diverge eder). Kendi olaylarımızın id'si uuid7 olduğundan nedensel sırayı korur.
  String? _deriveAssignedUserId(List<OrderEvent> events) {
    final assignEvents = events
        .where((e) => e.eventType == 'assigned' || e.eventType == 'unassigned')
        .toList()
      ..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    if (assignEvents.isEmpty) return null;
    final last = assignEvents.last;
    if (last.eventType != 'assigned' || last.payload == null) return null;
    return (jsonDecode(last.payload!) as Map<String, dynamic>)['assigned_user_id'] as String?;
  }
}
