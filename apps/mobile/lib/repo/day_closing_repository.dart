import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../data/tr_gun.dart';
import 'cash_handover_repository.dart';
import 'day_end_repository.dart';

/// Kapanış kapsamı: günün tamamı ya da tek kurye (tasarım: "Tümü" sekmesi vs kurye sekmesi).
enum ClosingScope { day, courier }

/// [ClosingOnizleme.dusulenKurus]un NE OLDUĞU. Anlam DEĞERLE BİRLİKTE taşınır; ekran kapsamdan
/// çıkarım YAPMAZ.
///
/// Bu vardiyada dört kez ısırılan kalıp tam olarak buydu: `kalanNakitKurus`, `araTahsilatKurus`,
/// `teslimEdilenKurus`... hepsi "bağlama göre doğru" sayılardı ve yanlış bağlamda kullanıldılar.
/// Sayının yanında ne olduğunu söyleyen bir etiket taşımak, o hatayı derleme zamanına çeker.
enum DusulenKalem {
  /// GÜN kapsamı: henüz teslim edilmemiş, hâlâ kuryelerin cebindeki para.
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

  /// Bu kapsam bugün kapatıldı mı? (Kapatılmışsa ekran kilitlenir — tasarım.)
  Future<bool> kapaliMi(ClosingScope scope, {String? userId, DateTime? localDate}) async {
    final date = localDate ?? await bugunTrDuzeltilmis(db);
    final rows = await (db.select(db.dayClosings)..where((t) => t.scope.equals(scope.name))).get();
    return rows.any((r) =>
        r.userId == (scope == ClosingScope.courier ? userId : null) && _sameTrDay(r.occurredAt, date));
  }

  /// [localDate] TR gününe düşen kapanış kayıtları (yeni üstte). Arşivin GÜN SÜZGEÇLİ hâli —
  /// geçmiş gün ekranı "o gün kim kapattı" sorusunu tüm arşivi taramadan sorabilsin diye.
  Future<List<DayClosing>> gununKapanislari(DateTime localDate) async {
    final rows = await (db.select(db.dayClosings)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
    return rows.where((r) => _sameTrDay(r.occurredAt, localDate)).toList();
  }

  /// Kapanış ÖNİZLEMESİ — ekranın gösterdiği rakamlar. `kapat()` submit anında bunu YENİDEN çağırır,
  /// böylece gösterilen ile yazılan aynı koddan çıkar (devir önizlemesiyle aynı desen).
  ///
  /// Her kapanış olayının sorduğu soru aynıdır: **"ŞİMDİ kasaya girecek para ne kadar?"** Ama
  /// cevabın şekli kapsama göre değişir ve bu ayrım İNCELEME #1'in düzelttiği hatadır:
  ///
  ///  • **KURYE kapsamı** — beklenen = kuryenin cebinde kalan (`CashHandoverRepository.onizle`).
  ///  • **GÜN kapsamı** — beklenen = günün nakdi − KURYELERDE KALAN.
  ///
  /// Gün kapsamında devir bir **İÇ TRANSFERDİR**: para kuryeden patrona geçer, işletmeden ÇIKMAZ.
  /// Teslim edilenleri düşmek işaretini kaybediyordu — kurye 10.000 toplayıp hepsini verdiğinde
  /// ekran "beklenen 0" derken patronun kasasında 10.000 vardı ve sayım "FAZLA 10.000" yazıyordu.
  /// Patron gün sonunda KASASINI sayar; kasada olması gereken = toplanan − hâlâ kuryelerin cebinde
  /// olan. Tek kişilik bayide kuryelerde kalan 0'dır → beklenen günün tüm nakdi olur (doğru).
  ///
  /// Gün kapsamı KENDİ FORMÜLÜNÜ YAZMAZ: kuryelerde kalan, her kuryenin kurye-kapsamı değerinin
  /// toplamıdır — türetme tek yerde durur.
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
    // Kurye kapsamında üçlü PENCEREDEN gelir (kimlik ancak aynı çerçevede tutar); gün kapsamında
    // GÜNDEN. Kurye o gün hiç kapatmamışsa pencere = günün tamamıdır, yani ikisi çakışır.
    final dusulen =
        handover?.teslimEdilenKurus ?? await _handovers.kuryelerdeKalanNakit(date);
    final cerceveNakit = handover?.toplananKurus ?? kasa.nakit;

    return ClosingOnizleme(
      kasa: kasa,
      deliveryCount: teslimat,
      openCreditKurus: borc.toplamAcikBorc,
      expectedCashKurus: handover?.expectedKurus ?? (kasa.nakit - dusulen),
      gunNakitKurus: cerceveNakit,
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

    final on = await onizle(scope, userId: userId, localDate: localDate);
    final meta = await db.syncState();
    final device = meta.deviceId;

    // GEÇMİŞ GÜN KAPANIŞI O GÜNE DAMGALANIR (inceleme F3). `kapaliMi` ve `gununKapanislari`
    // `occurred_at`in TR gününe bakıyor; kaydı "şimdi"ye damgalarsak dünü kapatan kapanış dünde
    // GÖRÜNMEZ — gün kapalı sayılmaz, arşivde yanlış güne düşer. Damga o günün SON anıdır:
    // olayın gerçek yazım anı `device_id` + outbox sırasında zaten duruyor, kaybolmuyor.
    final simdi = correctedNowIso(meta.serverTimeOffsetMs);
    final bugun = await bugunTrDuzeltilmis(db);
    final at = (localDate != null && localDate.isBefore(bugun))
        ? trGunBasiUtc(localDate)
            .add(const Duration(days: 1, milliseconds: -1))
            .toIso8601String()
        : simdi;
    final id = newId();
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
        'total_collected_kurus': on.kasa.toplam,
        'cash_nakit_kurus': on.kasa.nakit,
        'cash_kart_kurus': on.kasa.kart,
        'cash_havale_kurus': on.kasa.havale,
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
            totalCollectedKurus: Value(on.kasa.toplam),
            cashNakitKurus: Value(on.kasa.nakit),
            cashKartKurus: Value(on.kasa.kart),
            cashHavaleKurus: Value(on.kasa.havale),
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
    required this.deliveryCount,
    required this.openCreditKurus,
    required this.expectedCashKurus,
    required this.gunNakitKurus,
    this.dusulenKurus = 0,
    this.dusulenKalem = DusulenKalem.kuryelerdeKalan,
    this.periodStartIso,
  });
  final KasaOzeti kasa;
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
