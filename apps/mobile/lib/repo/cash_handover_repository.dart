import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../data/tr_gun.dart';
import 'day_end_repository.dart';

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
  Future<String> devret({
    required String fromUserId,
    String? toUserId,
    required int countedCashKurus,
    String? note,
    DateTime? localDate,
    String? occurredAtIso,
  }) async {
    final meta = await db.syncState();
    final at = occurredAtIso ?? correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final id = newId();

    // localDate GEÇİRİLİR (inceleme #5): `kapat(localDate: X)` önizlemeyi X için hesaplayıp
    // devri bugüne göre yazsaydı, kapanışa donan beklenen ile devre yazılan beklenen ayrışırdı.
    final on = await onizle(fromUserId, localDate: localDate);
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
  /// Gün içinde defalarca çağrılabilir: her ara tahsilat kuryenin cebinde O AN ne varsa onu
  /// kapsar, sayım serbesttir (patron sayar, fark KANIT olarak kaydedilir).
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
    final bugun = await bugunTrDuzeltilmis(db);
    final kapanislar = await db.select(db.dayClosings).get();
    for (final k in kapanislar) {
      final t = DateTime.tryParse(k.occurredAt);
      if (t == null || !ayniTrGunAn(t, bugun)) continue;
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
      if (t == null || !ayniTrGunAn(t, localDate)) continue;
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
