import 'dart:math';

import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

/// İstemci kimlik ve saat yardımcıları (offline-first).
///
/// Kimlikler UUIDv7 ve İSTEMCİDE üretilir (DECISIONS): offline oluşan kaydın id'si sunucuya çıkınca
/// değişmez, referanslar kırılmaz, senkron sırası önemsizleşir. UUIDv7 zaman-sıralıdır (index dostu).
const _uuid = Uuid();

/// Aynı milisaniye içinde üretilen id'leri sıralayan sayaç (RFC 9562 §6.2 "monotonic random",
/// yöntem 3) — 12 bitlik `rand_a` alanına yazılır.
///
/// NEDEN VAR (2026-07-27, ölçüldü): `uuid` 4.5.3'ün `v7`si zaman damgasından sonraki 74 bitin
/// TAMAMINI rastgele dolduruyor; aynı milisaniyede üretilen iki id'nin sırası **yazı-tura**
/// (20.000 çiftte %50,5 ters). Oysa depo "UUIDv7 zaman-sıralıdır" varsayımına dayanıyor:
/// `order_lines` tek transaction'da döngüyle üretiliyor ve kart dökümü `ORDER BY id ASC` ile
/// yazılıyordu — aynı siparişin kalemleri rastgele sırada çıkabiliyordu.
///
/// SINIR — MONOTONLUK TEK İZOLAT İÇİNDE GEÇERLİDİR, cihazlar arasında DEĞİL. Bu yeterli, çünkü
/// bir kaydın parçaları (siparişin kalemleri, teslimin defter satırları) TEK cihazda, tek
/// transaction'da üretilir; senkron id'leri olduğu gibi taşır, yani kaynakta sıra doğruysa her
/// cihazda aynı görünür. Sonraki vardiya bunu "iki cihaz arası monotonluk" sanmasın: iki cihazın
/// aynı milisaniyede ürettiği id'lerin birbirine göre sırası hâlâ rastgeledir ve olmak zorunda
/// değildir (çakışmayı önleyen şey kalan 62 rastgele bittir).
int _sonMs = 0;
int _sayac = 0;

/// `rand_a` 12 bit → milisaniye başına 4096 id. Dolarsa bir sonraki milisaniyeden ödünç alınır.
const int _sayacTavani = 0xFFF;

/// Rastgelelik kaynağı paketin varsayılanıyla aynı sınıfta: kriptografik. Id'ler sır değil ama
/// çakışma direnci iki cihazın offline aynı anda kayıt açmasına dayanmak zorunda.
final Random _rastgele = Random.secure();

/// Zaman-sıralı UUIDv7. Aynı milisaniye içinde ARTAN, yani `ORDER BY id` eklenme sırasını verir.
///
/// Sistem saati geri alınırsa id'ler geri gitmez: [_sonMs] asla küçülmez, sayaç ilerlemeye devam
/// eder. Sayaç her yeni milisaniyede 0'dan başlar (rastgele tohum yerine) — böylece ms başına tam
/// 4096 id kapasitesi kalır; kalan 62 bit zaten rastgele olduğundan tahmin edilebilirlik sorunu
/// doğmaz.
String newId() {
  final sonraki = sonrakiSayacDurumu(
    DateTime.now().toUtc().millisecondsSinceEpoch,
    _sonMs,
    _sayac,
  );
  _sonMs = sonraki.ms;
  _sayac = sonraki.sayac;

  // Paket `randomBytes`in ilk 10 baytını 6..15'e kopyalar, sonra 6'nın üst yarısını sürüm (7),
  // 8'in üst bitlerini varyant yapar. Sayaç bu yüzden bayt 0'ın ALT nibble'ı + bayt 1'dir:
  // metinde sürüm nibble'ının hemen ardından gelir, sıralamayı o belirler.
  final bayt = List<int>.generate(10, (_) => _rastgele.nextInt(256));
  bayt[0] = (_sayac >> 8) & 0x0F;
  bayt[1] = _sayac & 0xFF;
  return _uuid.v7(config: V7Options(_sonMs, bayt));
}

/// Sayaç durum geçişi — SAF fonksiyon, [newId]'nin tek karar noktası.
///
/// Dışarı açık olmasının tek sebebi TEST: taşma dalı (bir milisaniyede 4096'dan fazla id) ve
/// geri alınmış sistem saati dalı, gerçek zamanla tetiklenemez — ölçtüm, yoğun bir döngüde bile
/// milisaniye başına ~1000 id üretiliyor. Denenmemiş dal, olmayan daldır.
({int ms, int sayac}) sonrakiSayacDurumu(int simdi, int sonMs, int sayac) {
  if (simdi > sonMs) return (ms: simdi, sayac: 0);
  // Aynı milisaniye — ya da geri alınmış sistem saati; ikisinde de sıra sayaçla korunur ve
  // `ms` ASLA küçülmez, yani id'ler geriye gitmez.
  if (sayac < _sayacTavani) return (ms: sonMs, sayac: sayac + 1);
  // Sayaç doldu: sıradaki milisaniyeden ödünç al. Duvar saati yetişince kendiliğinden düzelir.
  return (ms: sonMs + 1, sayac: 0);
}

/// Teslim idempotensi namespace'i (FAZ 4). Bir kez seçilir, mağazada DEĞİŞMEZ — değişirse aynı
/// siparişin iki cihazdaki uuid5'leri ayrışır ve idempotensi kırılır. İstemci+sunucu ortak sabit
/// (sunucunun hesaplaması gerekmez; yalnız gelen client_event_id ile processed_events dedup eder).
const _deliverNamespace = '7a5b3c1d-9e0f-4a2b-8c6d-1f3e5a7b9c0d';

/// Teslimden türeyen olayların DETERMİNİSTİK kimliği (DECISIONS Faz 4). İki cihaz aynı siparişi
/// offline teslim edince AYNI uuid5 üretilir → sunucu processed_events(tenant_id, client_event_id)
/// UNIQUE bunları tekilleştirir → tek delivered olay + tek defter seti. tag ile aynı teslimin
/// farklı olayları ayrışır: 'order', 'debit', 'payment'.
String deliveryEventId(String orderId, String tag) =>
    _uuid.v5(_deliverNamespace, 'sipario:deliver-$tag:$orderId');

/// Gün sonu KAPANIŞI idempotens namespace'i. Bir kez seçilir, mağazada DEĞİŞMEZ — değişirse aynı
/// kapanışın iki cihazdaki uuid5'leri ayrışır ve idempotensi kırılır.
const _kapanisNamespace = 'b4c17e28-6d3f-4a91-8e52-0c7d9f1a3b6e';

/// Kapanış olaylarının DETERMİNİSTİK kimliği (üçüncü inceleme ①-b).
///
/// `kapaliMi` kapısı TEK CİHAZI kapatır. İki cihaz birbirinden habersiz aynı kurye/günü kapatırsa
/// ikisi de yerelde geçer ve İKİ `day_closings` + İKİ `cash_handovers` doğardı;
/// `teslimEdilenNakit` ikisini birden sayınca gün beklentisi iki katına çıkar ve patron olmayan
/// bir eksiği arar. Aynı çekirdek aynı id'yi verdiği için ikinci kayıt her katmanda AYNI satırdır:
/// sunucu 'duplicate' döner (mobilde `acked`), yerel senkron uygulayıcısı da "yoksa ekle, asla
/// ezme" kuralıyla atlar.
///
/// ⚠️ BİLİNÇLİ BEDEL: ikinci denemenin SAYILAN tutarı hiçbir yere geçmez — İLK mutabakat kalır.
/// Sonraki vardiya "ikinci sayım neden kayboldu" diye aramasın: kayboldu değil, REDDEDİLDİ.
/// Sayımı düzeltmenin yolu append-only kuralının kendisidir (yeni bir devir kaydı).
///
/// [tenantCode] ÇEKİRDEĞE ZORUNLU GİRER: sunucuda `day_closings.id` ve `cash_handovers.id`
/// PRIMARY KEY'dir ve tenant'a göre değil GLOBAL tekildir. Kiracı ayracı olmadan `scope='day'`
/// çekirdeği (`day|-|2026-08-06`) TÜM bayilerde aynı uuid'yi üretirdi ve ikinci bayinin kapanışı
/// 'duplicate' sayılıp SESSİZCE düşerdi. (Kurye kapsamında `userId` zaten global tekil bir uuid,
/// ama kuralı kapsama göre ikiye bölmüyoruz.)
///
/// [userId] null ise (gün kapsamı) çekirdeğe `-` girer; `scope` de çekirdekte olduğu için gün ve
/// kurye kapsamları zaten çakışamaz, yer tutucu yalnız çekirdeği okunur kılar.
///
/// [tag] aynı kapanıştan doğan farklı kayıtları ayırır: 'closing' (arşiv satırı), 'handover'
/// (kapanışa bağlı kasa devri). ARA TAHSİLATLAR BURAYA GİRMEZ — bkz. `CashHandoverRepository`.
String kapanisOlayId({
  required String tenantCode,
  required String scope,
  required String? userId,
  required String gunAnahtari,
  required String tag,
}) =>
    _uuid.v5(_kapanisNamespace,
        'sipario:closing-$tag:$tenantCode|$scope|${userId ?? '-'}|$gunAnahtari');

/// Düzeltilmiş sunucu saati (DECISIONS: sunucu her yanıtta saatini döner, istemci offset tutar;
/// occurred_at bu düzeltilmiş saatle yazılır — esnafın telefon saati yanlış olabilir).
String correctedNowIso(int serverOffsetMs) =>
    DateTime.now().toUtc().add(Duration(milliseconds: serverOffsetMs)).toIso8601String();

String nowIso() => DateTime.now().toUtc().toIso8601String();
