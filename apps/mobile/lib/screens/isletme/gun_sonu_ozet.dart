// GÜN SONU ekranının VERİ katmanı — ekrandan bağımsız, saf async testle sınanır.
//
// Ekran hiçbir para formülü yazmaz: kasa/borç `DayEndRepository`den, kapanış ve arşiv
// `DayClosingRepository`den gelir. Buradaki işlev yalnız read-model'leri tek çağrıda toplamak,
// böylece ekranın gösterdiği rakam ile arşive donan rakam AYNI koddan çıkmak zorunda kalsın
// (paralel hesap yasağı — DECISIONS Dilim 4).

import '../../data/app_database.dart';
import '../../data/tr_gun.dart';
import '../../repo/cash_handover_repository.dart';
import '../../repo/day_closing_repository.dart';
import '../../repo/day_end_repository.dart';

export '../../data/tr_gun.dart' show bugunTrDuzeltilmis;

/// Bugünün TR takvim günü (00:00). Kural `data/tr_gun.dart`ta TEK yerde durur (#9).
///
/// ⚠️ CİHAZ SAATİNDEN türer. Para hesabının gün sınırı için [bugunTrDuzeltilmis] KULLANILMALI:
/// telefon 40 dk ileriyken saat 23:40'ta bu fonksiyon YARINI döndürür ama kayıt (düzeltilmiş
/// saatle yazıldığı için) BUGÜNE düşer — ekran ile defter farklı gün konuşur (#4). Repo katmanı
/// artık düzeltilmiş saati kullanıyor; bu imza yalnız saat düzeltmesine erişimi olmayan sync
/// çağrılar için duruyor.
DateTime bugunTr({DateTime? now}) => trGunu(now ?? DateTime.now());

/// Gün geneli özet: kasa + açık borç.
///
/// ⚠️ [GunSonuGorunumu] BUNU TAŞIMAZ (bkz. [GunBorcOzeti]). Serbest bir read-model olarak durur:
/// gün genelinin kasasını tek çağrıda isteyen saf çağrılar (testler, raporlama) içindir.
class GunSonuOzet {
  GunSonuOzet({required this.kasa, required this.borc});
  final KasaOzeti kasa;
  final BorcDurumu borc;
}

Future<GunSonuOzet> gunSonuOzeti(AppDatabase db, DateTime localDate) async {
  final repo = DayEndRepository(db);
  final kasa = await repo.kasaOzeti(localDate);
  final borc = await repo.borcDurumu();
  return GunSonuOzet(kasa: kasa, borc: borc);
}

/// [GunSonuGorunumu.ozet]in tipi: yalnız BORÇ taşır, gün geneli kasa TAŞIMAZ.
///
/// NEDEN AYRI BİR TİP (üçüncü inceleme #3b): burada bir zamanlar [GunSonuOzet] duruyordu ve
/// `ozet.kasa` GÜN GENELİ bir [KasaOzeti]ydi — hiçbir yerde çizilmiyordu ama `kapsam.kasa`nın bir
/// tanımlayıcı yanında bekliyordu. `g.ozet.kasa` yazmak DERLENİYOR ve kurye sekmesinin başlığının
/// altına sessizce GÜN toplamlarını basıyordu: yanlış rakam, doğru görünen bir yerde. Kapsamın
/// kasası TEK yerden gelmeli — [GunSonuGorunumu.kapsam]. Tipi daraltmak o yazımı derleme
/// zamanında imkânsız kılar; yorum kılmazdı.
///
/// Alan adı `ozet` KALDI (ekran `g.ozet.borc` yazıyor): tuzağı kapatmak için ekranların
/// değişmesi gerekmiyordu.
class GunBorcOzeti {
  GunBorcOzeti({required this.borc});
  final BorcDurumu borc;
}

/// Seçili kapsamın (gün ya da tek kurye) kasa özeti + teslimat sayısı + açık sipariş sayısı.
class KapsamOzeti {
  KapsamOzeti({
    required this.kasa,
    required this.teslimat,
    required this.acikSiparis,
    this.iskonto = 0,
  });

  final KasaOzeti kasa;
  final int teslimat;
  final int acikSiparis;

  /// Kapıda kırılan toplam (pozitif kuruş). [kasa]nın İÇİNDE DEĞİLDİR — kasaya hiç girmedi.
  final int iskonto;
}

/// KAPSAM özeti. [kuryeId] null ise gün geneli.
///
/// Kurye kırılımı dahil TÜM para/teslimat rakamları `DayEndRepository`ye delege edilir; bu
/// dosyada ikinci bir toplama yapılmaz. Yalnız "açık sipariş" sayısı burada sorgulanır — o bir
/// kapatma kapısıdır, para değil.
Future<KapsamOzeti> kapsamOzeti(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
}) async {
  final repo = DayEndRepository(db);
  return KapsamOzeti(
    kasa: await repo.kasaOzeti(localDate, userId: kuryeId),
    teslimat: await repo.teslimatSayisi(localDate, userId: kuryeId),
    iskonto: await repo.iskontoOzeti(localDate, userId: kuryeId),
    acikSiparis: await acikSiparisSayisi(db, localDate, kuryeId: kuryeId),
  );
}

/// O günün AÇIK sipariş sayısı (kapsamla sınırlı). Kapatma bu sayı > 0 iken ENGELLENİR:
/// kapanmış bir gün açık bir siparişi gizlerdi.
Future<int> acikSiparisSayisi(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
}) async {
  // İki ayrı `where` çağrısı drift'te AND ile birleşir — ekran dosyasına `package:drift`
  // operatör eklentisini import etmemek için bilinçli tercih.
  final sorgu = db.select(db.orders)
    ..where((t) => t.deletedAt.isNull())
    ..where((t) => t.status.equals('open'));
  if (kuryeId != null) {
    sorgu.where((t) => t.assignedUserId.equals(kuryeId));
  }
  final satirlar = await sorgu.get();
  return satirlar.where((o) => ayniTrGun(o.occurredAt, localDate)).length;
}

/// occurred_at (UTC ISO) verilen TR yerel takvim gününe mi düşüyor?
/// Kural `data/tr_gun.dart`ta TEK yerde durur (#9); bu ad `order_queries.dart` da dahil çağrı
/// yerlerini kırmamak için korunuyor.
bool ayniTrGun(String iso, DateTime localDate) => ayniTrGunIso(iso, localDate);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ekranın tek atışta ihtiyaç duyduğu her şey
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Özet + kapsam + kilit durumu. Tek future ile yüklenir; kapatma sonrası tazelenir.
class GunSonuGorunumu {
  GunSonuGorunumu({
    required this.ozet,
    required this.kapsam,
    required this.gunKapali,
    required this.kapsamKapali,
    this.acikKuryeAdlari = const [],
    this.gunEngeli = false,
    this.araTahsilatlar = const [],
    this.gunKapanislari = const [],
    this.araTahsilatMumkun = false,
    this.araTahsilatToplamiKurus = 0,
    this.senkron = const SenkronTazeligi(),
  });

  /// Gün geneli BORÇ (yalnız borç — bkz. [GunBorcOzeti]).
  final GunBorcOzeti ozet;

  final KapsamOzeti kapsam;

  /// Gün hesabı kapatıldıysa artık HİÇBİR kapsam açılmaz (tasarım: "tüm hesaplar kilitli").
  final bool gunKapali;

  final bool kapsamKapali;

  /// Bugün hesabı HENÜZ KAPANMAMIŞ aktif kuryelerin adları (ada göre sıralı).
  /// Tasarımdaki `acikKuryeler` — gün engelinin metnini bu liste yazar.
  final List<String> acikKuryeAdlari;

  /// Tasarım `gunEngel` (s-gunsonu.jsx): gün hesabı, kuryelerin BİR KISMI kapanmışken
  /// kapatılamaz. Hiç kimse kapatmamışken engel YOKtur (tek kişilik bayi ya da kurye
  /// hesaplarını hiç kullanmayan bayi gün sonunu doğrudan kapatabilmeli); hepsi
  /// kapanmışsa da engel yoktur. Engel yalnız YARIM KALMIŞ devirde çıkar — kapanan gün
  /// açık bir kurye kasasını mutabakatsız bırakırdı.
  final bool gunEngeli;

  /// O güne düşen ARA tahsilatlar (eskiden yeniye), kapsamla sınırlı. Kapanışa bağlı devirler
  /// buraya GİRMEZ — onlar hesabı kapatırken teslim edilen kasadır, gün içi tahsilat değil.
  final List<AraTahsilatKaydi> araTahsilatlar;

  /// O güne düşen kapanış kayıtları (yeni üstte).
  ///
  /// Burada bir zamanlar bir de `arsiv` (tüm geçmiş, 50 satır) duruyordu: her yüklemede,
  /// her kapsam değişiminde ve her yenilemede `watchArchive().first` ile çekiliyor ve `lib`
  /// ile `test` genelinde HİÇ okunmuyordu. Arşivi gerçekten çizen ekran onu kendi
  /// `DayClosingRepository.watchArchive()` akışından alır — görünüm nesnesinin taşıması
  /// gereken tek liste SEÇİLİ GÜNÜNKÜDÜR.
  final List<DayClosing> gunKapanislari;

  /// Ara tahsilat düğmesi ÇİZİLEBİLİR mi (aktif kurye var + gün henüz kapanmadı + gün bugün).
  ///
  /// Kararı burada veriyoruz, ekranda değil: tek kişilik bayide "kuryeden ara tahsilat" diye bir
  /// kavram YOKTUR (patron parayı zaten cebinde taşır) ve bu koşulu her ekranın kendi başına
  /// türetmesi, koşul değiştiğinde bir ekranın geride kalması demekti.
  final bool araTahsilatMumkun;

  /// Cihazın sunucuyla son teması. Kapanış/ara tahsilat sheet'i bunu gösterir: bu ekrandaki
  /// beklenen nakit YEREL veriden çıkar ve başka bir cihazda alınmış bir ara tahsilat henüz
  /// inmemiş olabilir.
  final SenkronTazeligi senkron;

  /// [araTahsilatlar] LİSTESİNİN toplamı — REPO hesaplar, ekran kendi listesini toplamaz.
  ///
  /// ⚠️ BU KAPANIŞ ARİTMETİĞİ DEĞİLDİR ve oraya sokulamaz. Özet kartındaki "Ara tahsilat
  /// toplamı · N tahsilat" satırı içindir; kapanış devirleri bu kümede YOKTUR. Kapanışın üç
  /// sayısı TEK yerden gelir: `DayClosingRepository.onizle()` → `gunNakitKurus` · `dusulenKurus`
  /// (+`dusulenKalem`) · `expectedCashKurus`.
  ///
  /// Getter DEĞİL alan olmasının sebebi: bir zamanlar buradaki türetilmiş getter'lar
  /// (`kalanNakitKurus`, `araTahsilatKurus`) kapanış aritmetiğine yakın durup ondan farklı
  /// hesaplıyordu ve sheet'i bir kez fiilen yanlış besledi (inceleme #7).
  final int araTahsilatToplamiKurus;
}

/// Seçili GÜNÜN tam görünümü. [localDate] GEÇMİŞ bir gün olabilir — tüm süzgeçler bu tarihi
/// kullanır, hiçbiri "bugün" varsaymaz. Tek istisna [GunSonuOzet.borc]: müşteri bakiyeleri ANLIK
/// durumdur (`customers.balance_kurus`), geçmişe sarılamaz; geçmiş gün ekranı borç kartını
/// göstermemelidir.
Future<GunSonuGorunumu> gunSonuGorunumu(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
}) async {
  final kapanislar = DayClosingRepository(db);
  final gunKapali = await kapanislar.kapaliMi(ClosingScope.day, localDate: localDate);
  final kuryeKapali = kuryeId == null
      ? false
      : await kapanislar.kapaliMi(ClosingScope.courier,
          userId: kuryeId, localDate: localDate);

  final acikKuryeler = await acikKuryeAdlari(db, localDate);
  final aktifSayi = await _aktifKuryeSayisi(db);
  final bugun = localDate == await bugunTrDuzeltilmis(db);

  return GunSonuGorunumu(
    ozet: GunBorcOzeti(borc: await DayEndRepository(db).borcDurumu()),
    kapsam: await kapsamOzeti(db, localDate, kuryeId: kuryeId),
    gunKapali: gunKapali,
    kapsamKapali: gunKapali || kuryeKapali,
    gunKapanislari: await kapanislar.gununKapanislari(localDate),
    araTahsilatlar:
        await CashHandoverRepository(db).araTahsilatlar(localDate, kuryeId: kuryeId),
    araTahsilatToplamiKurus:
        await CashHandoverRepository(db).araTahsilatToplami(localDate, kuryeId: kuryeId),
    // Geçmiş gün için de FALSE: dünün kasasını bugün "ara" tahsilat diye almak, parayı dünün
    // hesabına yazmak olurdu.
    araTahsilatMumkun: bugun && !gunKapali && aktifSayi > 0,
    senkron: await senkronTazeligi(db),
    acikKuryeAdlari: acikKuryeler,
    gunEngeli: kuryeId == null &&
        !gunKapali &&
        acikKuryeler.isNotEmpty &&
        acikKuryeler.length < aktifSayi,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Senkron tazeliği (kullanıcı kararı 2026-08-06 · lead onayı: çevrimdışı kurye = BİLİNÇLİ BORÇ)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Kopukluğun "kısa" sayılmaktan çıktığı süre. Tur aralığı 2 dakikadır (`SyncService.start`);
/// beş tur üst üste kaçmışsa bu artık bodrumda geçen bir dakika değildir.
const Duration kSenkronBayatlikEsigi = Duration(minutes: 10);

/// Cihazın sunucuyla EN SON TEMASI. Kurye kapanışı/ara tahsilat sheet'i bunu gösterir.
///
/// NEDEN GEREKLİ: beklenen nakit YEREL `cash_handovers`tan hesaplanır. Patron kendi telefonundan
/// ara tahsilat alır ve kuryenin telefonu çevrimdışıysa, kurye ekranında ŞİŞİK bir beklenen tutar
/// görür; kendi hesabını o hâlde kapatırsa arşive gerçek dışı bir rakam donar (append-only →
/// kalıcı). Kapanışı sunucu doğrulamasına bağlamak onu çevrimiçi-zorunlu yapardı ve BRIEF'in
/// "internetsiz TAM çalışır" çizgisini keserdi; bunun yerine borç BİLİNÇLİ tutulup kullanıcıya
/// GÖRÜNÜR kılınıyor.
///
/// NEYİ ÖLÇTÜĞÜ (etiket bundan fazlasını İDDİA ETMEMELİ): kaynak `sync_meta.lastServerTimeIso`,
/// yani sunucudan alınan SON YANITTAKİ sunucu saati. `SyncEngine.pull()` bunu her turda yazar ve
/// `AppendServerTime` middleware'i her API yanıtına `server_time` eklediği için pull turu da
/// besler (push'un tek başına yetmediği yer burasıydı: boş kuyrukta push HTTP'ye hiç çıkmaz).
///
/// Bu "SON TEMAS"tır, "son EKSİKSİZ uygulanmış tur" DEĞİL: damga satırlar uygulanmadan ÖNCE
/// yazılır, yani bazı satırlar ayrıştırılamayıp atlanmışsa tur başarısız sayılsa bile bu değer
/// ilerler. Eksiksizliği ölçmek kalıcı bir alan ister (şema işi). Ekranda "son senkron" değil
/// "sunucuya son ulaşma" dili kullanılmalı — tazelik göstergesinin yalanı, göstergesizlikten
/// kötüdür.
class SenkronTazeligi {
  const SenkronTazeligi({this.sonTemasUtc, this.gecenSure});

  /// Sunucu saatiyle son temas anı (UTC). Hiç senkron olmadıysa null.
  final DateTime? sonTemasUtc;

  /// O andan beri geçen süre. Hiç senkron olmadıysa null.
  final Duration? gecenSure;

  /// Cihaz sunucuya HİÇ ulaşmadı (yeni kurulum ya da kalıcı çevrimdışı).
  bool get hicTemasYok => sonTemasUtc == null;

  /// Uyarı gösterilmeli mi? Hiç temas olmaması da bayattır — bilinmezlik, tazelik değildir.
  bool get bayat => gecenSure == null || gecenSure! >= kSenkronBayatlikEsigi;
}

/// [SenkronTazeligi] okur. [simdi] test içindir; verilmezse cihaz saati kullanılır.
///
/// Geçen süre DÜZELTİLMİŞ saatle ölçülür (`serverTimeOffsetMs`): esnafın telefon saati yanlış
/// olabilir ve offset son temasla AYNI anda hesaplandığı için ikisinin farkı gerçek geçen süreyi
/// verir. Sonuç negatife düşerse SIFIRA kırpılır — cihaz saati geriye atlamışsa "−3 dk önce"
/// yazmak, bilmediğimizi bildiğimiz sanmaktır.
Future<SenkronTazeligi> senkronTazeligi(AppDatabase db, {DateTime? simdi}) async {
  final meta = await db.syncState();
  final iso = meta.lastServerTimeIso;
  final sonTemas = iso == null ? null : DateTime.tryParse(iso);
  if (sonTemas == null) return const SenkronTazeligi();

  final duzeltilmisSimdi =
      (simdi ?? DateTime.now()).toUtc().add(Duration(milliseconds: meta.serverTimeOffsetMs));
  final gecen = duzeltilmisSimdi.difference(sonTemas.toUtc());
  return SenkronTazeligi(
    sonTemasUtc: sonTemas.toUtc(),
    gecenSure: gecen.isNegative ? Duration.zero : gecen,
  );
}

/// [localDate] gününde HİÇ kayıt var mı? (sipariş · kasaya dokunan defter hareketi · kapanış ·
/// kasa devri). Geçmiş gün ekranı boş durumu buna göre çizer — "0 ₺" ile "o gün çalışılmadı"
/// aynı şey değildir ve sıfırlarla dolu bir kart bayiyi kasa eksik sandırır.
Future<bool> gunKayitVarMi(AppDatabase db, DateTime localDate) async {
  final siparisler = await (db.select(db.orders)..where((t) => t.deletedAt.isNull())).get();
  if (siparisler.any((o) => ayniTrGun(o.occurredAt, localDate))) return true;

  final hareketler = await db.select(db.ledgerEntries).get();
  if (hareketler.any((e) => ayniTrGun(e.occurredAt, localDate))) return true;

  final kapanislar = await DayClosingRepository(db).gununKapanislari(localDate);
  if (kapanislar.isNotEmpty) return true;

  final devirler = await db.select(db.cashHandovers).get();
  return devirler.any((h) => ayniTrGun(h.occurredAt, localDate));
}

/// Aktif kuryelerden bugün hesabı KAPANMAMIŞ olanların adları.
Future<List<String>> acikKuryeAdlari(AppDatabase db, DateTime localDate) async {
  final kapanislar = DayClosingRepository(db);
  final kuryeler = await _aktifKuryeler(db);
  final acik = <String>[];
  for (final k in kuryeler) {
    final kapali = await kapanislar.kapaliMi(ClosingScope.courier,
        userId: k.id, localDate: localDate);
    if (!kapali) acik.add(k.name);
  }
  return acik;
}

/// Aktif kuryeler, ada göre. Sıralama SQL'de değil Dart'ta yapılır: bu dosya `package:drift`i
/// import etmiyor (ekran katmanı sözleşmesi) ve `OrderingTerm` oradan gelir.
Future<List<User>> _aktifKuryeler(AppDatabase db) async {
  final sorgu = db.select(db.users)
    ..where((t) => t.role.equals('kurye'))
    ..where((t) => t.status.equals('active'));
  final satirlar = await sorgu.get();
  satirlar.sort((a, b) => a.name.compareTo(b.name));
  return satirlar;
}

Future<int> _aktifKuryeSayisi(AppDatabase db) async => (await _aktifKuryeler(db)).length;
