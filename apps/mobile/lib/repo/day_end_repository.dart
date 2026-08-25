import 'package:drift/drift.dart';

import '../bildirim/kurallar/para_kurallari.dart';
import '../data/app_database.dart';
import '../data/tr_gun.dart';
import 'gun_veresiye_repository.dart';
import 'islem_sahibi.dart';

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
  Future<List<LedgerEntry>> _kasayaDokunanlar(
      DateTime localDate, String? userId, String? haric) async {
    final query = db.select(db.ledgerEntries)..where((t) => t.paymentType.isNotNull());
    query.where((t) =>
        defterKapsamSuzgeci(t, userId: userId, haric: haric) ?? const Constant(true));
    final hepsi = await query.get();
    return hepsi.where((e) => _sameTrDay(e.occurredAt, localDate)).toList();
  }

  Future<KasaOzeti> kasaOzeti(DateTime localDate, {String? userId, String? haric}) async {
    final tillEntries = await _kasayaDokunanlar(localDate, userId, haric);

    var nakit = 0, kart = 0, havale = 0, gider = 0;
    for (final e in tillEntries) {
      // GİDER AYRI KOVAYA DÜŞER, tahsilat kovalarına DEĞİL (2026-08-25). İkisi de kasaya dokunur
      // ama zıt yönde ve farklı soruların cevabıdır: "bugün ne tahsil ettim" ile "kasada ne
      // kalmalı". Gideri `nakit`in içine eritseydik üstteki satır "Nakit" derken NET rakamı
      // gösterir, "Toplam tahsilat" etiketi de düpedüz yalan olurdu — bu depoda tam olarak bu
      // hata sınıfı (anlamı değişen sayıyı eski kelimesiyle taşımak) gün sonu tanımında üç kez
      // tekrarlandı. Net rakam [KasaOzeti.netNakit] ile AYRI ve ADIYLA taşınır.
      //
      // TERS GİDER SATIRI (iptal) NEGATİF tutarlıdır ve aynı kovada netlenir: iptal edilmiş bir
      // gider toplamdan kendiliğinden düşer, ikinci bir küme sorgusu gerekmez.
      if (e.entryType == 'expense') {
        gider += e.amountKurus; // gider POZİTİF yazılır (kasadan çıkan); iptali NEGATİF
        continue;
      }
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
    return KasaOzeti(nakit: nakit, kart: kart, havale: havale, gider: gider);
  }

  /// Günün TAHSİLAT DETAYLARI — kasa kartındaki rakamların satır satır dökümü
  /// (kullanıcı isteği 2026-08-11: "havalelere tıklayınca o günkü havale siparişlerin
  /// detayları açılacak" + "altta günlük teslimatları detaylı görsün").
  ///
  /// [kasaOzeti] İLE AYNI SÜZGEÇTEN geçer ([_kasayaDokunanlar]) — yani bu listenin toplamı
  /// kartın rakamına EŞİTTİR. Ayrı bir sorgu yazmak, ekranın iki yerinde iki farklı para
  /// göstermek demekti.
  ///
  /// GİDER SATIRLARI BU LİSTEDE YOKTUR (2026-08-25) ve olmamalı: liste "Nakit 8.000 ₺" satırının
  /// dökümüdür ve o rakam tahsilattır. Gider satırları girseydi listenin toplamı kartın rakamını
  /// TUTMAZDI — dökümün tek varlık sebebi ise toplamı doğrulatabilmektir. Giderlerin kendi
  /// dökümü ayrıdır (`GiderRepository.gunGiderleri`).
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
    String? haric,
    String? odemeTuru,
  }) async {
    var kayitlar = await _kasayaDokunanlar(localDate, userId, haric)
      ..removeWhere((e) => e.entryType == 'expense'); // gider bir tahsilat değildir
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

    // TAHSİLATIN KAYNAĞI: bağlı siparişlerin GÜNÜ toplu okunur (saha isteği 2026-08-18 —
    // "geçmişten kalan bir siparişin tahsilatını yaptıysa bunu ayrı belirtmeli"). Satır başına
    // sorgu açmak yerine tek `isIn`: 60 tahsilatlı bir gün 60 sorgu demekti.
    final siparisIdler = {
      for (final e in kayitlar)
        if (e.relatedOrderId != null) e.relatedOrderId!,
    };
    final siparisler = siparisIdler.isEmpty
        ? const <Order>[]
        : await (db.select(db.orders)..where((t) => t.id.isIn(siparisIdler))).get();
    final siparisGunu = {for (final o in siparisler) o.id: o.occurredAt};

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
          kaynak: tahsilatKaynagi(
            entryType: e.entryType,
            relatedOrderId: e.relatedOrderId,
            siparisGunu: e.relatedOrderId == null ? null : siparisGunu[e.relatedOrderId],
            localDate: localDate,
          ),
        ),
    ];
    satirlar.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return satirlar;
  }

  /// BUGÜNKÜ SATIŞ DIŞI tahsilat toplamı — eski borç kapatmaları (pozitif kuruş).
  ///
  /// [kasaOzeti]NİN İÇİNDEDİR, ondan düşülmez (kullanıcı kararı 2026-08-18: "hesaba yine dahil
  /// etsin sıkıntı yok"). Ayrı bir sayı olarak durmasının sebebi mutabakat değil ANLAMDIR:
  /// kasadaki 3.400 ₺'nin 1.200'ü dün teslim edilmiş bir siparişin bugün ödenmesiyse, bugünün
  /// cirosu 3.400 DEĞİLDİR. Bu satır olmadan bayi her tahsilatı bugünün satışı sanar.
  Future<int> eskiBorcTahsilati(DateTime localDate, {String? userId, String? haric}) async {
    final satirlar = await tahsilatDetaylari(localDate, userId: userId, haric: haric);
    var toplam = 0;
    for (final s in satirlar) {
      if (s.kaynak == TahsilatKaynagi.gununSiparisi) continue;
      // DÜZELTME de dışarıda: ters kayıt bir tahsilat değil, bir tahsilatın geri alınmasıdır.
      if (s.kaynak == TahsilatKaynagi.duzeltme) continue;
      toplam += s.kurus;
    }
    return toplam;
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
  Future<int> iskontoOzeti(DateTime localDate, {String? userId, String? haric}) async {
    final query = db.select(db.ledgerEntries)..where((t) => t.entryType.equals('discount'));
    query.where((t) =>
        defterKapsamSuzgeci(t, userId: userId, haric: haric) ?? const Constant(true));
    final kayitlar = await query.get();
    var toplam = 0;
    for (final e in kayitlar) {
      if (!_sameTrDay(e.occurredAt, localDate)) continue;
      toplam += -e.amountKurus; // discount NEGATİF yazılır (borcu düşürür); ekran pozitif ister
    }
    return toplam;
  }

  /// Gün içinde teslim edilen sipariş SAYISI (tasarım: "N teslimat"). [userId] verilirse yalnız
  /// o kullanıcının TESLİM ETTİKLERİ. İptaller sayılmaz (status='delivered').
  ///
  /// ⚠️ ESKİDEN ATAMAYA BAKIYORDU (2026-08-20'de düzeltildi): patron, Ali'ye atanmış siparişi
  /// kendisi teslim ettiğinde teslimat ALİ'nin hesabına yazılıyordu — üstelik parası patronda
  /// kalarak, yani aynı olayın iki yarısı iki ayrı kişiye gidiyordu. Kural [siparisSahibiEsit]
  /// içinde tek yerde durur ve günün veresiyesiyle ORTAKTIR.
  Future<int> teslimatSayisi(DateTime localDate, {String? userId, String? haric}) async {
    final query = db.select(db.orders)
      ..where((t) => t.deletedAt.isNull() & t.status.equals('delivered'));
    query.where((t) =>
        siparisKapsamSuzgeci(t, userId: userId, haric: haric) ?? const Constant(true));
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
  /// `veresiyeKurus` GÜN ÖZETİ EKRANIYLA AYNI KODDAN gelir (`GunVeresiyeRepository.toplam`) —
  /// bildirim ile ekran farklı bir veresiye rakamı konuşamaz.
  ///
  /// ⚠️ ESKİDEN BURADA AYRI BİR HESAP VARDI (2026-08-18'de kaldırıldı): "günün tüm pozitif
  /// hareketleri − siparişe bağlı tahsilat", sonucu negatife düşmesin diye sıfıra kırpılmış
  /// hâlde. Kırpma bir düzeltme değil, bir BELİRTİ ÖRTMESİYDİ: hesap gün genelinde tek toplam
  /// aldığı için bir müşterinin fazla ödemesi (eski borcunu da kapatması) BAŞKA bir siparişin
  /// veresiyesini sessizce götürebiliyordu. Doğru birim sipariştir; gerekçenin tamamı
  /// `gun_veresiye_repository.dart` başlığında.
  ///
  /// İSKONTO yine düşülür ve bu DOĞRUDUR: `discount` negatiftir ve siparişe bağlıdır, yani
  /// grubun netinde kendiliğinden sayılır. Kırılan tutar bugün yazılmış bir veresiye DEĞİLDİR —
  /// bildirime "20 ₺ veresiye" yazsaydık bayi hiç var olmayan bir alacağı takip ederdi.
  Future<GunSonuVerisi> gunSonuBildirimVerisi(DateTime localDate) async {
    final kasa = await kasaOzeti(localDate);
    final teslim = await teslimatSayisi(localDate);

    return GunSonuVerisi(
      gun: localDate,
      tahsilatKurus: kasa.toplam,
      teslimatSayisi: teslim,
      veresiyeKurus: await GunVeresiyeRepository(db).toplam(localDate),
    );
  }
}

/// Bir tahsilatın NEREDEN geldiği (saha isteği 2026-08-18).
///
/// SORUN: kasaya giren her kuruş listede aynı görünüyordu. Bayi dün teslim ettiği bir siparişin
/// borcunu bugün tahsil ettiğinde satır, bugün yapılmış bir satıştan ayırt edilemiyordu — yani
/// "bugün ne sattım" sorusunun cevabı kasadaki rakam sanılıyordu. Para doğruydu, ANLAMI yanlıştı.
///
/// Sınıflandırma KASAYI DEĞİŞTİRMEZ: dördü de kasa toplamına dahildir (kullanıcı kararı). Tek
/// yaptığı, aynı rakamın hangi işten geldiğini söylemektir.
enum TahsilatKaynagi {
  /// BUGÜN teslim edilen bir siparişin tahsilatı — günün cirosu budur.
  gununSiparisi,

  /// GEÇMİŞ bir güne ait siparişin tahsilatı. Para bugün girdi, satış bugün olmadı.
  gecmisSiparis,

  /// Siparişe bağlı olmayan tahsilat: müşterinin birikmiş bakiyesinden ödeme
  /// (`LedgerRepository.tahsilat`). Hangi siparişi kapattığı defterde YAZMAZ ve yazamaz —
  /// müşteri "borcuma 500 ₺ vereyim" der, kalemleri ayırmaz.
  borcTahsilati,

  /// Ters kayıt (`correction`): yanlış yazılmış bir tahsilatın geri alınması. Tutarı NEGATİFTİR.
  duzeltme;

  /// Satırda görünen kısa etiket. Bugünün siparişinde etiket YOKTUR — olağan hâl rozet
  /// taşımaz, yoksa liste rozet denizine döner ve istisna göze batmaz.
  String? get etiket => switch (this) {
        TahsilatKaynagi.gununSiparisi => null,
        TahsilatKaynagi.gecmisSiparis => 'Geçmiş sipariş',
        TahsilatKaynagi.borcTahsilati => 'Borç tahsilatı',
        TahsilatKaynagi.duzeltme => 'Düzeltme',
      };
}

/// Bir defter kaydının tahsilat kaynağını çözer — SAF KURAL, doğrudan testlenir.
///
/// [siparisGunu] bağlı siparişin `occurred_at`i (UTC ISO); sipariş bulunamazsa null. Sipariş
/// kaydı YOKKEN "bugünün siparişi" demek, olmayan bir cirodan söz etmektir — o yüzden
/// bulunamayan sipariş [TahsilatKaynagi.gecmisSiparis] sayılır: bilinmezlikte bugüne yazmayan
/// taraf seçilir (deponun "belirsizlikte kapanan tarafı seç" ilkesinin para karşılığı).
TahsilatKaynagi tahsilatKaynagi({
  required String entryType,
  required String? relatedOrderId,
  required String? siparisGunu,
  required DateTime localDate,
}) {
  if (entryType == 'correction') return TahsilatKaynagi.duzeltme;
  if (relatedOrderId == null) return TahsilatKaynagi.borcTahsilati;
  if (siparisGunu != null && ayniTrGunIso(siparisGunu, localDate)) {
    return TahsilatKaynagi.gununSiparisi;
  }
  return TahsilatKaynagi.gecmisSiparis;
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
    this.kaynak = TahsilatKaynagi.gununSiparisi,
  });

  /// Paranın hangi işten geldiği — satırdaki rozet ve "eski borç tahsilatı" toplamı bundan çıkar.
  final TahsilatKaynagi kaynak;

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
///
/// ÜÇ TAHSİLAT KOVASI + BİR GİDER KOVASI (2026-08-25). Ayrım pazarlıksız: [nakit] "bugün nakit
/// olarak ne TAHSİL ETTİM", [netNakit] ise "kasada ne KALMALI". Tek bir sayı ikisine birden cevap
/// veremez ve bu depoda aynı sayıyı iki anlamda taşımak gün sonu tanımında üç kez ayrışma üretti.
class KasaOzeti {
  KasaOzeti({
    required this.nakit,
    required this.kart,
    required this.havale,
    this.gider = 0,
  });

  /// Nakit TAHSİLAT (gider HARİÇ).
  final int nakit;
  final int kart;
  final int havale;

  /// Kasadan ÇIKAN nakit — saha gideri (benzin, tamir…), POZİTİF kuruş. İptal edilmiş giderler
  /// ters satırla netlenmiş hâlde gelir, yani bu sayı "fiilen çıkan"dır.
  ///
  /// [toplam]IN İÇİNDE DEĞİLDİR (iskontoyla aynı kural): toplam bir TAHSİLAT toplamıdır ve
  /// gider bir tahsilat değildir. Kasa mutabakatına [netNakit] üzerinden girer.
  final int gider;

  /// Günün TAHSİLAT toplamı (üç ödeme türü). Gider bunun içinde DEĞİLDİR.
  int get toplam => nakit + kart + havale;

  /// Kasada FİİLEN kalması gereken nakit: tahsil edilen nakit − gider.
  ///
  /// Kapanış/devir mutabakatı BU rakamdan türer, [nakit]ten değil — sayılan para giderden
  /// sonraki paradır ve gider düşülmezse her gider kalıcı bir "EKSİK" olarak arşive donardı.
  int get netNakit => nakit - gider;
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
