import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../data/tr_gun.dart';
import 'day_end_repository.dart';

// ARA TAHSİLAT yüzeyi (al · iptal et · listele · topla) buradan ayrıldı — 500 satır sınırı.
// AYNI KÜTÜPHANEDİR: `_kapaliKapsamEngeli` gibi kapılar private kalsın ve çağrı yerleri
// (`CashHandoverRepository(db).araTahsilatlar(...)`) hiç değişmesin diye `part` seçildi.
part 'cash_handover_ara_tahsilat.dart';

/// Kasa devri yerel iş akışı (FAZ 4). Kurye kasayı patrona devreder: SAYILAN nakit + sistemin
/// BEKLEDİĞİ nakit (anlık snapshot) + fark, kalıcı append-only kayıt olur (cash_handovers) + outbox,
/// tek transaction (offline-first atomiklik). Silme/UPDATE YOK; düzeltme yeni devir kaydıyla.
///
/// KURYEDEN BEKLENEN NAKİT — TEK TANIM (kullanıcı kararı 2026-08-06 + inceleme #2):
///   **beklenen = kuryenin PENCEREDE topladığı nakit − pencerede teslim ettiği sayılan nakit.**
/// Yani rakam, kuryenin cebinde FİİLEN ne varsa odur. Devrin ARA mı KAPANIŞ mı olduğu hesaba
/// GİRMEZ — cep, paranın hangi gerekçeyle çıktığını bilmez.
///
/// NEDEN KÜMÜLATİF: eskiden pencere `period_start`tı (SON DEVİR). Patron beklenenin tamamını
/// almazsa — 90 toplandı, 60 alındı, 30 para üstü için kuryede BİLEREK bırakıldı — pencere o
/// devre kayıyor ve akşam beklenen 0 çıkıyordu; kurye o 30'u verince ekran "FAZLA 30" yazıyordu.
/// Kümülatif tanımda kuryede kalan DEVREDER: akşam beklenen 30, fark 0.
///
/// PENCERE = O KURYENİN SON KAPANIŞI (`day_closings`, scope=courier), yoksa günün TR başlangıcı.
/// Takvim gününe demirlemek YANLIŞTI (inceleme #2): kurye gece topladığı kasayı ertesi sabah
/// verirse "bugün toplanan 0 − bugün teslim edilen 5.000 = −5.000" çıkıyor ve kayda `diff +5.000`
/// KALICI olarak donuyordu. Cep gece yarısında boşalmaz. Bu tanımda beklenen matematiksel olarak
/// negatife DÜŞEMEZ: teslim, ancak aynı pencerede toplanmış paradan yapılabilir.
/// Kırpma (`max(0, …)`) YOK — o, yanlış rakamı gizlerdi; tanımın kendisi doğru.
///
/// Kart/havale fiziksel kasa değildir — devir yalnız NAKİT üzerinedir.
///
/// `period_start` KAYITTA KALIR ve SİLİNMEMELİDİR: hangi pencerenin mutabakatı olduğunu söyleyen
/// DENETİM İZİDİR. Yalnız BEKLENEN HESABI ondan türemeyi bıraktı — "kullanılmıyor" sanıp
/// kaldırmak izi yok eder.
///
/// İŞARET KURALI `DayEndRepository.kasaOzeti` ile AYNIDIR: payment(−)→kasaya giren(+), nakit
/// correction(+)→çıkan(−). Gün bazlı okumalar (`kuryelerinGunlukNetDegisimi`) doğrudan
/// `kasaOzeti`yi ÇAĞIRIR. Yalnız PENCERE bazlı okuma ([_pencerede]) kuralı tekrarlar, çünkü
/// `kasaOzeti` takvim gününe göre süzüyor ve pencere gün sınırını aşabiliyor. Kural değişirse
/// İKİ YERİ birden güncelle — bilinçli, kayıtlı bir tekrar.
class CashHandoverRepository {
  CashHandoverRepository(this.db);
  final AppDatabase db;

  /// [localDate] verilmezse DÜZELTİLMİŞ saatle bugün (#4).
  ///
  /// [occurredAtIso] YALNIZ `DayClosingRepository.kapat()` içindir: kapanış ile ona bağlanan devir
  /// AYNI damgayı taşımak ZORUNDA. Devir bir milisaniye SONRA damgalanırsa, kapanışın açtığı YENİ
  /// pencerenin içine düşer ve o kuryenin beklenen nakdi −(teslim edilen) çıkar. Pencere sınırı
  /// HARİÇ olduğu için (`isAfter`), aynı damga devri kapanan pencerede bırakır — doğrusu budur:
  /// o para kapanan dönemin parasıdır.
  ///
  /// [id] de YALNIZ `kapat()` içindir ve DETERMİNİSTİK gelir (`kapanisOlayId(... tag:'handover')`):
  /// iki cihaz aynı kapanışı yazarsa devir de tek satır olsun diye. Verilmezse rastgele UUIDv7.
  ///
  /// ⚠️ [araTahsilat] BURAYA ASLA id GEÇMEZ ve bu PAZARLIKSIZDIR: gün içinde aynı kuryeden defalarca
  /// tahsilat alınabilmeli. Deterministik id ara tahsilata sızsaydı ikinci tahsilat aynı satır
  /// sayılıp SESSİZCE yutulurdu — özelliğin tamamı ölürdü, üstelik hata "para kaybolmuş" diye
  /// görünürdü.
  Future<String> devret({
    required String fromUserId,
    String? toUserId,
    required int countedCashKurus,
    String? note,
    DateTime? localDate,
    String? occurredAtIso,
    String? id,
  }) async {
    final meta = await db.syncState();
    final at = occurredAtIso ?? correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final devirId = id ?? newId();

    // localDate GEÇİRİLİR (inceleme #5): `kapat(localDate: X)` önizlemeyi X için hesaplayıp
    // devri bugüne göre yazsaydı, kapanışa donan beklenen ile devre yazılan beklenen ayrışırdı.
    final on = await onizle(fromUserId, localDate: localDate);
    final periodStart = on.periodStartIso;
    final expected = on.expectedKurus;
    final diff = countedCashKurus - expected;

    await db.transaction(() async {
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: devirId,
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
          entityId: devirId,
          occurredAt: at,
          deviceId: device,
          payload: {
            'id': devirId,
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
            'counted_cash_kurus': countedCashKurus,
            'expected_cash_kurus': expected,
            'diff_kurus': diff,
            'period_start': periodStart,
            'note': note,
          });
    });

    return devirId;
  }

  /// Devir ÖNİZLEMESİ (FAZ 4b Dilim 4): ekranın gösterdiği "beklenen nakit" ile devret()'in kayda
  /// yazdığı beklenen AYNI koddan çıksın diye public. Yalnız OKUR (yazma yok). devret() submit anında
  /// bunu YENİDEN çağırır → "anlık snapshot" tanımı korunur (ekranda gösterilen ile yazılan arasında
  /// süre geçse de kayıt submit anındaki değeri tutar).
  /// [localDate] verilmezse DÜZELTİLMİŞ saatle bugün. Pencerenin BİTİŞİ o günün sonudur; geçmiş
  /// gün sorulduğunda sonraki hareketler girmez.
  Future<HandoverOnizleme> onizle(String fromUserId, {DateTime? localDate}) async {
    final gun = localDate ?? await bugunTrDuzeltilmis(db);
    final pencere = await _pencere(fromUserId, gun);
    final toplanan = await _pencerede(fromUserId, pencere);
    final teslimEdilen = await _teslimEdilen(kuryeId: fromUserId, pencere: pencere);
    return HandoverOnizleme(
      periodStartIso: await _periodStart(fromUserId),
      expectedKurus: toplanan - teslimEdilen,
      toplananKurus: toplanan,
      teslimEdilenKurus: teslimEdilen,
    );
  }

  /// Kuryelerin cebindeki paranın [gun] İÇİNDEKİ NET DEĞİŞİMİ (gün kapsamı için).
  ///
  ///   `Σ (kuryenin O GÜN topladığı nakit − o gün teslim ettiği sayılan nakit)`
  ///
  /// AKIŞ'tır, STOK değil — ve ayrım bu fonksiyonun bütün sebebidir (ikinci inceleme bulgusu).
  /// Gün kapsamı `kasa.nakit` ile çalışır ve o bir AKIŞtır (takvim günü). Buradan kuryenin
  /// ALTTAN AÇIK penceresindeki stoku (ömür boyu birikmiş kalan) düşülürse iki farklı çerçeve
  /// karışır: Emre dün 5.000 taşıyıp bugün 3.000 toplarsa "3.000 − 8.000 = −5.000" çıkar,
  /// patronun kasasında 0 varken ekran FAZLA 5.000 yazar ve bu arşive KALICI donar. Kurye hiç
  /// "hesabı kapat" kullanmadan her gün biraz para tutarsa — ki kümülatif tanımın gerekçesi tam
  /// olarak buydu — stok her gün büyür ve sapma sinsice artar.
  ///
  /// NEGATİF OLABİLİR ve bu DOĞRUDUR: kurye dünün parasını bugün teslim ederse net değişim
  /// eksidir, yani kasaya günün nakdinden FAZLASI girer. Kırpma YOK.
  ///
  /// KURYE KAPSAMI BUNU KULLANMAZ: orada alttan açık pencere (stok) doğrudur — kuryenin cebindeki
  /// gerçek para odur. İki kapsam iki farklı soru sorar.
  ///
  /// KÜME `users` AYNASINDAN DEĞİL, DEFTERDEN TÜRER (inceleme B — bağlayıcı): `users` sunucu
  /// kaynaklı bir önbellektir ve GEÇ İNEBİLİR; `status='active'` süzgeci ise gün içinde pasife
  /// alınmış kuryeyi düşürürdü. Kanıt defterdedir: o gün fiilen para toplayan
  /// `collected_by_user_id`ler + devir yapan `from_user_id`ler.
  ///
  /// DIŞLAMA POZİTİF BİLGİYE DAYANIR: bir toplayıcı, ancak `users` aynası (ya da oturum) "bu kişi
  /// kurye DEĞİL" diyorsa kümeden çıkar. Aynada hiç olmayan toplayıcı KURYE SAYILIR. Yanlış
  /// kuryeleştirmenin yönü: düşülen büyür → beklenen DÜŞER → patron FAZLA görür. Yanlış
  /// kasalaştırmanın yönü ise EKSİK. İkisinden birini seçmek zorundayız; aynanın geç inmesi bu
  /// depoda yaşanmış bir arıza sınıfı olduğu için "aynada yoksa kurye" tarafını seçiyoruz —
  /// kurye kümesi zaten defterden doğrulanıyor, patron/operatör ise oturumdan biliniyor.
  ///
  /// TOPLAYICISI NULL nakit (inceleme E) kümeye GİRMEZ ve bu BİLİNÇLİ: atfı olmayan para
  /// "kuryede" sayılamaz, kasada sayılır. Böyle bir kayıt yalnız oturum kurulmadan yazılabilir
  /// (giriş `sync_meta.user_id`yi her zaman doldurur, `logout` silmez) — yani pratikte patronun
  /// kendi cihazıdır. Yine de o parayı fiilen bir kurye taşıyorsa gün sayımı EKSİK gösterir;
  /// eksik GÖRÜNÜR bir sinyaldir, sessizce yutulmaz.
  Future<int> kuryelerinGunlukNetDegisimi(DateTime gun) async {
    final adaylar = await _gunlukKuryeAdaylari(gun);
    if (adaylar.isEmpty) return 0;

    final dayEnd = DayEndRepository(db);
    var toplam = 0;
    for (final id in adaylar) {
      final toplanan = (await dayEnd.kasaOzeti(gun, userId: id)).nakit;
      final teslim = await teslimEdilenNakit(gun, kuryeId: id);
      toplam += toplanan - teslim;
    }
    return toplam;
  }

  /// [gun] içinde para taşımış KURYE adayları (bkz. [kuryelerinGunlukNetDegisimi] notu).
  Future<Set<String>> _gunlukKuryeAdaylari(DateTime gun) async {
    final adaylar = <String>{};

    final hareketler = await (db.select(db.ledgerEntries)
          ..where((t) => t.paymentType.equals('nakit') & t.collectedByUserId.isNotNull()))
        .get();
    for (final e in hareketler) {
      if (ayniTrGunIso(e.occurredAt, gun)) adaylar.add(e.collectedByUserId!);
    }
    // Devir yapan kişi tanım gereği kuryedir; o gün hiç tahsilat yapmamış olsa bile kümededir
    // (dünden taşıdığı kasa bugün teslim edilmiş olabilir — net değişimi NEGATİF olur).
    for (final h in await db.select(db.cashHandovers).get()) {
      if (ayniTrGunIso(h.occurredAt, gun)) adaylar.add(h.fromUserId);
    }
    if (adaylar.isEmpty) return adaylar;

    final aynadakiRoller = {
      for (final u in await (db.select(db.users)..where((t) => t.id.isIn(adaylar))).get())
        u.id: u.role,
    };
    final meta = await db.syncState();
    adaylar.removeWhere((id) {
      final rol = aynadakiRoller[id] ?? (id == meta.userId ? meta.userRole : null);
      return rol != null && rol != 'kurye'; // pozitif olarak kurye DEĞİL
    });
    return adaylar;
  }

  /// Kuryenin mutabakat PENCERESİ: [gun]un sonundan önceki SON kurye kapanışından o günün sonuna.
  ///
  /// HİÇ KAPANIŞI YOKSA PENCERE ALTTAN AÇIKTIR (gün başı DEĞİL). İnceleme #2 fallback olarak
  /// "bugünün TR gün başı" öneriyordu ama o, kapatmaya çalıştığı hatanın ta kendisini üretir:
  /// dün 23:00'te toplanıp bugün 09:00'da teslim edilen kasada "bugün toplanan 0 − teslim edilen
  /// 5.000 = −5.000" çıkardı. Hiç kapanış yapmamış kurye HİÇ mutabakat yapmamıştır; o güne kadar
  /// topladığının teslim etmediği kısmı hâlâ cebindedir. Alttan açık pencere, incelemenin
  /// istediği garantiyi ("beklenen negatife düşemez") gerçekten sağlar: teslim, ancak aynı
  /// pencerede toplanmış paradan yapılabilir.
  Future<_Pencere> _pencere(String fromUserId, DateTime gun) async {
    final bitis = trGunBasiUtc(gun).add(const Duration(days: 1));
    final kapanislar = await (db.select(db.dayClosings)
          ..where((t) => t.scope.equals('courier') & t.userId.equals(fromUserId)))
        .get();

    DateTime? sonKapanis;
    for (final k in kapanislar) {
      final t = DateTime.tryParse(k.occurredAt)?.toUtc();
      if (t == null || !t.isBefore(bitis)) continue;
      if (sonKapanis == null || t.isAfter(sonKapanis)) sonKapanis = t;
    }
    return _Pencere(baslangic: sonKapanis, bitis: bitis);
  }

  /// Penceredeki NAKİT kasa katkısı (payment(−)→giren(+); nakit correction(+)→çıkan(−)).
  Future<int> _pencerede(String fromUserId, _Pencere pencere) async {
    final satirlar = await (db.select(db.ledgerEntries)
          ..where((t) => t.paymentType.equals('nakit') & t.collectedByUserId.equals(fromUserId)))
        .get();
    var toplam = 0;
    for (final e in satirlar) {
      final t = DateTime.tryParse(e.occurredAt)?.toUtc();
      if (t == null || !pencere.icinde(t)) continue;
      toplam += -e.amountKurus;
    }
    return toplam;
  }

  /// [gun] TR gününde teslim edilen nakdin SAYILAN toplamı. [kuryeId] verilmezse tüm kuryeler.
  ///
  /// ARA ve KAPANIŞ devirleri BİRLİKTE sayılır — [araTahsilatlar]dan farkı budur ve bilinçlidir:
  /// orası EKRANIN gösterdiği listedir (ara tahsilatı kapanıştan ayırmak kullanıcı için anlamlı),
  /// burası ise CEPTEKİ parayı ölçer ve cep, paranın hangi gerekçeyle çıktığını bilmez. Ayrımı
  /// hesaba sokmak, aynı fiziksel olayı gerekçesine göre iki türlü saymak olurdu.
  ///
  /// ⚠️ İPTAL EDİLMİŞ TAHSİLATLAR BURADA SÜZÜLMEZ ve SÜZÜLMEMELİ (2026-08-13). İptal, ters
  /// işaretli ikinci bir satırdır ([araTahsilatIptal]); orijinal(+) ve iptal(−) BİRLİKTE
  /// toplanınca net sıfır eder, yani kuryenin beklenen nakdi kendiliğinden geri gelir.
  /// "Burası da süzülmeli mi?" sorusunun cevabı HAYIR: iptal edileni süzüp iptal satırını
  /// bırakmak parayı bir kez daha düşürürdü, ikisini birden süzmek ise iptali bir NO-OP yapardı
  /// (o zaman orijinal hiç düşülmemiş sayılırdı — ama düşülmüştü, para gerçekten alınmıştı ve
  /// geri verilmişti). Süzgeç YALNIZ [araTahsilatlar]/[araTahsilatToplami] gibi KULLANICIYA
  /// LİSTE gösteren yerlere aittir; cep matematiğine değil.
  ///
  /// `counted` kullanılır, `expected` DEĞİL: kuryenin cebinden fiilen çıkan para sayılan paradır.
  Future<int> teslimEdilenNakit(DateTime gun, {String? kuryeId}) =>
      _teslimEdilen(kuryeId: kuryeId, gun: gun);

  /// [pencere] verilirse o aralık, yoksa [gun]ün tamamı süzgeç olur.
  Future<int> _teslimEdilen({String? kuryeId, DateTime? gun, _Pencere? pencere}) async {
    final sorgu = db.select(db.cashHandovers);
    if (kuryeId != null) {
      sorgu.where((t) => t.fromUserId.equals(kuryeId));
    }
    final satirlar = await sorgu.get();
    var toplam = 0;
    for (final r in satirlar) {
      final t = DateTime.tryParse(r.occurredAt)?.toUtc();
      if (t == null) continue;
      if (!(pencere?.icinde(t) ?? ayniTrGunAn(t, gun!))) continue;
      toplam += r.countedCashKurus;
    }
    return toplam;
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
    return last?.occurredAt ?? trGunBasiUtc(await bugunTrDuzeltilmis(db)).toIso8601String();
  }
}

/// Kuryenin mutabakat penceresi: `(baslangic, bitis)`. [baslangic] null ise ALTTAN AÇIK —
/// kurye hiç kapanış yapmamıştır, yani hiç mutabakat yapmamıştır.
class _Pencere {
  const _Pencere({required this.baslangic, required this.bitis});
  final DateTime? baslangic;
  final DateTime bitis;

  /// [baslangic] HARİÇTİR (`isAfter`): kapanış ANINDA yazılan devir (`kapat(alsoHandover: true)`)
  /// kapanışla AYNI damgayı taşır ve yeni pencereye DEĞİL kapanan pencereye aittir. Dahil
  /// olsaydı kapanış sonrası beklenen −(teslim edilen) çıkardı.
  bool icinde(DateTime t) {
    final alt = baslangic;
    return (alt == null || t.isAfter(alt)) && t.isBefore(bitis);
  }
}

/// Devir önizleme değeri (salt-okunur): mutabakat dönemi başı + o dönemde kuryenin topladığı
/// beklenen nakit. Ekran gösterir, devret() aynı hesabı kayda yazar.
class HandoverOnizleme {
  HandoverOnizleme({
    required this.periodStartIso,
    required this.expectedKurus,
    this.toplananKurus = 0,
    this.teslimEdilenKurus = 0,
  });

  /// Denetim izi — hesaba GİRMEZ (bkz. sınıf notu).
  final String periodStartIso;

  /// Kuryenin cebinde kalan = [toplananKurus] − [teslimEdilenKurus].
  final int expectedKurus;

  /// PENCEREDE toplanan nakit (son kapanıştan beri). Ekran üçlüsünün ilk sayısı; kimliğin
  /// tutması için gün toplamı DEĞİL pencere toplamı taşınır — kurye gün içinde bir kez
  /// kapatmışsa günün tamamı artık onun çerçevesi değildir.
  final int toplananKurus;

  /// PENCEREDE teslim edilen sayılan nakit (ara + kapanış devirleri birlikte).
  final int teslimEdilenKurus;
}

