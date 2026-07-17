import 'package:uuid/uuid.dart';

/// İstemci kimlik ve saat yardımcıları (offline-first).
///
/// Kimlikler UUIDv7 ve İSTEMCİDE üretilir (DECISIONS): offline oluşan kaydın id'si sunucuya çıkınca
/// değişmez, referanslar kırılmaz, senkron sırası önemsizleşir. UUIDv7 zaman-sıralıdır (index dostu).
const _uuid = Uuid();

String newId() => _uuid.v7();

/// Teslim idempotensi namespace'i (FAZ 4). Bir kez seçilir, mağazada DEĞİŞMEZ — değişirse aynı
/// siparişin iki cihazdaki uuid5'leri ayrışır ve idempotensi kırılır. İstemci+sunucu ortak sabit
/// (sunucunun hesaplaması gerekmez; yalnız gelen client_event_id ile processed_events dedup eder).
const _deliverNamespace = '7a5b3c1d-9e0f-4a2b-8c6d-1f3e5a7b9c0d';

/// Teslimden türeyen olayların DETERMİNİSTİK kimliği (DECISIONS Faz 4). İki cihaz aynı siparişi
/// offline teslim edince AYNI uuid5 üretilir → sunucu processed_events(tenant_id, client_event_id)
/// UNIQUE bunları tekilleştirir → tek delivered olay + tek defter seti + tek kupon hareketi. tag ile
/// aynı teslimin farklı olayları ayrışır: 'order', 'debit', 'payment', 'coupon'.
String deliveryEventId(String orderId, String tag) =>
    _uuid.v5(_deliverNamespace, 'sipario:deliver-$tag:$orderId');

/// Düzeltilmiş sunucu saati (DECISIONS: sunucu her yanıtta saatini döner, istemci offset tutar;
/// occurred_at bu düzeltilmiş saatle yazılır — esnafın telefon saati yanlış olabilir).
String correctedNowIso(int serverOffsetMs) =>
    DateTime.now().toUtc().add(Duration(milliseconds: serverOffsetMs)).toIso8601String();

String nowIso() => DateTime.now().toUtc().toIso8601String();
