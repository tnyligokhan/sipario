import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../data/tr_gun.dart';
import 'cash_handover_repository.dart';
import 'day_end_repository.dart';

// KAPANIŞI GERİ ALMA yüzeyi buradan ayrıldı — 500 satır sınırı. AYNI KÜTÜPHANEDİR (`part`):
// gerekçe o dosyanın başlığında.
part 'day_closing_geri_alma.dart';

/// Kapanış kapsamı: günün tamamı ya da tek kurye (tasarım: "Tümü" sekmesi vs kurye sekmesi).
enum ClosingScope { day, courier }

/// [ClosingOnizleme.dusulenKurus]un NE OLDUĞU. Anlam DEĞERLE BİRLİKTE taşınır; ekran kapsamdan
/// çıkarım YAPMAZ.
///
/// Bu vardiyada dört kez ısırılan kalıp tam olarak buydu: `kalanNakitKurus`, `araTahsilatKurus`,
/// `teslimEdilenKurus`... hepsi "bağlama göre doğru" sayılardı ve yanlış bağlamda kullanıldılar.
/// Sayının yanında ne olduğunu söyleyen bir etiket taşımak, o hatayı derleme zamanına çeker.
enum DusulenKalem {
  /// GÜN kapsamı: kuryelerin cebindeki paranın O GÜNKÜ NET DEĞİŞİMİ — yani bugün toplayıp henüz
  /// teslim etmedikleri. NEGATİF olabilir: kurye dünün parasını bugün teslim ettiyse kasaya
  /// günün nakdinden fazlası girer. Ekran işareti buna göre göstermeli.
  kuryelerdeKalan,

  /// KURYE kapsamı: o kuryenin bu pencerede patrona teslim ettiği para.
  teslimEdilen,
}

/// Gün sonu KAPANIŞI (tasarım: "Hesabı Kapat · Kasa Devri" + "Arşiv") — APPEND-ONLY.
///
/// Faz 3'te gün sonu salt-okunur bir read-model'di; tasarım kalıcı bir kapanış istiyor: kapatılan
/// hesap kilitlenir ve arşivde kuruşu kuruşuna geri okunur. Kapanış özeti KAPATILDIĞI ANDAKİ
/// gerçeği dondurur — sonradan gelen geç senkron kaydı arşivi değiştirmez.
///
/// PARALEL HESAP YASAĞI (DECISIONS Dilim 4): kasa/teslimat rakamları ekranın gösterdiği ile AYNI
/// koddan gelir (`DayEndRepository`); beklenen nakit ve devir kaydı `CashHandoverRepository`'den.
/// Bu sınıf kendi başına hiçbir para formülü yazmaz, yalnız birleştirir ve dondurur.
class DayClosingRepository {
  DayClosingRepository(this.db)
      : _dayEnd = DayEndRepository(db),
        _handovers = CashHandoverRepository(db);

  final AppDatabase db;
  final DayEndRepository _dayEnd;
  final CashHandoverRepository _handovers;

  /// Arşiv listesi (yeni üstte).
  Stream<List<DayClosing>> watchArchive({int limit = 50}) => (db.select(db.dayClosings)
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
        ..limit(limit))
      .watch();

  /// GERİ ALINMIŞ kapanışların id kümesi — bir satırın hâlâ GEÇERLİ olup olmadığının tek ölçüsü.
  ///
  /// Geri alma, tabloya yazılan TERS BİR SATIRdır (`reverses_closing_id` dolu). Yani bir kapanışın
  /// "iptal edilmiş" olduğu, kendi satırında DEĞİL başka bir satırda yazar — append-only defterin
  /// doğal sonucu ([DayClosings.reversesClosingId] gerekçesi).
  Future<Set<String>> _geriAlinmisIdler() async {
    final rows = await (db.select(db.dayClosings)
          ..where((t) => t.reversesClosingId.isNotNull()))
        .get();
    return {for (final r in rows) r.reversesClosingId!};
  }

  /// Bu kapsam bugün kapatıldı mı? (Kapatılmışsa ekran kilitlenir — tasarım.)
  ///
  /// ⚠️ İKİ ELEME ŞART (2026-08-18, geri alma özelliğiyle geldi) ve ikisini de atlamak farklı
  /// biçimlerde bozar:
  ///  • GERİ ALMA SATIRLARI kapanış SAYILMAZ. Sayılsaydı geri alma işlemi günü kapatır ve
  ///    kullanıcı "geri aldım ama hâlâ kilitli" derdi — özellik kendi kendini iptal ederdi.
  ///  • GERİ ALINMIŞ KAPANIŞLAR da sayılmaz. Sayılsaydı geri almanın hiçbir görünür etkisi olmaz,
  ///    gün yine kilitli kalırdı.
  Future<bool> kapaliMi(ClosingScope scope, {String? userId, DateTime? localDate}) async {
    final date = localDate ?? await bugunTrDuzeltilmis(db);
    final rows = await _gecerliKapanislar(scope);
    return rows.any((r) =>
        r.userId == (scope == ClosingScope.courier ? userId : null) &&
        _sameTrDay(r.occurredAt, date));
  }

  /// Bir kapsamın GEÇERLİ (hâlâ ayakta) kapanış satırları — iki elemenin TEK yeri.
  ///
  /// [kapaliMi] ve [kapaliGunAnahtarlari] bunu paylaşır. Ayrı yazılsalardı "geçerli kapanış"
  /// tanımı iki kopya olurdu ve bu tanım tam olarak iki kez ısırmış bir tanımdır (geri alma
  /// satırının kendisi kapanış sanılması · geri alınmış kapanışın hâlâ kapatıyor sayılması).
  Future<List<DayClosing>> _gecerliKapanislar(ClosingScope scope) async {
    final geriAlinmis = await _geriAlinmisIdler();
    final rows = await (db.select(db.dayClosings)..where((t) => t.scope.equals(scope.name))).get();
    return rows
        .where((r) => r.reversesClosingId == null && !geriAlinmis.contains(r.id))
        .toList();
  }

  /// GÜN hesabı kapatılmış TR günlerinin anahtar kümesi (`2026-08-20` biçiminde) —
  /// `kapaliMi(ClosingScope.day, localDate: …)`ın TOPLU hâli.
  ///
  /// NEDEN TOPLU: "kapanmamış günler" taraması 14 güne kadar bakar; her gün için `kapaliMi`
  /// çağırmak aynı iki sorguyu 14 kez koşturmak demekti. Aynı kuralı paylaşırlar
  /// ([_gecerliKapanislar]), yani ikisi ASLA farklı cevap veremez.
  Future<Set<String>> kapaliGunAnahtarlari() async {
    final rows = await _gecerliKapanislar(ClosingScope.day);
    return {
      for (final r in rows)
        if (DateTime.tryParse(r.occurredAt) != null)
          trGunAnahtari(trGunu(DateTime.parse(r.occurredAt).toUtc())),
    };
  }

  /// [localDate] TR gününe düşen kapanış kayıtları (yeni üstte). Arşivin GÜN SÜZGEÇLİ hâli —
  /// geçmiş gün ekranı "o gün kim kapattı" sorusunu tüm arşivi taramadan sorabilsin diye.
  ///
  /// GERİ ALMA SATIRLARI DA DÖNER ve bu bilinçlidir: liste bir ARŞİVDİR, olan biteni anlatır.
  /// Geri alınmış kapanışı gizlemek, "5.000 ₺ teslim alındı" diye bir kaydın hiç olmamış gibi
  /// yok olması demekti — oysa olay olmuştu ve düzeltildiği de görünmeli (BRIEF: "eksik para
  /// kanıt olarak görünür kalmalı"). Hangi satırın geçersiz olduğunu [geriAlinmisIdler] söyler.
  Future<List<DayClosing>> gununKapanislari(DateTime localDate) async {
    final rows = await (db.select(db.dayClosings)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
    return rows.where((r) => _sameTrDay(r.occurredAt, localDate)).toList();
  }

  /// Ekranın "bu satır geri alınmış" rozetini çizebilmesi için — [_geriAlinmisIdler]in genel
  /// yüzeyi. Ekran kendi sorgusunu yazmaz: "geçerli kapanış" tanımı TEK yerde durmalı.
  Future<Set<String>> geriAlinmisIdler() => _geriAlinmisIdler();

  /// Kapanış ÖNİZLEMESİ — ekranın gösterdiği rakamlar. `kapat()` submit anında bunu YENİDEN çağırır,
  /// böylece gösterilen ile yazılan aynı koddan çıkar (devir önizlemesiyle aynı desen).
  ///
  /// Her kapanış olayının sorduğu soru aynıdır: **"ŞİMDİ kasaya girecek para ne kadar?"** Ama
  /// cevabın şekli kapsama göre değişir ve bu ayrım İNCELEME #1'in düzelttiği hatadır:
  ///
  ///  • **KURYE kapsamı** — beklenen = kuryenin cebindeki STOK: son kapanışından beri topladığı
  ///    eksi teslim ettiği (`CashHandoverRepository.onizle`, alttan açık pencere).
  ///  • **GÜN kapsamı** — beklenen = günün nakdi − kuryelerin O GÜNKÜ NET DEĞİŞİMİ.
  ///
  /// Gün kapsamında devir bir **İÇ TRANSFERDİR**: para kuryeden patrona geçer, işletmeden ÇIKMAZ.
  /// Teslim edilenleri düşmek işaretini kaybediyordu — kurye 10.000 toplayıp hepsini verdiğinde
  /// ekran "beklenen 0" derken patronun kasasında 10.000 vardı ve sayım "FAZLA 10.000" yazıyordu.
  /// Patron gün sonunda KASASINI sayar.
  ///
  /// İKİ ÇERÇEVE KARIŞTIRILAMAZ (ikinci inceleme): `kasa.nakit` bir AKIŞtır (takvim günü), kurye
  /// kapsamının değeri ise bir STOKtur (ömür boyu birikmiş). Gün kapsamı stoku düşerse, dünden
  /// para taşıyan kurye yüzünden beklenen negatife düşer ve arşive KALICI donar. Bu yüzden gün
  /// kapsamı akışa akış düşer: kuryelerin O GÜN topladığı eksi o gün teslim ettiği.
  ///
  /// Eşdeğer ve daha okunur ifadesi (testler bunu BAĞIMSIZ yoldan doğrular):
  /// `beklenen = patronun bugün doğrudan topladığı + bugün alınan devirlerin SAYILAN toplamı`
  /// — yani "bugün kasaya fiilen giren para".
  ///
  /// Üç sayı ARİTMETİK OLARAK KAPANIR ve ekran farkı açıklayabilsin diye üçü de taşınır:
  /// `gunNakitKurus − dusulenKurus == expectedCashKurus`. Kapanmayan bir üçlü, patronun toplamdan
  /// küçük bir rakam görüp sebebini soramaması demekti.
  Future<ClosingOnizleme> onizle(ClosingScope scope, {String? userId, DateTime? localDate}) async {
    final date = localDate ?? await bugunTrDuzeltilmis(db);
    final courierId = scope == ClosingScope.courier ? userId : null;

    final kasa = await _dayEnd.kasaOzeti(date, userId: courierId);
    final teslimat = await _dayEnd.teslimatSayisi(date, userId: courierId);
    final borc = await _dayEnd.borcDurumu();

    final handover =
        courierId != null ? await _handovers.onizle(courierId, localDate: date) : null;
    // ÇERÇEVELER AYRI ve ikisi de kendi içinde tutarlı:
    //  • KURYE kapsamı → PENCERE (son kapanıştan beri; kuryenin cebindeki gerçek STOK).
    //  • GÜN kapsamı  → TAKVİM GÜNÜ (akış). Kuryelerin STOKUNU düşmek iki çerçeveyi karıştırırdı:
    //    dünden para taşıyan kurye yüzünden beklenen negatife düşer ve arşive kalıcı donardı.
    // Bu yüzden gün kapsamı kuryelerin O GÜNKÜ NET DEĞİŞİMİNİ düşer.
    final dusulen = handover?.teslimEdilenKurus ??
        await _handovers.kuryelerinGunlukNetDegisimi(date);

    // KAYDA DONACAK KASA, beklenen nakitle AYNI ÇERÇEVEDEN gelmek ZORUNDA (üçüncü inceleme #2).
    // Kurye kapsamında `kasa` GÜN nakdini, `expectedCashKurus` PENCERE nakdini taşıyordu; arşiv
    // detayı ikisini yan yana basınca "Toplam Tahsilat 3.000 · Beklenen nakit 8.000" gibi kendi
    // içinde AÇIKLANAMAZ bir kayıt donuyordu — ve kayıt append-only.
    //
    // Kart/havale GÜN çerçevesinde kalır ve bu bilinçli bir SINIRDIR: devir yalnız NAKİT
    // üzerinedir (`CashHandoverRepository` kart penceresi hesaplamaz), kart fiziksel kasa da
    // değildir. Yine de `toplam == nakit + kart + havale` kimliği kayıt içinde TUTAR, çünkü
    // toplam bu nesneden türer — arşivi okuyan üç sayıyı toplayıp dördüncüyü bulabilir.
    final cerceveKasa = handover == null
        ? kasa
        : KasaOzeti(nakit: handover.toplananKurus, kart: kasa.kart, havale: kasa.havale);

    return ClosingOnizleme(
      kasa: kasa,
      cerceveKasa: cerceveKasa,
      deliveryCount: teslimat,
      openCreditKurus: borc.toplamAcikBorc,
      expectedCashKurus: handover?.expectedKurus ?? (kasa.nakit - dusulen),
      gunNakitKurus: cerceveKasa.nakit,
      dusulenKurus: dusulen,
      dusulenKalem: courierId != null
          ? DusulenKalem.teslimEdilen
          : DusulenKalem.kuryelerdeKalan,
      periodStartIso: handover?.periodStartIso,
    );
  }

  /// Hesabı kapat ve arşivle. [countedCashKurus] null ise nakit sayılmamıştır (fark 0 yazılır).
  ///
  /// [alsoHandover] true ve kurye kapsamı ise AYNI transaction'da bir kasa devri de yazılır ve
  /// kapanışa bağlanır: tasarımda "Hesabı Kapat" ile "Kasa Devri" tek ekrandır. Para mutabakatının
  /// defteri cash_handovers olarak KALIR; day_closings o anın ekran özetidir.
  ///
  /// ATOMİKLİK GERÇEKTİR (inceleme #3): devir çağrısı transaction'ın İÇİNDEDİR (drift iç içe
  /// `transaction`ı savepoint'e çevirir). Eskiden doc "aynı transaction" diyor ama kod devri
  /// bloğun DIŞINDA ve ÖNCESİNDE çağırıyordu; arada süreç ölürse kapanışa bağlanmamış bir devir
  /// kalıyordu ve `araTahsilatlar` onu ARA TAHSİLAT sayıyordu — kurye hesabı kapanmamış görünür,
  /// ara tahsilat toplamı şişerdi. Kayıtların ikisi de olur ya da hiçbiri olmaz.
  ///
  /// KAPANMIŞ KAPSAM REDDEDİLİR ([StateError]) — `araTahsilat()`taki kapının AYNISI (üçüncü
  /// inceleme #1). Ekran kapanmış kapsamda düğmeyi zaten gizler; bu İKİNCİ kapı, çünkü sheet
  /// açıkken senkron başka bir cihazdan gelen kapanışı indirebilir ve ekranın bildiği durum o an
  /// bayattır. İkinci kapanış aynı kurye/gün için İKİ `day_closings` + İKİ `cash_handovers`
  /// yazardı; `teslimEdilenNakit` ikisini birden sayınca gün kapsamında beklenen 10.000 yerine
  /// 20.000 çıkar, patron kasasını sayınca "EKSİK 10.000" görür ve bu append-only olarak DONARDI.
  ///
  /// CİHAZLAR ARASI YARIŞI DETERMİNİSTİK ID KAPATIR (üçüncü inceleme ①-b). Yukarıdaki kapı yalnız
  /// TEK cihazı bağlar; iki cihaz birbirinden habersiz kapatırsa ikisi de yerelde geçer. Bu yüzden
  /// hem kapanışın hem ona bağlı devrin id'si `kapanisOlayId()` ile `tenant|scope|user|TR gün`
  /// çekirdeğinden türer: aynı kapanış her cihazda AYNI satırdır.
  ///
  /// Sunucu tarafında tekillik İNDEKSİ denendi ve reddedildi — ölçüldü: kapanış sunucuya İKİ AYRI
  /// olay olarak gidiyor, indeks yalnız arşiv satırını reddediyor, para hatası aynen kalıyor ve
  /// sahipsiz kalan devir sistemin kendi kuralıyla ("kapanışa bağlı olmayan devir ARA tahsilattır")
  /// hayalet bir ARA TAHSİLATA terfi ediyordu. Deterministik id ikisini birden kapatır.
  ///
  /// ⚠️ BİLİNÇLİ BEDEL: ikinci denemenin SAYILAN tutarı hiçbir yere geçmez, İLK mutabakat kalır —
  /// sunucu 'duplicate' döner (mobilde `acked`, kuyruk kilitlenmez), yerel senkron uygulayıcısı da
  /// "yoksa ekle, asla ezme" der. İkinci sayım KAYBOLMADI, REDDEDİLDİ.
  ///
  /// `tenantCode` (sunucu sahipli, senkronla iner) HENÜZ İNMEMİŞSE id rastgeleye düşer ve bu
  /// bilinçli: kiracı ayracı olmadan `scope='day'` çekirdeği tüm bayilerde aynı uuid'yi üretirdi ve
  /// sunucuda `day_closings.id` GLOBAL primary key olduğu için ikinci bayinin kapanışı sessizce
  /// düşerdi. Koruma kaybı bugünkü davranışa dönmektir; kiracı çakışması VERİ KAYBIDIR.
  Future<String> kapat({
    required ClosingScope scope,
    String? userId,
    int? countedCashKurus,
    String? note,
    String? toUserId,
    bool alsoHandover = false,
    DateTime? localDate,
  }) async {
    if (scope == ClosingScope.courier && userId == null) {
      throw ArgumentError('Kurye kapanışında userId zorunlu');
    }
    if (scope == ClosingScope.day && userId != null) {
      throw ArgumentError('Gün kapanışında userId olamaz');
    }

    final bugun = await bugunTrDuzeltilmis(db);
    final gun = localDate ?? bugun;

    // KAPI, KAPATILAN GÜNE sorulur ("bugün"e değil): geçmiş bir günü kapatan çağrı da o günün
    // kapanışına takılmalı, yoksa dün iki kez kapatılabilirdi.
    if (await kapaliMi(ClosingScope.day, localDate: gun)) {
      throw StateError('Gün hesabı kapandı; yeniden kapatılamaz.');
    }
    if (scope == ClosingScope.courier &&
        await kapaliMi(ClosingScope.courier, userId: userId, localDate: gun)) {
      throw StateError('Bu kuryenin hesabı kapandı; yeniden kapatılamaz.');
    }

    final on = await onizle(scope, userId: userId, localDate: localDate);
    final meta = await db.syncState();
    final device = meta.deviceId;

    // GEÇMİŞ GÜN KAPANIŞI O GÜNE DAMGALANIR (inceleme F3). `kapaliMi` ve `gununKapanislari`
    // `occurred_at`in TR gününe bakıyor; kaydı "şimdi"ye damgalarsak dünü kapatan kapanış dünde
    // GÖRÜNMEZ — gün kapalı sayılmaz, arşivde yanlış güne düşer. Damga o günün SON anıdır:
    // olayın gerçek yazım anı `device_id` + outbox sırasında zaten duruyor, kaybolmuyor.
    final simdi = correctedNowIso(meta.serverTimeOffsetMs);
    final at = (localDate != null && localDate.isBefore(bugun))
        ? trGunBasiUtc(localDate)
            .add(const Duration(days: 1, milliseconds: -1))
            .toIso8601String()
        : simdi;
    // Çekirdek KAPATILAN GÜNE demirlenir (`gun`), "şimdi"ye değil: dünü kapatan iki cihaz da aynı
    // id'yi üretmeli. Gün metni `tr_gun.dart`taki tek tanımdan gelir — burada elle +3 YOK.
    // ⚠️ DENEME SIRASI ÇEKİRDEĞE GİRER (2026-08-18, geri alma özelliğiyle zorunlu oldu).
    //
    // Kapanış id'si `tenant|scope|user|gün` çekirdeğinden TÜRETİLİR — aynı kapanışın iki cihazda
    // aynı satır olması için. Ama gün geri alınıp YENİDEN kapatılınca ikinci kapanış AYNI
    // çekirdeği üretirdi: yerelde birincil anahtar çakışır, sunucuda uygulayıcı 'duplicate' der
    // ve DÜZELTİLMİŞ SAYIM HİÇ KAYDEDİLMEZDİ. Yani özellik, sessizce hiçbir şey yapmayan bir
    // düğmeye dönüşürdü — üstelik kullanıcı "geri aldım, düzelttim, kapattım" sanarak.
    //
    // Sıra, O KAPSAMIN O GÜNDEKİ mevcut kapanış sayısıdır (geri alma satırları hariç). İki cihaz
    // aynı geçmişi gördüğü sürece aynı sayıyı bulur, yani DETERMİNİZM KORUNUR — çekirdek
    // "kaçıncı deneme" bilgisiyle zenginleşti, rastgeleliğe düşmedi.
    final oncekiler = await (db.select(db.dayClosings)
          ..where((t) => t.scope.equals(scope.name))
          ..where((t) => t.reversesClosingId.isNull()))
        .get();
    final deneme = oncekiler
        .where((r) =>
            r.userId == (scope == ClosingScope.courier ? userId : null) &&
            _sameTrDay(r.occurredAt, gun))
        .length;

    final tenant = meta.tenantCode;
    String? olayId(String tag) => tenant == null
        ? null
        : kapanisOlayId(
            tenantCode: tenant,
            scope: scope.name,
            userId: userId,
            gunAnahtari: trGunAnahtari(gun),
            // İlk kapanış eski etiketi AYNEN taşır: sahadaki kayıtların id'si değişmemeli,
            // yoksa aynı kapanış eski ve yeni sürümde iki ayrı satır olurdu.
            tag: deneme == 0 ? tag : '$tag-${deneme + 1}',
          );
    final id = olayId('closing') ?? newId();
    final diff = countedCashKurus == null ? 0 : countedCashKurus - on.expectedCashKurus;

    await db.transaction(() async {
      // Devir ÖNCE yazılır (kapanış ona `cash_handover_id` ile bağlanacak) ama AYNI transaction
      // içinde: yarım kalma durumu artık yok.
      String? handoverId;
      if (alsoHandover && scope == ClosingScope.courier && countedCashKurus != null) {
        handoverId = await _handovers.devret(
          fromUserId: userId!,
          toUserId: toUserId,
          countedCashKurus: countedCashKurus,
          note: note,
          localDate: localDate,
          // Kapanışla AYNI çekirdek, FARKLI etiket: iki kayıt ayrı ama ikisi de tek kapanışa aittir.
          id: olayId('handover'),
          // Kapanışla AYNI damga: devir bir ms sonra damgalanırsa kapanışın AÇTIĞI pencerenin
          // içine düşer ve o kuryenin beklenen nakdi −(teslim edilen) çıkar.
          occurredAtIso: at,
        );
      }

      final payload = <String, Object?>{
        'id': id,
        'scope': scope.name,
        'user_id': userId,
        'period_start': on.periodStartIso,
        'delivery_count': on.deliveryCount,
        // KAPSAMIN KENDİ ÇERÇEVESİ — `expected_cash_kurus` ile aynı yerden (bkz. [onizle]).
        'total_collected_kurus': on.cerceveKasa.toplam,
        'cash_nakit_kurus': on.cerceveKasa.nakit,
        'cash_kart_kurus': on.cerceveKasa.kart,
        'cash_havale_kurus': on.cerceveKasa.havale,
        'open_credit_kurus': on.openCreditKurus,
        'expected_cash_kurus': on.expectedCashKurus,
        'counted_cash_kurus': countedCashKurus,
        'diff_kurus': diff,
        'cash_handover_id': handoverId,
        'note': note,
      };

      await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
            id: id,
            scope: scope.name,
            userId: Value(userId),
            periodStart: Value(on.periodStartIso),
            deliveryCount: Value(on.deliveryCount),
            totalCollectedKurus: Value(on.cerceveKasa.toplam),
            cashNakitKurus: Value(on.cerceveKasa.nakit),
            cashKartKurus: Value(on.cerceveKasa.kart),
            cashHavaleKurus: Value(on.cerceveKasa.havale),
            openCreditKurus: Value(on.openCreditKurus),
            expectedCashKurus: Value(on.expectedCashKurus),
            countedCashKurus: Value(countedCashKurus),
            diffKurus: Value(diff),
            cashHandoverId: Value(handoverId),
            note: Value(note),
            occurredAt: at,
            deviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'day_closing',
          op: 'closing',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: payload);
    });

    return id;
  }

  /// Gün sınırı kuralı `data/tr_gun.dart`ta TEK yerde durur (#9).
  static bool _sameTrDay(String iso, DateTime localDate) => ayniTrGunIso(iso, localDate);
}

/// Kapanış önizlemesi (salt-okunur): ekranın gösterdiği ve kayda donacak rakamlar.
class ClosingOnizleme {
  ClosingOnizleme({
    required this.kasa,
    required this.cerceveKasa,
    required this.deliveryCount,
    required this.openCreditKurus,
    required this.expectedCashKurus,
    required this.gunNakitKurus,
    this.dusulenKurus = 0,
    this.dusulenKalem = DusulenKalem.kuryelerdeKalan,
    this.periodStartIso,
  });

  /// GÜN çerçevesindeki kasa (takvim günü, kapsam süzgeçli). Ekranın "bugün ne toplandı"
  /// kartlarının kaynağı; kurye kapsamında bu rakam kuryenin PENCERESİ değildir.
  final KasaOzeti kasa;

  /// KAPSAMIN KENDİ çerçevesindeki kasa — kayda donan rakamlar bundan yazılır.
  ///
  /// Gün kapsamında [kasa] ile AYNIDIR. Kurye kapsamında `nakit` PENCEREden gelir (son kurye
  /// kapanışından beri toplanan), böylece kayıt `expected_cash_kurus` ile aynı çerçeveyi konuşur.
  /// Kart/havale gün çerçevesinde kalır — devir yalnız nakit üzerinedir (bkz. [onizle] notu).
  final KasaOzeti cerceveKasa;

  final int deliveryCount;
  final int openCreditKurus;

  /// ŞİMDİ sayılması beklenen nakit = KÜMÜLATİF KALAN: kapsamın günlük nakdi − o gün TESLİM
  /// EDİLEN sayılan nakit. Kuryede bilerek bırakılan para (para üstü) devreder ve akşam yine
  /// burada görünür — "fazla para" diye okunmaz.
  final int expectedCashKurus;

  /// Kapsamın gün BOYUNCA topladığı nakdin tamamı. [expectedCashKurus] ile birlikte taşınır ki
  /// ekran "gün 10.000 · teslim edilen 4.000 · şimdi 6.000" üçlüsünü tek kaynaktan yazabilsin —
  /// aksi hâlde farkı ekran kendi çıkarır ve iki yerde iki formül olurdu.
  final int gunNakitKurus;

  /// [gunNakitKurus]tan DÜŞÜLEN tutar. `gunNakitKurus − dusulenKurus == expectedCashKurus`
  /// her zaman, her kapsamda tutar. NE OLDUĞUNU [dusulenKalem] söyler — ekran kapsamdan çıkarım
  /// yapmaz, etiketi o enum'dan seçer.
  ///
  /// Tek sayı tutuluyor çünkü kimliği kapatan sayı BUDUR; iki ayrı alan olsaydı ekran yanlışını
  /// seçebilirdi (bu vardiyada `kalanNakitKurus` tam olarak böyle yanılttı).
  ///
  /// Ekranın "gün içi ara tahsilatlar" LİSTESİ bundan farklı bir kümedir — o liste kullanıcıya
  /// olayları anlatır, bu sayı aritmetiği kapatır. İkisini karıştırma.
  final int dusulenKurus;

  /// [dusulenKurus]un anlamı. Ekran etiketi BUNDAN seçer.
  final DusulenKalem dusulenKalem;

  final String? periodStartIso;
}
