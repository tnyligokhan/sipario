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

class SyncEngine {
  SyncEngine(this.db, this.api);
  final AppDatabase db;
  final SyncApi api;

  /// KARANTİNA EŞİĞİ: bir olay TEK BAŞINA bu kadar kez kalıcı 4xx yerse artık gönderilmez.
  ///
  /// 1 DEĞİL, bilerek: parti düzeyindeki bir 4xx her zaman "bu olay bozuk" demek değildir.
  /// ZARF hatası (dizi değil / boş / çok büyük) ya da sunucudaki bir dağıtım hatası tek olaylık
  /// partiyi de reddeder — eşiksiz bir karantina, masum bir siparişi ilk aksilikte gönderilmez
  /// yapardı. 3 tur ≈ 6 dakika (zamanlayıcı 2 dk): sunucu tarafı düzelirse kayıt kendiliğinden
  /// akar, düzelmezse kuyruk yine de kilitli kalmaz.
  static const int karantinaEsigi = 3;

  /// İKİLİ ARAMA BÜTÇESİ: parti reddedilince bir turda atılacak azami EK istek. 500 olayda tek
  /// suçluyu daraltmak ~2·log2(500) ≈ 18 istek eder; 24 buna yer bırakır ama zayıf şebekede
  /// turu saatlerce sürdürmez. Bütçe biterse kalan olaylar PENDING kalır (kayıp yok) ve sonraki
  /// tur kaldığı yerden devam eder.
  ///
  /// ⚠️ BÖLME YALNIZ KALICI 4xx'TE: zaman aşımı ve 5xx'te bölmek, ulaşılamayan bir sunucuya
  /// log₂n kat daha fazla istek atmak — kararsız şebekede istek fırtınası — olurdu. O hatalar
  /// `_partiGonder`de `rethrow` edilir ve tur düşer; kayıtlar sırada bekler
  /// (`sync_zaman_asimi_test.dart` bu ayrımı iki yönlü kilitler).
  static const int _bolmeButcesi = 24;

  /// Bekleyen outbox olaylarını gönderir.
  ///
  /// applied/duplicate/stale/noop → acked (retry durur). rejected → karantina (elle inceleme).
  /// locked ve BİLİNMEYEN durumlar → pending KALIR (bkz. [_kararVer]) — silinmez, sıradadır.
  ///
  /// PARTİ DÜZEYİNDE KALICI 4xx (sunucu bize ULAŞTI ve "bunu kabul etmiyorum" dedi) artık turu
  /// düşürmez: parti İKİYE BÖLÜNEREK suçlu daraltılır. Kabul edilen yarı aynı turda akar — tek
  /// bozuk olay bütün kuyruğu rehin alamaz. Suçlu tek olaya inince deneme sayısı artar ve
  /// [karantinaEsigi]'nde kayıt `rejected` olur; SİLİNMEZ.
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

  /// Sunucu durumunu outbox kararına çevirir — BEYAZ LİSTE (bkz. [_Karar]).
  static _Karar _kararVer(String status) => switch (status) {
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
  static String? _sebepMetni(EventResult res) {
    final mesaj = res.message;
    final kod = res.reason;
    if (mesaj != null && kod != null) return '$mesaj ($kod)';
    return mesaj ?? kod;
  }

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
  /// Deneme sayısı artar; [karantinaEsigi]'ne gelince KARANTİNA.
  ///
  /// ⚠️ KARANTİNA SİLME DEĞİLDİR (BRIEF kırmızı çizgi #3): satır outbox'ta `rejected` olarak
  /// DURUR, payload'ı dokunulmamıştır, `last_error` neden reddedildiğini söyler. Tek değişen,
  /// artık `pending` seçkisine girmemesi — yani kuyruğun geri kalanını kilitlememesi.
  Future<void> _redDenemesiIsle(OutboxData row, SyncApiException e, _PushTuru tur) async {
    final deneme = row.attempts + 1;
    final karantina = deneme >= karantinaEsigi;
    if (karantina) tur.karantina++;
    await (db.update(db.outbox)..where((t) => t.id.equals(row.id))).write(
      OutboxCompanion(
        status: Value(karantina ? 'rejected' : 'pending'),
        attempts: Value(deneme),
        lastError: Value('HTTP ${e.statusCode} · ${_kisaGovde(e.body)}'),
      ),
    );
  }

  /// Sunucu gövdesinin saklanan kısmı. KIRPILIR: bir doğrulama hatası bütün payload'ı geri
  /// yankılayabilir ve outbox satırını şişirir; teşhis için ilk satır zaten yeter.
  static String _kisaGovde(String body) {
    final tek = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return tek.length <= 200 ? tek : '${tek.substring(0, 200)}…';
  }

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

  /// SÜRÜM ÇARPIKLIĞI KAPISI (2026-08-05) — pull yönünün zehirli hap koruması.
  ///
  /// Tek bir satırın ayrıştırılması, SAYFANIN geri kalanını ve `lastPulledSeq` ilerlemesini
  /// rehin alamaz. Eskiden alıyordu: satır ayrıştırıcıları null-güvensiz cast kullanır
  /// (`m['name'] as String`) ve sayfa TEK transaction'da uygulanırdı. Sunucu bir migration'la
  /// bir kolonu nullable yaptığında ya da tek satırda beklenmedik bir tip gönderdiğinde TypeError
  /// transaction'ı düşürür, cursor İLERLEMEZ ve sonraki tur aynı sayfayı çekip aynı yerde düşerdi
  /// — senkron kalıcı ölür, tek "çözüm" uygulama verisini silmek olurdu (kırmızı çizgi #3).
  ///
  /// Push yönünde bu sınıf zaten kapalıydı (sunucuda olay bazında savepoint, istemcide ikili
  /// arama). Bu, aynı disiplinin okuma yönündeki karşılığıdır: kayıp SATIRA hapsedilir.
  ///
  /// NEDEN "ATLA" SEÇİLDİ (alternatifleri elendi):
  ///  • "Turu düşür" = eski davranış = KALICI ÖLÜM. Cursor ilerlemediği için sonraki tur aynı
  ///    sayfayı çeker; bu, atlamaktan tartışmasız daha kötüdür.
  ///  • "Snapshot'a dön" = onarmaz: snapshot da AYNI ayrıştırıcıdan geçer, aynı satırda yine
  ///    düşer — üstelik her turda tam snapshot çekerek şebekeyi yakar.
  ///  • "Yerel karantina kaydına yaz" = doğru yol ama `sync_meta` şema sürümü + onu gösterecek
  ///    bir yüzey ister; bugün ikisi de yok.
  ///
  /// ATLAMAK KALICI KAYIP DEĞİLDİR: sunucunun delta yükü DEĞİŞEN ALANLAR değil satırın TAM
  /// DURUMUdur (`SyncPayload::change` → `attributesToArray()`), yani o varlığa yapılan HERHANGİ
  /// bir sonraki güncelleme kaçan satırı eksiksiz indirir (sync_surum_carpikligi_test bunu kilitler).
  ///
  /// ⚠️ BİLİNEN BOŞLUK (kapatılmadı, bilinçli): cursor ilerlediği için atlanan satır BİR DAHA
  /// gelmez. Dolayısıyla (a) `veri` cinsinden tur hatası yalnız O turda yanar, kalıcı bir "eksiğin
  /// var" işareti yoktur; (b) bir daha HİÇ dokunulmayan varlığın kaçan güncellemesi, uygulama
  /// güncellense bile geri gelmez — `logout` `lastPulledSeq`e bilerek dokunmaz (offline-first),
  /// yani çıkış+giriş de snapshot'a döndürmez. Gerçek kapağı: atlanan en erken seq'i `sync_meta`ya
  /// yazmak ve uygulama sürümü değiştiğinde cursor'u oraya geri sarmak — şema sürümü işi.
  ///
  /// `Object` yakalanır, `Exception` değil: buradaki tehlike TypeError'dur ve o bir Error'dur.
  Future<bool> _guvenliUygula(Future<void> Function() is_) async {
    try {
      await is_();

      return true;
    } catch (_) {
      return false;
    }
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
              // FAVORİ ÜRÜNLER (v18) — cihazda JSON METİN saklanır. Sunucu bu alanı ya metin
              // ya da gerçek JSON dizi olarak gönderebilir (kolon `text` mi `json` cast'li mi
              // olduğuna göre değişir) ve İKİSİ DE kabul edilir: tek biçim bekleyen bir cast,
              // sunucu tarafı kolonu bir gün `json`a çevirdiğinde satırı TypeError'a düşürür ve
              // sürüm çarpıklığı kapısı o müşteriyi sessizce ATLAR (bkz. _guvenliUygula).
              favoriteProductIds: Value(_jsonMetin(m['favorite_product_ids'])),
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
              // SATIR NOTU (v18) — `unit` ile birebir aynı desen: satırda saklanan, o anki gerçek.
              // Eski sunucu alanı hiç göndermezse null kalır (not yoktu, doğru başlangıç).
              note: Value(_sN(m['note'])),
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
  /// Bozuk BİR eleman listenin tamamını düşürmez (2026-08-05): eskiden `_s` cast'i TypeError
  /// atınca transaction geri alınır ve hata `pull`/`push` turunun TAMAMINI düşürürdü — üstelik
  /// `team` her iki yanıtta da geldiği için senkron her yönde ölürdü. Artık atlanan eleman
  /// sayılır ve turun sonucuna yansır; ekip listesinin geri kalanı yazılır.
  ///
  /// @return atlanan eleman sayısı
  Future<int> _applyTeam(List<Map<String, dynamic>>? team) async {
    if (team == null) return 0;
    var atlanan = 0;
    await db.transaction(() async {
      await db.delete(db.users).go();
      for (final u in team) {
        final ok = await _guvenliUygula(() async {
          await db.into(db.users).insert(UsersCompanion.insert(
                id: _s(u['id']),
                name: _s(u['name']),
                role: _s(u['role']),
                status: _s(u['status']),
                phone: Value(_sN(u['phone'])),
                // Eski sunucu `username` göndermezse boş kalır (kolon NOT NULL, varsayılan '') —
                // Kuryeler ekranı o durumda giriş adını "—" gösterir, uydurmaz.
                username: Value(_sN(u['username']) ?? ''),
                // KİŞİYE ÖZEL YETKİLER (2026-08-10) — `_bN` ile, `_bV` ile DEĞİL: burada
                // "alan gelmedi" ile "false geldi" AYRI şeylerdir. Eski bir sunucu bu 13
                // anahtarı hiç göndermez; onları `false` saymak, bayi varsayılanı açık olan
                // bir yetkiyi (ör. tahsilat) sahadaki her kurye için sessizce KAPATIRDI.
                // `null` yazmak devralmayı korur ve davranış bugünküyle birebir aynı kalır.
                courierCanCustomers: Value(_bN(u['courier_can_customers'])),
                courierCanOrders: Value(_bN(u['courier_can_orders'])),
                courierCanCollect: Value(_bN(u['courier_can_collect'])),
                courierCanDiscount: Value(_bN(u['courier_can_discount'])),
                courierCanDayEnd: Value(_bN(u['courier_can_day_end'])),
                courierCanSeeAllOrders: Value(_bN(u['courier_can_see_all_orders'])),
                courierCanViewHistory: Value(_bN(u['courier_can_view_history'])),
                courierCanExpense: Value(_bN(u['courier_can_expense'])),
                courierPhoneMask: Value(_bN(u['courier_phone_mask'])),
                courierCanCustomerLedger: Value(_bN(u['courier_can_customer_ledger'])),
                courierCanDebtReminder: Value(_bN(u['courier_can_debt_reminder'])),
                courierCanToggleStock: Value(_bN(u['courier_can_toggle_stock'])),
                courierCanCallLog: Value(_bN(u['courier_can_call_log'])),
              ));
        });
        if (!ok) atlanan++;
      }
    });

    return atlanan;
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

  /// Sunucunun bildirdiği sözleşme sürümünü (`api_version`) önbelleğe yaz.
  ///
  /// YOKLUK EZMEZ (`if (surum == null) return`): sürüm bildirmeyen bir yanıt — eski bir sunucu
  /// sürümü, ya da yanıtı bu alanı taşımayan bir ara katman — bilinen son sürümü SİLMEK için
  /// gerekçe değildir. Ezseydi, bir tur bile eksik alan gelmesi Ayarlar'daki satırı boşaltır ve
  /// "sunucu sürümü bilinmiyor" yanlış bilgisini verirdi.
  ///
  /// Karşılaştırma/uyarı BİLİNÇLİ OLARAK YOK: bu alan bir GÖSTERİMDİR. İstemcinin "sunucu benden
  /// yeni, kilitleneyim" demesi için önce hangi sürüm çiftinin uyumsuz olduğunu söyleyen YAZILI
  /// bir karar gerekir (CLAUDE.md → Sürümleme: MAJOR bir olaydır ve eski istemcinin ne yapacağı
  /// önceden kararlaştırılır). O karar olmadan eklenecek bir uyarı, uyumlu bir sunucu sürümünde
  /// bayiyi boş yere korkuturdu.
  Future<void> _applyApiSurumu(String? surum) async {
    if (surum == null) return;
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(apiVersion: Value(surum)));
  }

  // ---- JSON tip yardımcıları (sunucu attributesToArray çıktısını güvenli çevir) ----
  static int _i(dynamic v) => (v as num).toInt();
  static int? _iN(dynamic v) => v == null ? null : (v as num).toInt();
  static double? _dN(dynamic v) => v == null ? null : (v as num).toDouble();
  static String _s(dynamic v) => v as String;
  static String? _sN(dynamic v) => v as String?;
  static bool _b(dynamic v) => v == true || v == 1;

  /// Varsayılanlı boolean: alan YOKSA (eski sunucu sürümü) [varsayilan] kullanılır.
  ///
  /// `_b` burada YETMEZ: o, gelmeyen alanı `false` sayar. Varsayılanı `true` olan bir yetki
  /// (ör. kurye tahsilat alabilir) eski bir sunucuya bağlandığında sessizce KAPANIRDI —
  /// kurye sahada işini yapamaz, kimse de nedenini bilmezdi.
  static bool _bV(dynamic v, bool varsayilan) => v == null ? varsayilan : _b(v);

  /// JSON alanının CİHAZDA saklanan metin karşılığı (v18 favori ürünler).
  ///
  /// Sunucu aynı alanı iki biçimde gönderebilir ve ikisi de meşrudur: kolon düz `text` ise
  /// zaten JSON METİN gelir (`'["a","b"]'`), `json`/`array` cast'liyse Laravel onu
  /// `attributesToArray()`te GERÇEK DİZİ yapar. Tek biçim bekleyen bir cast, sunucu bir gün
  /// diğerine geçtiğinde o satırı düşürür ve sürüm çarpıklığı kapısı müşteriyi sessizce atlar.
  ///
  /// Metin OLDUĞU GİBİ saklanır (yeniden kodlanmaz): bozuk bir metin gelse bile okuma tarafı
  /// (`favoriIdleriCoz`) boş listeye düşer — burada kırpmak, ileride eklenecek bir alanı da
  /// sessizce yutardı.
  static String? _jsonMetin(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return jsonEncode(v);
  }

  /// ÜÇ DURUMLU boolean: `null` yokluğu KORUR, ezmez.
  ///
  /// `_b`/`_bV`den farkı anlamlıdır ve kişiye özel kurye yetkilerinin (2026-08-10) tamamı buna
  /// dayanır: orada `null` bir eksiklik değil, ÜÇÜNCÜ BİR DEĞERDİR — "bayi varsayılanını
  /// devral". Bu alanları `_b` ile okumak devralmayı `false`a çevirir ve yetkiyi sessizce kapatır.
  static bool? _bN(dynamic v) => v == null ? null : _b(v);
}
