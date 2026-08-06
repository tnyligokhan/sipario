import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import 'day_end_repository.dart';

/// Kasa devri yerel iş akışı (FAZ 4). Kurye kasayı patrona devreder: SAYILAN nakit + sistemin
/// BEKLEDİĞİ nakit (anlık snapshot) + fark, kalıcı append-only kayıt olur (cash_handovers) + outbox,
/// tek transaction (offline-first atomiklik). Silme/UPDATE YOK; düzeltme yeni devir kaydıyla.
///
/// BEKLENEN NAKİT — TEK TANIM (kullanıcı kararı 2026-08-06):
///   **Beklenen nakit = kapsamın o gün topladığı nakit − o gün teslim ettiği sayılan nakit.
///   Kapsam kurye de olsa gün de olsa aynı formül; devrin ARA mı KAPANIŞ mı olduğu hesaba GİRMEZ.**
///
/// Her kapanış/tahsilat olayının sorduğu soru aynıdır: "ŞİMDİ kasaya girecek para ne kadar?"
/// Cebe konan paranın hangi gerekçeyle çıktığını cep bilmez — aynı fiziksel olayı gerekçesine göre
/// iki türlü saymak, iki ekranın farklı rakam konuşması demekti.
///
/// NEDEN DEĞİŞTİ: eskiden beklenen `period_start`tan (son devirden) beri toplanandı. Patron ara
/// tahsilatta beklenenin tamamını almazsa — 90 toplandı, 60 alındı, 30 para üstü için kuryede
/// BİLEREK bırakıldı — pencere o devre kayıyor ve akşam beklenen 0 çıkıyordu; kurye o 30'u
/// verince ekran "FAZLA 30" yazıyordu. Veri kaybı yoktu ama okunuşu tersti. Kümülatif tanımda
/// kuryede kalan DEVREDER: akşam beklenen 30, fark 0.
///
/// Kart/havale fiziksel kasa değildir — devir yalnız NAKİT üzerinedir.
///
/// GÜNLÜK SIFIRLAMA KORUNUR (TR +03:00): dünden devreden nakit taşınmaz.
///
/// `period_start` KAYITTA KALIR ve SİLİNMEMELİDİR: hangi pencerenin mutabakatı olduğunu söyleyen
/// DENETİM İZİDİR (kayıt append-only, sonradan sorulacak soruların cevabı orada). Yalnız BEKLENEN
/// HESABI ondan türemeyi bıraktı — "kullanılmıyor" sanıp kaldırmak izi yok eder.
///
/// PARALEL HESAP YASAĞI: toplanan nakit [DayEndRepository.kasaOzeti]den gelir — ekranın gösterdiği
/// kasa ile devrin beklediği nakit AYNI koddan çıkmak zorunda.
class CashHandoverRepository {
  CashHandoverRepository(this.db) : _dayEnd = DayEndRepository(db);
  final AppDatabase db;
  final DayEndRepository _dayEnd;

  static const _trOffset = Duration(hours: 3);

  Future<String> devret({
    required String fromUserId,
    String? toUserId,
    required int countedCashKurus,
    String? note,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final id = newId();

    final on = await onizle(fromUserId);
    final periodStart = on.periodStartIso;
    final expected = on.expectedKurus;
    final diff = countedCashKurus - expected;

    await db.transaction(() async {
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: id,
            fromUserId: fromUserId,
            toUserId: Value(toUserId),
            countedCashKurus: countedCashKurus,
            expectedCashKurus: expected,
            diffKurus: diff,
            periodStart: Value(periodStart),
            occurredAt: at,
            deviceId: Value(device),
            note: Value(note),
          ));
      await enqueueOutbox(db,
          entityType: 'cash_handover',
          op: 'handover',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: {
            'id': id,
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
            'counted_cash_kurus': countedCashKurus,
            'expected_cash_kurus': expected,
            'diff_kurus': diff,
            'period_start': periodStart,
            'note': note,
          });
    });

    return id;
  }

  /// ARA TAHSİLAT (kullanıcı kararı 2026-08-06): gün içinde kuryede çok para birikmesin diye patron
  /// kasayı KAPANIŞ BEKLEMEDEN alır. Kayıt tipi olarak bu bir kasa devridir — [devret] ile birebir
  /// aynı satırı yazar; ayrı bir tablo/kolon YOK.
  ///
  /// Peki neden ayrı bir fonksiyon? Çünkü çağrı yerinin NİYETİ okunabilir olmalı: burada gün
  /// KAPANMAZ (`DayClosingRepository.kapat()` çağrılmaz). "devret" adı kapanışla eşanlamlı
  /// okunuyordu; ekran kodunda `araTahsilat(...)` görmek, kapanışın unutulduğu değil bilinçli
  /// olarak ertelendiği anlamına gelir. Ayrıca ara tahsilatın ayırt edilmesi bu niyete bağlıdır:
  /// şemada `kind` kolonu olmadığı için ARA olan, `day_closings.cash_handover_id` ile HİÇBİR
  /// kapanışa bağlanmamış devirdir ([araTahsilatlar]).
  ///
  /// period_start sayesinde gün içinde defalarca çağrılabilir: her ara tahsilat bir öncekinden beri
  /// toplananı kapsar, sayım serbesttir (patron sayar, fark KANIT olarak kaydedilir).
  ///
  /// KAPANMIŞ KAPSAMA YAZMAZ ([StateError] atar). Ekran düğmeyi zaten gizliyor; bu İKİNCİ kapı,
  /// çünkü kapanış "o anın gerçeğini dondurur" — kapandıktan sonra o güne düşen yeni bir devir
  /// arşivi sessizce yalancı çıkarırdı. Kapı [devret]'e DEĞİL buraya konur: kurye kapanışı
  /// (`kapat(alsoHandover: true)`) kapanış satırını yazmadan önce [devret] çağırır, oraya kapı
  /// koysaydık kendi kendini engellerdi.
  Future<String> araTahsilat({
    required String fromUserId,
    String? toUserId,
    required int countedCashKurus,
    String? note,
  }) async {
    final engel = await _kapaliKapsamEngeli(fromUserId);
    if (engel != null) throw StateError(engel);
    return devret(
      fromUserId: fromUserId,
      toUserId: toUserId,
      countedCashKurus: countedCashKurus,
      note: note,
    );
  }

  /// Bugün kapanmış bir kapsam ara tahsilatı engelliyorsa hata metni, engel yoksa null.
  Future<String?> _kapaliKapsamEngeli(String fromUserId) async {
    final bugun = _trBugun();
    final kapanislar = await db.select(db.dayClosings).get();
    for (final k in kapanislar) {
      final t = DateTime.tryParse(k.occurredAt);
      if (t == null || !_ayniTrGun(t, bugun)) continue;
      if (k.scope == 'day') return 'Gün hesabı kapandı; ara tahsilat alınamaz.';
      if (k.scope == 'courier' && k.userId == fromUserId) {
        return 'Bu kuryenin hesabı kapandı; ara tahsilat alınamaz.';
      }
    }
    return null;
  }

  /// Devir ÖNİZLEMESİ (FAZ 4b Dilim 4): ekranın gösterdiği "beklenen nakit" ile devret()'in kayda
  /// yazdığı beklenen AYNI koddan çıksın diye public. Yalnız OKUR (yazma yok). devret() submit anında
  /// bunu YENİDEN çağırır → "anlık snapshot" tanımı korunur (ekranda gösterilen ile yazılan arasında
  /// süre geçse de kayıt submit anındaki değeri tutar).
  /// [localDate] verilmezse BUGÜN. Geçmiş gün de sorulabilir: formül gün bazlı olduğu için
  /// geçmişe sarılabilir (eski `period_start` tabanlı hesap sarılamıyordu — dünün ekranı bugünün
  /// son devrine göre değişirdi).
  Future<HandoverOnizleme> onizle(String fromUserId, {DateTime? localDate}) async {
    final gun = localDate ?? _trBugun();
    final toplanan = (await _dayEnd.kasaOzeti(gun, userId: fromUserId)).nakit;
    final teslimEdilen = await teslimEdilenNakit(gun, kuryeId: fromUserId);
    return HandoverOnizleme(
      periodStartIso: await _periodStart(fromUserId),
      expectedKurus: toplanan - teslimEdilen,
    );
  }

  /// fromUserId'nin son devir occurred_at'i; yoksa bugünün TR gün başı (UTC ISO).
  ///
  /// Yalnız KAYDA yazılır (denetim izi) — beklenen nakit ARTIK bundan türemez. Bkz. sınıf notu.
  Future<String> _periodStart(String fromUserId) async {
    final last = await (db.select(db.cashHandovers)
          ..where((t) => t.fromUserId.equals(fromUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(1))
        .getSingleOrNull();
    return last?.occurredAt ?? _trDayStartUtcIso();
  }

  /// [gun] içinde patrona teslim edilen nakdin SAYILAN toplamı. [kuryeId] verilirse yalnız o
  /// kuryeden alınanlar; verilmezse GÜN kapsamı (tüm kuryeler).
  ///
  /// ARA ve KAPANIŞ devirleri BİRLİKTE sayılır — [araTahsilatlar]dan farkı budur ve bilinçlidir:
  /// orası EKRANIN gösterdiği listedir (ara tahsilatı kapanıştan ayırmak kullanıcı için anlamlı),
  /// burası ise CEPTEKİ parayı ölçer ve cep, paranın hangi gerekçeyle çıktığını bilmez. Ayrımı
  /// hesaba sokmak, aynı fiziksel olayı gerekçesine göre iki türlü saymak olurdu.
  ///
  /// `counted` kullanılır, `expected` DEĞİL: kuryenin cebinden fiilen çıkan para sayılan paradır.
  Future<int> teslimEdilenNakit(DateTime gun, {String? kuryeId}) async {
    final sorgu = db.select(db.cashHandovers);
    if (kuryeId != null) {
      sorgu.where((t) => t.fromUserId.equals(kuryeId));
    }
    final satirlar = await sorgu.get();
    var toplam = 0;
    for (final r in satirlar) {
      final t = DateTime.tryParse(r.occurredAt);
      if (t == null || !_ayniTrGun(t, gun)) continue;
      toplam += r.countedCashKurus;
    }
    return toplam;
  }

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Ara tahsilat okuma katmanı (kullanıcı kararı 2026-08-06)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  /// [localDate] TR gününe düşen ARA tahsilatlar (eskiden yeniye). [kuryeId] verilirse yalnız
  /// o kuryeden alınanlar.
  ///
  /// ARA olmanın tanımı İLİŞKİDEN türetilir: şemada `kind` kolonu YOK ve eklemiyoruz — bir kolon
  /// eklemek aynı gerçeği iki yerde tutmak olurdu ve `day_closings.cash_handover_id` zaten tek
  /// doğru kaynak. Bir kapanışa bağlanmış devir KAPANIŞ devridir (kurye hesabını kapatırken
  /// verdiği kasa); bağlanmamış olan ara tahsilattır. Sonradan gelen senkron bir kapanışı
  /// getirirse aynı satır kendiliğinden "kapanış devri"ne döner — kolon olsaydı bayat kalırdı.
  ///
  /// Sıra ESKİDEN YENİYE: bu bir arşiv değil, günün akışıdır ("önce 4.000 aldım, sonra 6.000").
  Future<List<AraTahsilatKaydi>> araTahsilatlar(DateTime localDate, {String? kuryeId}) async {
    final sorgu = db.select(db.cashHandovers);
    if (kuryeId != null) {
      sorgu.where((t) => t.fromUserId.equals(kuryeId));
    }
    final satirlar = await sorgu.get();
    if (satirlar.isEmpty) return const [];

    final kapanisaBagli = await _kapanisaBagliDevirIdleri();
    final adlar = {for (final u in await db.select(db.users).get()) u.id: u.name};

    final sonuc = <AraTahsilatKaydi>[];
    for (final r in satirlar) {
      if (kapanisaBagli.contains(r.id)) continue;
      final t = DateTime.tryParse(r.occurredAt);
      if (t == null || !_ayniTrGun(t, localDate)) continue;
      sonuc.add(AraTahsilatKaydi(
        id: r.id,
        fromUserId: r.fromUserId,
        // Ad `users` aynasından çözülür; kullanıcı silinmişse kayıt KANIT olarak kalır (sert FK
        // yok) — o yüzden ad boş kalabilir, ekran kimlikle baş başa bırakılmaz diye boş string.
        kuryeAdi: adlar[r.fromUserId] ?? '',
        occurredAt: t,
        countedCashKurus: r.countedCashKurus,
        expectedCashKurus: r.expectedCashKurus,
        diffKurus: r.diffKurus,
        note: r.note,
      ));
    }
    sonuc.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return sonuc;
  }

  /// [localDate] gününde alınan ara tahsilatların SAYILAN toplamı (kuruş).
  ///
  /// `counted` kullanılır, `expected` DEĞİL: kuryenin cebinden fiilen çıkan para sayılan paradır.
  /// Beklenen, sistemin tahminidir; fark zaten devir kaydında kanıt olarak duruyor. Kalan nakdi
  /// beklenenle hesaplasaydık, bir ara tahsilatta 500 kuruş eksik çıktığında o eksiği gün
  /// kapanışında İKİNCİ kez farka yazardık — aynı eksik iki defa suçlanırdı.
  Future<int> araTahsilatToplami(DateTime localDate, {String? kuryeId}) async {
    final kayitlar = await araTahsilatlar(localDate, kuryeId: kuryeId);
    return kayitlar.fold<int>(0, (s, k) => s + k.countedCashKurus);
  }

  /// Bir kapanışa bağlanmış devir id'leri (`day_closings.cash_handover_id`).
  Future<Set<String>> _kapanisaBagliDevirIdleri() async {
    final rows =
        await (db.select(db.dayClosings)..where((t) => t.cashHandoverId.isNotNull())).get();
    return rows.map((r) => r.cashHandoverId!).toSet();
  }

  /// UTC zaman damgası verilen TR yerel takvim gününe mi düşüyor? (`DayEndRepository` ile aynı
  /// +03:00 kaydırması — iki farklı gün tanımı rakamları sessizce ayrıştırırdı.)
  static bool _ayniTrGun(DateTime t, DateTime localDate) {
    final tr = t.toUtc().add(_trOffset);
    return tr.year == localDate.year && tr.month == localDate.month && tr.day == localDate.day;
  }

  /// Şu ANIN TR takvim günü (saat sıfırlanmış) — `DayEndRepository.bugunTr` ile aynı tanım.
  static DateTime _trBugun() {
    final tr = DateTime.now().toUtc().add(_trOffset);
    return DateTime(tr.year, tr.month, tr.day);
  }

  /// Bugünün TR (+03:00) gün başının UTC ISO karşılığı (occurred_at UTC ISO ile karşılaştırılır).
  static String _trDayStartUtcIso() {
    final tr = DateTime.now().toUtc().add(_trOffset);
    final trMidnight = DateTime.utc(tr.year, tr.month, tr.day); // TR 00:00 (saat değeri olarak)
    return trMidnight.subtract(_trOffset).toIso8601String(); // gerçek UTC'ye geri al
  }
}

/// Devir önizleme değeri (salt-okunur): mutabakat dönemi başı + o dönemde kuryenin topladığı
/// beklenen nakit. Ekran gösterir, devret() aynı hesabı kayda yazar.
class HandoverOnizleme {
  HandoverOnizleme({required this.periodStartIso, required this.expectedKurus});
  final String periodStartIso;
  final int expectedKurus;
}

/// Gün içinde alınmış TEK bir ara tahsilat (salt-okunur görünüm). Ekran "kim · ne zaman · sayılan
/// · beklenen · fark" satırını bundan çizer; kayıt append-only `cash_handovers` satırıdır.
class AraTahsilatKaydi {
  AraTahsilatKaydi({
    required this.id,
    required this.fromUserId,
    required this.kuryeAdi,
    required this.occurredAt,
    required this.countedCashKurus,
    required this.expectedCashKurus,
    required this.diffKurus,
    this.note,
  });

  final String id;
  final String fromUserId;

  /// `users` aynasından çözülen ad; kullanıcı yoksa boş.
  final String kuryeAdi;

  /// UTC. Ekran TR'ye çevirir.
  final DateTime occurredAt;

  final int countedCashKurus;
  final int expectedCashKurus;

  /// sayılan − beklenen. Eksik para SİLİNMEZ, kanıt olarak burada durur.
  final int diffKurus;

  final String? note;
}
