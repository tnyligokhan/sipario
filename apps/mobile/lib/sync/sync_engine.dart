import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import 'sync_api.dart';

// İKİ TUR, İKİ DOSYA (500 satır sınırı — bölme 2026-08-17). Motor 850 satıra çıkmıştı ve
// içindeki iki iş birbirine hiç bakmıyordu: giden kutusunu İTMEK ile sunucudan ÇEKMEK ayrı
// sözleşmeler, ayrı hata politikaları, ayrı testlerdir.
//
// NEDEN `part` (ayrı kütüphane değil): motorun bütün iç yüzeyi `_` ile gizlidir ve gizli
// KALMALIDIR — `_kararVer` (beyaz liste), `_guvenliUygula` (sürüm çarpıklığı kapısı) ve JSON
// tip yardımcıları dışarıdan çağrılabilir olsaydı, aynı kararı ikinci bir yerde vermenin yolu
// açılırdı; bu dosyadaki her uyarı tam olarak o sınıf hatanın izidir. `part` aynı kütüphanede
// kalmayı, dolayısıyla gizliliği ve `db`/`api` alanlarına erişimi korur. Çağrı yerleri ve
// testler DEĞİŞMEZ: `import 'sync_engine.dart'` üçünü birden görür.
part 'sync_itme.dart';
part 'sync_cekme.dart';

/// Senkron motoru (DECISIONS): giden kutusunu sunucuya iter (push) ve delta/snapshot çeker (pull).
/// İki işçi tek sınıfta toplanır; ağ tetiği (connectivity) ve zamanlayıcı bunları çağırır.
///
/// Çakışma (istemci tarafı): pull bir varlık değişikliği getirdiğinde, o varlık için GÖNDERİLMEMİŞ
/// (pending) daha yeni occurred_at'li bir outbox düzenlemesi varsa YERELİ KORU (o push sunucuda
/// kazanacak). Defter/olay tabloları append: id/client_event_id ile "yoksa ekle" — asla ezme.
///
/// Bu dosya turların ORTAK zeminidir: bağlantı (`db`/`api`), satır bazında zehirli hap koruması
/// ([_guvenliUygula]) ve HER İKİ yanıtta da inen sunucu-sahipli bloklar (server_time, api_version,
/// abonelik, ekip). Turların kendisi `sync_itme.dart` ve `sync_cekme.dart` dosyalarındadır.
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
  /// SINIF GÖVDESİNDE KALIR (turlarla birlikte taşınmadı): ekip bloğunu yazan [_applyTeam] de
  /// bunu kullanır ve o blok HER İKİ yanıtta iner. Kapı bir tur politikası değil, motorun
  /// tamamının satır bazında dayanıklılık sözüdür.
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
                courierCanSeeAllCustomers: Value(_bN(u['courier_can_see_all_customers'])),
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
}

// ---- JSON tip yardımcıları (sunucu attributesToArray çıktısını güvenli çevir) ----
//
// KÜTÜPHANE DÜZEYİNDE, sınıfın statiği DEĞİL: hem bu dosyadaki ekip bloğu hem `sync_cekme.dart`
// içindeki satır yazıcıları kullanıyor. `_` ile gizli oldukları için dışarıya hiçbir şey açılmaz.
int _i(dynamic v) => (v as num).toInt();
int? _iN(dynamic v) => v == null ? null : (v as num).toInt();
double? _dN(dynamic v) => v == null ? null : (v as num).toDouble();
String _s(dynamic v) => v as String;
String? _sN(dynamic v) => v as String?;
bool _b(dynamic v) => v == true || v == 1;

/// Varsayılanlı boolean: alan YOKSA (eski sunucu sürümü) [varsayilan] kullanılır.
///
/// `_b` burada YETMEZ: o, gelmeyen alanı `false` sayar. Varsayılanı `true` olan bir yetki
/// (ör. kurye tahsilat alabilir) eski bir sunucuya bağlandığında sessizce KAPANIRDI —
/// kurye sahada işini yapamaz, kimse de nedenini bilmezdi.
bool _bV(dynamic v, bool varsayilan) => v == null ? varsayilan : _b(v);

/// SÜRÜM ÇARPIKLIĞI KORUMASI — sunucunun HENÜZ BİLMEDİĞİ metin alanı için.
///
/// Anahtar payload'da VARSA değeri (null olsa bile) yazılır; anahtar HİÇ YOKSA
/// `Value.absent()` döner ve drift o kolonu `ON CONFLICT DO UPDATE SET` listesine hiç
/// koymaz — yani cihazdaki mevcut değer KORUNUR.
///
/// ⚠️ NEDEN VAR (2026-08-13, GERÇEK CİHAZDA YAKALANDI): `call_logs.user_id` eklendi, telefon
/// atfı doğru yazdı, ama uygulama CANLI sunucuya bağlıydı ve orada bu alan henüz yoktu.
/// Sunucu alanı düşürdü, pull o satırı geri getirdi ve istemci `_sN` ile okuduğu için EKSİK
/// anahtarı `null` sayıp KENDİ DOĞRU VERİSİNİ EZDİ. Belirti sinsiydi: kayıt görünüyor, atıf
/// birkaç saniye sonra kayboluyordu ve kullanıcıya göre süzgeç hiçbir şey bulamıyordu.
///
/// Bu, `_bV`nin metin karşılığıdır ve aynı sınıf hatadır: **gelmeyen alan, "boş" demek
/// değildir.** Sunucu tarafında aynı koruma `SyncPayload::gonderilenler`da yaşıyor; istemci
/// pull yolunda karşılığı yoktu.
///
/// Sunucu dağıtıldıktan sonra da GEREKLİ: telefonlar günlerce eski sürümde kalabildiği gibi
/// sunucu da bir istemciden geride kalabilir (aşamalı dağıtım, geri alma).
Value<String?> _korunan(Map<String, dynamic> m, String anahtar) =>
    m.containsKey(anahtar) ? Value(_sN(m[anahtar])) : const Value.absent();

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
String? _jsonMetin(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return jsonEncode(v);
}

/// ÜÇ DURUMLU boolean: `null` yokluğu KORUR, ezmez.
///
/// `_b`/`_bV`den farkı anlamlıdır ve kişiye özel kurye yetkilerinin (2026-08-10) tamamı buna
/// dayanır: orada `null` bir eksiklik değil, ÜÇÜNCÜ BİR DEĞERDİR — "bayi varsayılanını
/// devral". Bu alanları `_b` ile okumak devralmayı `false`a çevirir ve yetkiyi sessizce kapatır.
bool? _bN(dynamic v) => v == null ? null : _b(v);
