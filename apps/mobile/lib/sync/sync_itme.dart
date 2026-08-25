// PUSH TURU — giden kutusunu sunucuya iter.
//
// Buradaki her satır TEK bir soruya hizmet eder: "sunucu bu olayı ne yaptı ve outbox satırının
// kaderi ne olmalı?" Kararın üç ucu var ve üçü de bu dosyada durur:
//   • BEYAZ LİSTE ([_kararVer]) — bilinen sunucu durumları tek tek eşlenir, tanınmayan beklet.
//   • İKİLİ ARAMA ([SyncItme._partiGonder]) — parti kalıcı 4xx yerse suçlu daraltılır.
//   • KARANTİNA EŞİĞİ ([SyncEngine.karantinaEsigi]) — tek olay üst üste reddedilirse kuyruğu
//     kilitlemesin diye `rejected` olur; SİLİNMEZ.
//
// ⚠️ ÇEKME TURUYLA ORTAK HİÇBİR KARAR YOKTUR ve olmamalıdır: pull yönünün kaybı SATIRA
// hapsedilir (`_guvenliUygula`), push yönünün kaybı OLAYA. İki politikayı tek yere toplamak,
// birini diğerinin gerekçesiyle gevşetmenin kapısını açardı.
//
// NEDEN `part`: gerekçenin tamamı `sync_engine.dart` başlığında.

part of 'sync_engine.dart';

/// Bir push turunun özeti. Düz `int` YETMİYORDU: turun dürüst olabilmesi için servisin
/// "sunucu bir şeyi KALICI olarak reddetti mi" sorusunu da sorabilmesi gerekiyor — yoksa parti
/// reddedilen bir tur, kuyruk kilitlenmiş olmasına rağmen "başarılı" görünür.
class PushOzeti {
  const PushOzeti({
    this.gonderildi = 0,
    this.karantina = 0,
    this.beklemede = 0,
    this.kaliciRed = false,
  });

  /// Sunucunun NİHAİ karar verdiği olay sayısı (acked ya da rejected işaretlenenler).
  final int gonderildi;

  /// BU TURDA karantinaya alınan olay sayısı. Karantina SİLME DEĞİLDİR: kayıt outbox'ta
  /// `rejected` olarak durur, veri kaybı yoktur (BRIEF kırmızı çizgi #3).
  final int karantina;

  /// Sunucunun BİLEREK uygulamadığı ve `pending` bırakılan olay sayısı (`locked` ve bilinmeyen
  /// durumlar). Kaybolmadılar, SIRADALAR — abonelik yenilenince/istemci güncellenince akarlar.
  final int beklemede;

  /// Parti ya da olay düzeyinde KALICI red görüldü mü? Bant bunu `veri` cinsiyle anlatır;
  /// "çevrimdışı" demek yalan olurdu — sunucuya ULAŞILDI. `locked` BURAYA GİRMEZ: o bir red
  /// değil, ertelemedir.
  final bool kaliciRed;
}

/// Sunucu durum dizesinin outbox'taki karşılığı. BEYAZ LİSTE: bilinen durumlar tek tek eşlenir,
/// tanınmayan her şey `beklet`e düşer.
///
/// NEDEN BEYAZ LİSTE: eski kod "`rejected` değilse `acked`" diyordu ve sunucunun sonradan
/// eklediği `locked` sessizce ACKED olup outbox'tan düşüyordu — abonelik kilitliyken yazılan
/// sipariş/tahsilat, abonelik yenilense bile bir daha ASLA gönderilmiyordu. Kara liste mantığı
/// her yeni sunucu durumunda aynı veri kaybını üretir; beyaz liste en kötü ihtimalle bir kaydı
/// fazladan tekrar gönderir (idempotency zaten `client_event_id`de).
enum _Karar { onayla, karantina, beklet }

/// Tek push turunun değişen durumu (bütçe + sayaçlar). İkili arama özyinelemeli olduğu için
/// sayaçların çağrılar arasında taşınması gerekiyor; alan olarak `SyncEngine`e koymak servisi
/// turlar arası sızdırırdı.
class _PushTuru {
  _PushTuru(this._butce);
  int _butce;
  int gonderildi = 0;
  int karantina = 0;
  int beklemede = 0;
  bool kaliciRed = false;

  /// Bölme bütçesinden bir istek düşer; bütçe bittiyse false (kalan olaylar PENDING kalır).
  bool istekAl() => _butce-- > 0;
}

/// İKİLİ ARAMA BÜTÇESİ: parti reddedilince bir turda atılacak azami EK istek. 500 olayda tek
/// suçluyu daraltmak ~2·log2(500) ≈ 18 istek eder; 24 buna yer bırakır ama zayıf şebekede
/// turu saatlerce sürdürmez. Bütçe biterse kalan olaylar PENDING kalır (kayıp yok) ve sonraki
/// tur kaldığı yerden devam eder.
///
/// ⚠️ BÖLME YALNIZ KALICI 4xx'TE: zaman aşımı ve 5xx'te bölmek, ulaşılamayan bir sunucuya
/// log₂n kat daha fazla istek atmak — kararsız şebekede istek fırtınası — olurdu. O hatalar
/// `_partiGonder`de `rethrow` edilir ve tur düşer; kayıtlar sırada bekler
/// (`sync_zaman_asimi_test.dart` bu ayrımı iki yönlü kilitler).
const int _bolmeButcesi = 24;

/// Sunucu durumunu outbox kararına çevirir — BEYAZ LİSTE (bkz. [_Karar]).
_Karar _kararVer(String status) => switch (status) {
      // Sunucu olayı NİHAİ olarak sonuçlandırdı; tekrar göndermenin anlamı yok.
      'applied' || 'noop' || 'duplicate' || 'stale' => _Karar.onayla,

      // Olay içeriği kalıcı olarak geri çevrildi — elle inceleme (kayıt SİLİNMEZ).
      'rejected' => _Karar.karantina,

      // ⚠️ `locked`: abonelik kilitliyken sunucu olayı BİLEREK uygulamıyor — `processed_events`e
      // yazmıyor, seq ilerletmiyor; "abonelik yenilenince aynı olay retry'da uygulanabilir"
      // diye tasarlanmış. Bunu `acked` saymak (eski davranış) o retry'ı ASLA gerçekleştirmiyor
      // ve kilitliyken yazılan sipariş/tahsilat sessizce yok oluyordu — BRIEF kırmızı çizgi #3
      // ("hiçbir kayıt kaybolmaz") ve #5 ("veri rehin alınmaz, kilitlense bile silinmez")
      // birlikte ihlal ediliyordu.
      'locked' => _Karar.beklet,

      // BİLİNMEYEN DURUM → beklet. Sunucu yarın yeni bir durum eklerse eski istemci onu
      // sessizce silmemeli; en kötü ihtimalle bir kayıt fazladan gönderilir (idempotency
      // `client_event_id`de zaten var). Bugünkü arızanın kök deseni tam olarak buydu.
      _ => _Karar.beklet,
    };

/// `last_error`a yazılacak metin: İNSAN mesajı önce (destek onu okuyacak, KVKK-güvenli),
/// makine kodu parantez içinde (triyaj/aramada lazım).
String? _sebepMetni(EventResult res) {
  final mesaj = res.message;
  final kod = res.reason;
  if (mesaj != null && kod != null) return '$mesaj ($kod)';
  return mesaj ?? kod;
}

/// Sunucu gövdesinin saklanan kısmı. KIRPILIR: bir doğrulama hatası bütün payload'ı geri
/// yankılayabilir ve outbox satırını şişirir; teşhis için ilk satır zaten yeter.
String _kisaGovde(String body) {
  final tek = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return tek.length <= 200 ? tek : '${tek.substring(0, 200)}…';
}

/// [SyncEngine]'in İTME yüzeyi — outbox → sunucu.
extension SyncItme on SyncEngine {
  /// Bekleyen outbox olaylarını gönderir.
  ///
  /// applied/duplicate/stale/noop → acked (retry durur). rejected → karantina (elle inceleme).
  /// locked ve BİLİNMEYEN durumlar → pending KALIR (bkz. [_kararVer]) — silinmez, sıradadır.
  ///
  /// PARTİ DÜZEYİNDE KALICI 4xx (sunucu bize ULAŞTI ve "bunu kabul etmiyorum" dedi) artık turu
  /// düşürmez: parti İKİYE BÖLÜNEREK suçlu daraltılır. Kabul edilen yarı aynı turda akar — tek
  /// bozuk olay bütün kuyruğu rehin alamaz. Suçlu tek olaya inince deneme sayısı artar ve
  /// [SyncEngine.karantinaEsigi]'nde kayıt `rejected` olur; SİLİNMEZ.
  ///
  /// NEDEN İKİLİ ARAMA (tek tek gönderme ya da "hepsini karantinaya al" değil): tek tek göndermek
  /// 500 olayda 500 istek eder ve zayıf şebekede tur hiç bitmez; partiyi toptan karantinaya almak
  /// ise 499 masum kaydı cezalandırırdı. Bölme, suçluyu ~log₂n istekte bulur ve masum olayları
  /// AYNI turda teslim eder. Ek bir armağanı da var: hata "parti çok büyük" cinsindense bölme
  /// onu kendiliğinden çözer.
  ///
  /// [batchSize] SUNUCU TAVANINDAN KÜÇÜKTÜR, bilerek: `SyncService::MAX_EVENTS` 500'dür ve bu
  /// değer eskiden de 500'dü — yani SIFIR PAY vardı. Tam sınırda çalışan bir sözleşmede tek
  /// olaylık bir sapma (ileride eklenecek bir sentetik olay, ya da sunucunun tavanı düşürmesi)
  /// HER push'u kalıcı 422 yapardı; istemcinin bölmesi kuyruğu kurtarır ama her tur boşa giderdi.
  /// 400 o payı açar; bağı `SurumCarpikligiTest` makineyle zorlar.
  Future<PushOzeti> pushPending({int batchSize = 400}) async {
    final pending = await (db.select(db.outbox)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(batchSize))
        .get();
    if (pending.isEmpty) return const PushOzeti();

    final tur = _PushTuru(_bolmeButcesi);
    await _partiGonder(pending, tur);
    return PushOzeti(
      gonderildi: tur.gonderildi,
      karantina: tur.karantina,
      beklemede: tur.beklemede,
      kaliciRed: tur.kaliciRed,
    );
  }

  /// [rows] partisini gönderir; parti KALICI 4xx alırsa ikiye bölerek suçluyu daraltır.
  Future<void> _partiGonder(List<OutboxData> rows, _PushTuru tur) async {
    if (rows.isEmpty) return;

    final PushResponse resp;
    try {
      resp = await api.push([for (final r in rows) _olay(r)]);
    } on SyncApiException catch (e) {
      // GEÇİCİ (5xx/408/425/429) ve OTURUM (401/403) hataları KARANTİNAYA ALINMAZ: sunucu
      // "bu kayıt bozuk" demiyor, "şu an olmaz" ya da "seni tanımıyorum" diyor. Yukarı fırlar →
      // tur düşer, bant gerçeği söyler, sonraki tur AYNI partiyi yeniden dener.
      if (!e.kaliciRed) rethrow;
      tur.kaliciRed = true;

      if (rows.length == 1) {
        await _redDenemesiIsle(rows.single, e, tur);
        return;
      }
      final orta = rows.length ~/ 2;
      if (tur.istekAl()) await _partiGonder(rows.sublist(0, orta), tur);
      if (tur.istekAl()) await _partiGonder(rows.sublist(orta), tur);
      return;
    }

    await _applyServerTime(resp.serverTime);
    await _applyApiSurumu(resp.apiSurum);
    await _applySubscription(resp.subscription);
    // Atlanan ekip elemanı burada SAYILMAZ: push özeti gönderilen OLAYLARIN kaderini anlatır,
    // yanına iliştirilen önbellek bloğunun değil. Aynı liste pull turunda da iner ve orada sayılır.
    await _applyTeam(resp.team);
    await _sonuclariIsle(rows, resp, tur);
  }

  /// Outbox satırını sunucunun beklediği olay zarfına çevirir.
  Map<String, Object?> _olay(OutboxData r) => <String, Object?>{
        'client_event_id': r.clientEventId,
        'entity_type': r.entityType,
        'op': r.op,
        'occurred_at': r.occurredAt,
        'device_id': r.deviceId,
        'payload': jsonDecode(r.payload),
      };

  /// Sunucunun per-olay sonuçlarını outbox'a işler (parti 200 geçti).
  ///
  /// EŞLEME: birincil anahtar `client_event_id`. O bozuk/eksik gelirse (`missing_client_event_id`
  /// / `invalid_client_event_id` sunucunun red kodları arasında) `index` devreye girer — sonuçlar
  /// gönderdiğimiz olaylarla birebir ve aynı sıradadır. İkisi de tutmazsa satıra DOKUNULMAZ ve
  /// `pending` kalır (sonraki tur yeniden dener) — asla "herhâlde gitmiştir" varsayılmaz.
  Future<void> _sonuclariIsle(List<OutboxData> rows, PushResponse resp, _PushTuru tur) async {
    final byId = <String, EventResult>{};
    final byIndex = <int, EventResult>{};
    for (final res in resp.results) {
      final cid = res.clientEventId;
      if (cid != null) byId[cid] = res;
      final i = res.index;
      if (i != null) byIndex[i] = res;
    }

    var onaylanan = 0;
    var reddedilen = 0;
    var bekleyen = 0;

    await db.transaction(() async {
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final res = byId[row.clientEventId] ?? byIndex[i];
        if (res == null) continue; // sunucu yanıtlamadıysa pending kalsın (sonraki retry)

        final karar = _kararVer(res.status);
        if (karar == _Karar.beklet) {
          bekleyen++;
          // KAYIT PENDING KALIR ve `attempts` ARTMAZ — geçici/oturum hatalarındaki kuralın
          // aynısı: bu bir başarısızlık değil, ertelemedir. Karantina eşiğine yaklaştırmak,
          // uzun süre kilitli kalan bir bayinin kayıtlarını sonunda karantinaya sürüklerdi.
          // Sebep yine de yazılır: destek "neden bekliyor" sorusunu cihazdan yanıtlayabilsin.
          await (db.update(db.outbox)..where((t) => t.id.equals(row.id)))
              .write(OutboxCompanion(lastError: Value(_sebepMetni(res))));
          continue;
        }

        final red = karar == _Karar.karantina;
        red ? reddedilen++ : onaylanan++;
        await (db.update(db.outbox)..where((t) => t.id.equals(row.id))).write(
          OutboxCompanion(
            status: Value(red ? 'rejected' : 'acked'),
            attempts: Value(row.attempts + 1),
            lastError: Value(red ? (_sebepMetni(res) ?? 'sunucu reddetti') : null),
          ),
        );
      }
    });

    tur.gonderildi += onaylanan + reddedilen;
    tur.karantina += reddedilen;
    tur.beklemede += bekleyen;
    // Per-olay red de KALICI reddir: bant bunu "çevrimdışı" diye değil, ne olduğunu söyleyerek
    // anlatmalı. Yoksa gönderilmemiş bir sipariş sessizce cihazda kalırdı.
    // `beklet` kararı BURAYA GİRMEZ — o kayıtlar sırada, kaybolmuş değil.
    if (reddedilen > 0) tur.kaliciRed = true;
  }

  /// TEK olaylık parti kalıcı 4xx yedi → suçlu bu olaydır (ya da bir zarf hatası vardır).
  /// Deneme sayısı artar; [SyncEngine.karantinaEsigi]'ne gelince KARANTİNA.
  ///
  /// ⚠️ KARANTİNA SİLME DEĞİLDİR (BRIEF kırmızı çizgi #3): satır outbox'ta `rejected` olarak
  /// DURUR, payload'ı dokunulmamıştır, `last_error` neden reddedildiğini söyler. Tek değişen,
  /// artık `pending` seçkisine girmemesi — yani kuyruğun geri kalanını kilitlememesi.
  Future<void> _redDenemesiIsle(OutboxData row, SyncApiException e, _PushTuru tur) async {
    final deneme = row.attempts + 1;
    final karantina = deneme >= SyncEngine.karantinaEsigi;
    if (karantina) tur.karantina++;
    await (db.update(db.outbox)..where((t) => t.id.equals(row.id))).write(
      OutboxCompanion(
        status: Value(karantina ? 'rejected' : 'pending'),
        attempts: Value(deneme),
        lastError: Value('HTTP ${e.statusCode} — ${_kisaGovde(e.body)}'),
      ),
    );
  }
}
