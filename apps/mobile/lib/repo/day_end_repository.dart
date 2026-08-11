import 'package:drift/drift.dart';

import '../bildirim/kurallar/para_kurallari.dart';
import '../data/app_database.dart';
import '../data/tr_gun.dart';

/// Gün sonu SALT-OKUNUR read-model (FAZ 3). Hiçbir tabloya YAZMAZ (kalıcı durum üretmez); tüm veriyi
/// yerel Drift'ten türetir. Kasa özeti + borç durumu. Kurye kasa DEVRİ (kalıcı mutabakat) ve atama
/// FAZ 4 sınırıdır — buraya girmez.
///
/// Gün sınırı SABİT +03:00 (Türkiye, 2016'dan beri DST yok): occurred_at (düzeltilmiş sunucu saati,
/// UTC ISO) +3s kaydırılıp yerel takvim günü çıkarılır. Sabit offset DST karmaşasını kökten kapatır.
class DayEndRepository {
  DayEndRepository(this.db);
  final AppDatabase db;

  /// Şu ANIN TR takvim günü. Gün sınırı kuralı artık `data/tr_gun.dart`ta TEK yerde durur (#9).
  ///
  /// DİKKAT: [simdi] verilmezse CİHAZ saati kullanılır. Para hesabının gün sınırı için
  /// `bugunTrDuzeltilmis(db)` tercih edilmeli — cihaz saati yanlışken ekran ile defter farklı
  /// gün konuşur (#4). Bu imza, saat düzeltmesine erişimi olmayan saf çağrılar (bildirim
  /// kuralları, testler) için sync kalıyor.
  static DateTime bugunTr({DateTime? simdi}) => trGunu(simdi ?? DateTime.now());

  /// occurred_at (UTC ISO) verilen TR yerel takvim gününe mi düşüyor?
  static bool _sameTrDay(String iso, DateTime localDate) => ayniTrGunIso(iso, localDate);

  /// Kasa özeti: gün içinde KASAYA DOKUNAN kayıtlar ödeme tipine göre. İnvariant (DECISIONS Faz 3):
  /// "payment_type taşıyan kayıt = kasaya dokundu" — payment (tahsilat, −) VE payment_type'lı
  /// correction (yanlış tahsilatı ters çeviren, +) birlikte toplanır; kasa katkısı = −amount_kurus.
  /// Böylece yanlış nakit tahsilat correction ile ters çevrilince kasa da düzelir (bakiye + kasa birlikte).
  ///
  /// [userId] verilirse yalnız O KULLANICININ topladıkları sayılır (tasarım: gün sonu ekranındaki
  /// kurye sekmesi). Opsiyonel — mevcut çağrılar (Tümü) aynen çalışır.
  /// KASAYA DOKUNAN kayıtların TEK süzgeci — [kasaOzeti] ve [tahsilatDetaylari] bunu paylaşır.
  ///
  /// AYRI YAZILSAYDI kırılım ile detay farklı rakam söylerdi: bayi "Havale 2.240 ₺" satırına
  /// dokunup açılan listede 1.900 ₺ görürse hangisinin doğru olduğunu soramaz ve ikisine de
  /// güvenmez. Bu depoda aynı sınıf hata (aynı parayı iki yerde ayrı hesaplamak) gün sonu
  /// tanımında üç kez tekrarlandı; süzgeç o yüzden tek yerde durur.
  Future<List<LedgerEntry>> _kasayaDokunanlar(DateTime localDate, String? userId) async {
    final query = db.select(db.ledgerEntries)..where((t) => t.paymentType.isNotNull());
    if (userId != null) {
      query.where((t) => t.collectedByUserId.equals(userId));
    }
    final hepsi = await query.get();
    return hepsi.where((e) => _sameTrDay(e.occurredAt, localDate)).toList();
  }

  Future<KasaOzeti> kasaOzeti(DateTime localDate, {String? userId}) async {
    final tillEntries = await _kasayaDokunanlar(localDate, userId);

    var nakit = 0, kart = 0, havale = 0;
    for (final e in tillEntries) {
      final giren = -e.amountKurus; // payment(−)→kasaya girer(+); ters correction(+)→kasadan çıkar(−)
      switch (e.paymentType) {
        case 'nakit':
          nakit += giren;
        case 'kart':
          kart += giren;
        case 'havale':
          havale += giren;
      }
    }
    return KasaOzeti(nakit: nakit, kart: kart, havale: havale);
  }

  /// Günün TAHSİLAT DETAYLARI — kasa kartındaki rakamların satır satır dökümü
  /// (kullanıcı isteği 2026-08-11: "havalelere tıklayınca o günkü havale siparişlerin
  /// detayları açılacak" + "altta günlük teslimatları detaylı görsün").
  ///
  /// [kasaOzeti] İLE AYNI SÜZGEÇTEN geçer ([_kasayaDokunanlar]) — yani bu listenin toplamı
  /// kartın rakamına EŞİTTİR. Ayrı bir sorgu yazmak, ekranın iki yerinde iki farklı para
  /// göstermek demekti.
  ///
  /// [odemeTuru] verilirse yalnız o tür (`nakit`/`kart`/`havale`) döner.
  ///
  /// TERS KAYITLAR (correction) LİSTEDE KALIR ve tutarları NEGATİF görünür: kartın toplamı
  /// onları içerdiği için gizlemek listeyi toplamla çelişir. Bayi "neden 200 ₺ eksik" diye
  /// sorduğunda cevabı bu satırdır; saklamak, sayıyı açıklanamaz yapardı.
  ///
  /// EN YENİ ÜSTTE. Adres BİRİNCİL adrestir; yoksa null (ekran satırı adressiz çizer —
  /// tezgâh satışının müşterisi de adresi de yoktur).
  Future<List<TahsilatSatiri>> tahsilatDetaylari(
    DateTime localDate, {
    String? userId,
    String? odemeTuru,
  }) async {
    var kayitlar = await _kasayaDokunanlar(localDate, userId);
    if (odemeTuru != null) {
      kayitlar = kayitlar.where((e) => e.paymentType == odemeTuru).toList();
    }
    if (kayitlar.isEmpty) return const [];

    // Müşteri ve adres TOPLU okunur: satır başına sorgu açmak 60 teslimatlı bir günde
    // 120 sorgu demekti ve gün sonu ekranı zaten `FutureBuilder` ile tek atış çalışıyor.
    final musteriIdler = {
      for (final e in kayitlar)
        if (e.customerId != null) e.customerId!,
    };
    final musteriler = musteriIdler.isEmpty
        ? const <Customer>[]
        : await (db.select(db.customers)..where((t) => t.id.isIn(musteriIdler))).get();
    final adresler = musteriIdler.isEmpty
        ? const <CustomerAddressesData>[]
        : await (db.select(db.customerAddresses)
              ..where((t) => t.customerId.isIn(musteriIdler))
              ..where((t) => t.deletedAt.isNull()))
            .get();

    final adMap = {for (final m in musteriler) m.id: m.name};
    final adresMap = <String, String>{};
    for (final a in adresler) {
      // Birincil adres kazanır; yoksa ilk görülen kalır (müşterinin tek adresi olabilir).
      if (a.isPrimary || !adresMap.containsKey(a.customerId)) {
        adresMap[a.customerId] = a.addressText;
      }
    }

    final satirlar = [
      for (final e in kayitlar)
        TahsilatSatiri(
          musteriAd: e.customerId == null
              ? 'Tezgâh satışı'
              : (adMap[e.customerId] ?? 'Müşteri'),
          adres: e.customerId == null ? null : adresMap[e.customerId],
          kurus: -e.amountKurus, // kartla AYNI işaret kuralı: kasaya giren pozitiftir
          odemeTuru: e.paymentType ?? '',
          occurredAt: e.occurredAt,
          orderId: e.relatedOrderId,
        ),
    ];
    satirlar.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return satirlar;
  }

  /// Gün içinde yazılan İSKONTO toplamı (POZİTİF kuruş; iskonto yoksa 0).
  ///
  /// KASADAN AYRI DURUR ve bu ayrım özelliğin bütün sebebidir (kullanıcı isteği 2026-07-30):
  /// kapıda kırılan 20 ₺ kasaya HİÇ girmedi. `discount` satırları `payment_type` taşımadığı için
  /// [kasaOzeti] onları zaten görmez — yani kasa sayımı iskontoyla şişmez ve gün sonu farkı KANIT
  /// olmayı sürdürür. Ama rakam görünmez de olamaz: "420 ₺lik siparişten neden 400 girdi"
  /// sorusunun cevabı gün sonunda okunabilmeli, yoksa bayi her iskontoda kasayı eksik sanır.
  ///
  /// [userId] verilirse yalnız O KULLANICININ verdiği iskontolar ([kasaOzeti] ile simetrik:
  /// `collected_by_user_id` teslimi yapan kişidir).
  Future<int> iskontoOzeti(DateTime localDate, {String? userId}) async {
    final query = db.select(db.ledgerEntries)..where((t) => t.entryType.equals('discount'));
    if (userId != null) {
      query.where((t) => t.collectedByUserId.equals(userId));
    }
    final kayitlar = await query.get();
    var toplam = 0;
    for (final e in kayitlar) {
      if (!_sameTrDay(e.occurredAt, localDate)) continue;
      toplam += -e.amountKurus; // discount NEGATİF yazılır (borcu düşürür); ekran pozitif ister
    }
    return toplam;
  }

  /// Gün içinde teslim edilen sipariş SAYISI (tasarım: "N teslimat"). [userId] verilirse yalnız
  /// o kuryeye atanmış siparişler. İptaller sayılmaz (status='delivered').
  Future<int> teslimatSayisi(DateTime localDate, {String? userId}) async {
    final query = db.select(db.orders)
      ..where((t) => t.deletedAt.isNull() & t.status.equals('delivered'));
    if (userId != null) {
      query.where((t) => t.assignedUserId.equals(userId));
    }
    final rows = await query.get();
    return rows.where((o) => _sameTrDay(o.occurredAt, localDate)).length;
  }

  /// Borç durumu: toplam açık veresiye (balance_kurus>0) + borçlu müşteri listesi (çoktan aza).
  Future<BorcDurumu> borcDurumu() async {
    final rows = await (db.select(db.customers)
          ..where((t) => t.deletedAt.isNull() & t.balanceKurus.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.balanceKurus)]))
        .get();

    final borclular = rows
        .map((c) => BorcluMusteri(customerId: c.id, name: c.name, balanceKurus: c.balanceKurus))
        .toList();
    final toplam = borclular.fold<int>(0, (s, b) => s + b.balanceKurus);
    return BorcDurumu(toplamAcikBorc: toplam, borclular: borclular);
  }

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Bildirim okuma katmanı (Faz 1 · para grubu). Kurallar SAFTIR; okuma burada durur.
  // ═════════════════════════════════════════════════════════════════════════════════════════

  /// Gün sonu bildiriminin üç rakamı. Kasa ve teslimat sayısı EKRANLA AYNI fonksiyonlardan
  /// gelir ([kasaOzeti], [teslimatSayisi]) — bildirim ile gün sonu ekranı farklı sayı konuşamaz.
  ///
  /// `veresiyeKurus` = günün `debit` toplamı − günün SİPARİŞ BAĞLI tahsilatı. Sipariş dışı
  /// tahsilat (eski borcun kapatılması) düşülmez: o, bugün yazılmış bir veresiyeyi kapatmaz.
  ///
  /// İSKONTO da düşülür ve bu DOĞRUDUR: `discount` negatiftir ve siparişe bağlıdır, yani aşağıdaki
  /// döngüde kendiliğinden sayılır. Kırılan tutar bugün yazılmış bir veresiye DEĞİLDİR — bildirime
  /// "20 ₺ veresiye" yazsaydık bayi hiç var olmayan bir alacağı takip ederdi. Kasa rakamı ise
  /// [kasaOzeti]den gelir ve orası iskontoyu görmez; iki rakam da doğru kaynaktan çıkar.
  Future<GunSonuVerisi> gunSonuBildirimVerisi(DateTime localDate) async {
    final kasa = await kasaOzeti(localDate);
    final teslim = await teslimatSayisi(localDate);

    final hareketler = await db.select(db.ledgerEntries).get();
    var borcYazilan = 0;
    var siparisTahsilati = 0;
    for (final e in hareketler) {
      if (!_sameTrDay(e.occurredAt, localDate)) continue;
      if (e.amountKurus > 0) {
        borcYazilan += e.amountKurus;
      } else if (e.relatedOrderId != null) {
        siparisTahsilati += -e.amountKurus;
      }
    }

    return GunSonuVerisi(
      gun: localDate,
      tahsilatKurus: kasa.toplam,
      teslimatSayisi: teslim,
      // Negatife düşemez: bir siparişten tutarından fazlası tahsil edilmiş olabilir (fazla ödeme
      // önceki borcu kapatır) ve o fark "bugün eksi veresiye yazıldı" anlamına gelmez.
      veresiyeKurus:
          borcYazilan - siparisTahsilati < 0 ? 0 : borcYazilan - siparisTahsilati,
    );
  }

  /// Haftalık tarama: FIFO yaşlandırmayla gecikmiş borcu olan müşteriler (çoktan aza).
  /// Bakiyesi pozitif olmayan müşteri hiç sorgulanmaz — gecikmiş borcu matematiksel olarak olamaz.
  Future<List<GecikmisMusteri>> gecikmisBorclular({
    required DateTime simdi,
    int gunEsigi = kVadeGunEsigi,
  }) async {
    final borclular = (await borcDurumu()).borclular;
    if (borclular.isEmpty) return const [];

    final kimlikler = borclular.map((b) => b.customerId).toSet();
    final hareketler = await (db.select(db.ledgerEntries)
          ..where((t) => t.customerId.isIn(kimlikler)))
        .get();

    final musteriBazli = <String, List<DefterHareketi>>{};
    for (final e in hareketler) {
      final zaman = DateTime.tryParse(e.occurredAt);
      if (zaman == null) continue; // okunamayan zaman damgası yaşlandırmaya sokulmaz
      musteriBazli
          .putIfAbsent(e.customerId!, () => [])
          .add(DefterHareketi(occurredAt: zaman.toUtc(), amountKurus: e.amountKurus));
    }

    final sonuc = <GecikmisMusteri>[];
    for (final b in borclular) {
      final tutar = gecikmisTutar(
        musteriBazli[b.customerId] ?? const [],
        simdi: simdi,
        gunEsigi: gunEsigi,
      );
      if (tutar > 0) {
        sonuc.add(GecikmisMusteri(customerId: b.customerId, ad: b.name, gecikmisKurus: tutar));
      }
    }
    sonuc.sort((a, b) => b.gecikmisKurus.compareTo(a.gecikmisKurus));
    return sonuc;
  }

  /// [localDate] gününde borcu eşiği AŞAN müşteriler (borcu çoktan aza).
  ///
  /// Geçişi defterden yeniden oynatarak buluruz: müşterinin hareketleri zamana göre sıralanır,
  /// koşan bakiye hesaplanır ve o güne düşen her yazımda [esikAsildiMi] sorulur. Böylece
  /// "bugün kim eşiği geçti" sorusu HİÇBİR DURUM SAKLAMADAN yanıtlanır — bildirim gönderilip
  /// gönderilmediğini bir tabloda tutmak zorunda kalsaydık, o tablo defterle ıraksayabilirdi.
  ///
  /// Eşiğin üstünde ZATEN duran müşteri dönmez (geçiş yok, yalnız seviye var) — mükerrer
  /// bildirimin kaynağı tam olarak bu ayrımdır.
  Future<List<EsikAsanMusteri>> bugunEsigiAsanlar(
    DateTime localDate, {
    required int esikKurus,
  }) async {
    // Eşik girilmemişse (Faz 1 varsayılanı KAPALI) defter hiç okunmaz.
    if (esikKurus <= kBorcEsigiKapali) return const [];

    final hareketler = await (db.select(db.ledgerEntries)
          ..where((t) => t.customerId.isNotNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.occurredAt),
            (t) => OrderingTerm.asc(t.id), // eşit zamanda deterministik sıra
          ]))
        .get();

    final kosanBakiye = <String, int>{};
    final asanlar = <String>{};
    for (final e in hareketler) {
      final cid = e.customerId!;
      final onceki = kosanBakiye[cid] ?? 0;
      final yeni = onceki + e.amountKurus;
      kosanBakiye[cid] = yeni;

      if (!_sameTrDay(e.occurredAt, localDate)) continue;
      final gecti = esikAsildiMi(
        BorcEsigiOlayi(
          customerId: cid,
          ad: '', // ad geçiş kararına girmez; aşağıda müşteri kaydından okunur
          oncekiBakiyeKurus: onceki,
          yeniBakiyeKurus: yeni,
          occurredAtIso: e.occurredAt,
        ),
        esikKurus: esikKurus,
      );
      if (gecti) asanlar.add(cid);
    }
    if (asanlar.isEmpty) return const [];

    final musteriler = await (db.select(db.customers)
          ..where((t) => t.id.isIn(asanlar) & t.deletedAt.isNull()))
        .get();

    final sonuc = musteriler
        .map((c) => EsikAsanMusteri(
              customerId: c.id,
              ad: c.name,
              bakiyeKurus: c.balanceKurus,
            ))
        .toList()
      ..sort((a, b) => b.bakiyeKurus.compareTo(a.bakiyeKurus));
    return sonuc;
  }
}

/// Günün TEK bir tahsilat satırı — gün özetindeki detay listesinin ve ödeme türü
/// dökümünün ortak satır tipi (kullanıcı isteği 2026-08-11).
///
/// SİPARİŞ DEĞİL TAHSİLAT taşır ve ayrım önemlidir: kartın rakamı defterden (`ledger_entries`)
/// gelir, siparişten değil. Veresiye teslim edilen bir sipariş o gün kasaya HİÇ girmez ve bu
/// listede görünmemelidir — göründüğü an liste toplamı kasa kartını aşar ve iki rakam
/// birbirini yalanlar.
class TahsilatSatiri {
  const TahsilatSatiri({
    required this.musteriAd,
    required this.kurus,
    required this.odemeTuru,
    required this.occurredAt,
    this.adres,
    this.orderId,
  });

  final String musteriAd;

  /// Müşterinin birincil adresi; tezgâh satışında ve adresi olmayan müşteride null.
  final String? adres;

  /// Kasaya GİREN tutar (ters kayıtta negatif) — kasa kartıyla aynı işaret kuralı.
  final int kurus;

  /// `nakit` · `kart` · `havale`.
  final String odemeTuru;

  final String occurredAt;
  final String? orderId;
}

/// Gün sonu kasa özeti (kuruş). Salt-okunur değer nesnesi.
class KasaOzeti {
  KasaOzeti({required this.nakit, required this.kart, required this.havale});
  final int nakit;
  final int kart;
  final int havale;
  int get toplam => nakit + kart + havale;
}

class BorcDurumu {
  BorcDurumu({required this.toplamAcikBorc, required this.borclular});
  final int toplamAcikBorc;
  final List<BorcluMusteri> borclular;
}

class BorcluMusteri {
  BorcluMusteri({required this.customerId, required this.name, required this.balanceKurus});
  final String customerId;
  final String name;
  final int balanceKurus;
}
