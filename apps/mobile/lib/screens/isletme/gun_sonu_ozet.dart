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
import '../../repo/gun_veresiye_repository.dart';
import '../../repo/islem_sahibi.dart';
import '../../repo/kapanmamis_gunler.dart';

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
    this.veresiye = 0,
    this.eskiBorcTahsilati = 0,
  });

  final KasaOzeti kasa;
  final int teslimat;
  final int acikSiparis;

  /// Kapıda kırılan toplam (pozitif kuruş). [kasa]nın İÇİNDE DEĞİLDİR — kasaya hiç girmedi.
  final int iskonto;

  /// BUGÜN yazılan veresiye (pozitif kuruş). [kasa]nın İÇİNDE DEĞİLDİR — tanımı gereği kasaya
  /// girmeyen paradır (saha isteği 2026-08-18).
  ///
  /// "Açık Veresiye" kartıyla KARIŞTIRILMAMALI: o kart anlık toplam bakiyeyi (aylardır birikmiş
  /// borç) gösterir, bu sayı yalnız bugüne aittir. İkisini tek satırda toplamak, bugünün işini
  /// geçmişin yığınında görünmez kılan tam olarak o hataydı.
  final int veresiye;

  /// Kasaya giren ama BUGÜNKÜ SATIŞTAN gelmeyen tutar (pozitif kuruş) — eski borç kapatmaları
  /// ve geçmiş siparişlerin tahsilatı. [kasa]NIN İÇİNDEDİR, ondan düşülmez.
  ///
  /// Ayrı durur çünkü "kasaya ne girdi" ile "bugün ne sattım" farklı sorulardır ve bir tek
  /// rakam ikisine birden cevap veremez.
  final int eskiBorcTahsilati;
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
  String? haric,
}) async {
  final repo = DayEndRepository(db);
  // ALTI OKUMA PARALEL: hiçbiri diğerinin sonucuna bağlı değil ve `await`leri sıraya dizmek
  // ekranın ilk çizimini altı gidiş-dönüş kadar geciktiriyordu. Gün özeti `FutureBuilder` ile
  // TEK ATIŞ yüklenir — o future uzadıkça ekran iskelet kalır. (2026-08-18'de iki okuma daha
  // eklenince sınır göründü: mevcut widget testleri "dört tur bekle" varsayımıyla yazılmıştı
  // ve future yetişemedi. Testin varsayımını büyütmek yerine işi kısaltmak doğrusu.)
  final sonuc = await Future.wait<Object>([
    repo.kasaOzeti(localDate, userId: kuryeId, haric: haric),
    repo.teslimatSayisi(localDate, userId: kuryeId, haric: haric),
    repo.iskontoOzeti(localDate, userId: kuryeId, haric: haric),
    GunVeresiyeRepository(db).toplam(localDate, userId: kuryeId, haric: haric),
    repo.eskiBorcTahsilati(localDate, userId: kuryeId, haric: haric),
    acikSiparisSayisi(db, localDate, kuryeId: kuryeId, haric: haric),
  ]);

  return KapsamOzeti(
    kasa: sonuc[0] as KasaOzeti,
    teslimat: sonuc[1] as int,
    iskonto: sonuc[2] as int,
    veresiye: sonuc[3] as int,
    eskiBorcTahsilati: sonuc[4] as int,
    acikSiparis: sonuc[5] as int,
  );
}

/// O günün AÇIK sipariş sayısı (kapsamla sınırlı). Kapatma bu sayı > 0 iken ENGELLENİR:
/// kapanmış bir gün açık bir siparişi gizlerdi.
Future<int> acikSiparisSayisi(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
  String? haric,
}) async {
  // İki ayrı `where` çağrısı drift'te AND ile birleşir — ekran dosyasına `package:drift`
  // operatör eklentisini import etmemek için bilinçli tercih.
  final sorgu = db.select(db.orders)
    ..where((t) => t.deletedAt.isNull())
    ..where((t) => t.status.equals('open'));
  final satirlar = await sorgu.get();
  // KAPSAM SÜZGECİ DART TARAFINDA: gün süzgeci zaten burada koşuyor (satırlar toptan çekiliyor)
  // ve bu dosya `package:drift` import ETMİYOR (ekran katmanı sözleşmesi).
  //
  // AÇIK SİPARİŞTE SAHİP = ATANANDIR: henüz teslim edilmemiş bir siparişin "teslim edeni" yoktur
  // ve olamaz. `delivered_by_user_id` boş olduğu için [kapsamaDusuyor] zaten atamaya bakar;
  // burada açıkça atama geçilmesi, okuyanın "acaba teslim eden mi" diye durmaması içindir.
  return satirlar
      .where((o) => ayniTrGun(o.occurredAt, localDate))
      .where((o) => kapsamaDusuyor(o.assignedUserId, userId: kuryeId, haric: haric))
      .length;
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
    this.bugunMu = true,
    this.kayitVar = true,
    this.beklenenNakit,
    this.senkron = const SenkronTazeligi(),
    this.geriAlinmisKapanislar = const {},
  });

  /// Görüntülenen gün BUGÜN mü (düzeltilmiş sunucu saatine göre)?
  ///
  /// Gün Özeti ekranı 2026-08-25'te gün gezinmesi kazandı; artık AYNI ekran hem bugünü hem
  /// geçmişi gösteriyor ve yazma yolları buna göre kapanıyor: ara tahsilat, gider ekleme ve
  /// SAYIMLI kapanış yalnız bugün mümkündür. Geçmiş bir güne bugünün parasını yazmak, kapanmış
  /// ya da kapanmaya hazır bir günün kasasını geriye dönük değiştirmek olurdu.
  ///
  /// Anlık bakiye gösteren "Açık Veresiye" kartı da buna bağlıdır: `customers.balance_kurus` ŞU
  /// ANIN durumudur, geçmişe sarılamaz — geçmiş bir günde çizmek, o günün borcu sanılacak bir
  /// rakamı basmak olurdu.
  final bool bugunMu;

  /// O GÜNDE (kapsamdan bağımsız) herhangi bir kayıt var mı? "0 ₺" ile "o gün çalışılmadı" aynı
  /// şey değildir ve sıfırlarla dolu bir kasa kartı bayiyi kasa eksik sandırır.
  ///
  /// Görünümün İÇİNDE taşınır, ekranın ikinci bir future'ından değil: ayrı olsaydı gövde bir kare
  /// boyunca kartları çizip sonra boş duruma atlardı (ya da tersi) — geçmiş bir günde bu titreme,
  /// bayiye rakamların oynadığını düşündürürdü.
  final bool kayitVar;

  /// KASADA OLMASI GEREKEN nakit — ekranın en üstündeki iri rakam.
  ///
  /// `DayClosingRepository.onizle`den OLDUĞU GİBİ alınır: kapanış sheet'inde yazan tutarla aynı
  /// koddan çıkmak zorunda, yoksa bayi kapatmaya bastığında başka bir rakam görür.
  ///
  /// NULL = BU KAPSAMDA TANIMLI DEĞİL, "sıfır" değil. `day_closings` yalnız iki kapsam tanır
  /// (gün · kurye); "Elemanlar" ve patronun "Kendi işlemlerim" kapsamları birer okuma
  /// kapsamıdır ve orada "kasada olması gereken" diye bir büyüklük yoktur — patronun kendi
  /// topladığı para zaten kasanın kendisidir. Sıfır yazmak, olmayan bir mutabakat iddia etmek
  /// olurdu; ekran o kapsamlarda başlığı da rakamı da değiştirir.
  final int? beklenenNakit;

  /// GERİ ALINMIŞ kapanışların id'leri (2026-08-18).
  ///
  /// Görünümün İÇİNDE taşınır, ekranın ikinci bir sorgusundan gelmez: [gunKapanislari] ile
  /// AYNI ANDA okunmalı, yoksa liste ile rozet bir kare boyunca ayrışır ve kullanıcı geri
  /// aldığı kapanışı hâlâ geçerli görür.
  final Set<String> geriAlinmisKapanislar;

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
  String? haric,
  bool devirKapsami = false,
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

  // BEKLENEN NAKİT — ekranın en üstündeki iri rakam. HER KAPSAMDA TANIMLI DEĞİLDİR ve
  // tanımsızken null kalır (bkz. [GunSonuGorunumu.beklenenNakit]). Kapsam süzgeci burada
  // `ClosingScope`a çevrilir; "Elemanlar" ve patronun "Kendi işlemlerim" kapsamları birer OKUMA
  // kapsamıdır, `day_closings` onları hiç tanımaz.
  //
  // FORMÜL BURADA YAZILMAZ, `DayClosingRepository.onizle`den ALINIR: kapanış sheet'inde yazan
  // rakam ile ekranın en üstündeki rakam AYNI koddan çıkmak zorunda. İkisini ayrı hesaplamak,
  // bu depoda gün sonu tanımında üç kez ayrışma üreten hata sınıfının ta kendisi.
  final beklenen = haric != null || (kuryeId != null && !devirKapsami)
      ? null
      : (await kapanislar.onizle(
          kuryeId == null ? ClosingScope.day : ClosingScope.courier,
          userId: kuryeId,
          localDate: localDate,
        ));

  return GunSonuGorunumu(
    ozet: GunBorcOzeti(borc: await DayEndRepository(db).borcDurumu()),
    kapsam: await kapsamOzeti(db, localDate, kuryeId: kuryeId, haric: haric),
    gunKapali: gunKapali,
    kapsamKapali: gunKapali || kuryeKapali,
    gunKapanislari: await kapanislar.gununKapanislari(localDate),
    geriAlinmisKapanislar: await kapanislar.geriAlinmisIdler(),
    araTahsilatlar:
        await CashHandoverRepository(db).araTahsilatlar(localDate, kuryeId: kuryeId),
    araTahsilatToplamiKurus:
        await CashHandoverRepository(db).araTahsilatToplami(localDate, kuryeId: kuryeId),
    // Geçmiş gün için de FALSE: dünün kasasını bugün "ara" tahsilat diye almak, parayı dünün
    // hesabına yazmak olurdu.
    araTahsilatMumkun: bugun && !gunKapali && aktifSayi > 0,
    bugunMu: bugun,
    kayitVar: await gunKayitVarMi(db, localDate),
    beklenenNakit: beklenen?.expectedCashKurus,
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
/// ⚠️ TANIM BURADA DEĞİL: `KapanmamisGunlerRepository.hareketliGunler()` içinde. Bu imza
/// çağrı yerlerini kırmamak için duruyor ve oraya DELEGE eder.
///
/// NEDEN TAŞINDI (2026-08-21): "kapanmamış günler" taraması aynı soruyu 14 gün için soruyor ve
/// kendi kopyasını yazsaydı iki tanım ayrışırdı — bayi hareketsiz bir pazar günü için "gün
/// kapatmadınız" uyarısı alır ya da tersine gerçekten çalışılmış bir gün listeden düşerdi.
Future<bool> gunKayitVarMi(AppDatabase db, DateTime localDate) async =>
    (await KapanmamisGunlerRepository(db).hareketliGunler())
        .contains(trGunAnahtari(localDate));

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
