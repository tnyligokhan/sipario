// ARA TAHSİLAT — gün içi nakit teslimi ve İPTALİ (kullanıcı kararları 2026-08-06 · 2026-08-13).
//
// NEDEN AYRI DOSYA: `cash_handover_repository.dart` iptal akışıyla 631 satıra çıkmıştı (depo
// sınırı 500). Ayrım keyfi değil, KONUYA göre: ana dosya "kuryenin cebinde ne var" sorusunu
// (pencere · beklenen nakit · devir) yanıtlar; burası gün İÇİNDEKİ tahsilat olaylarını yazar ve
// ekrana listeler.
//
// NEDEN `part` (ayrı kütüphane değil): buradaki üç yardımcı (`_kapaliKapsamEngeli`,
// `_kapanisaBagliDevirIdleri`, `_iptalEdilmisDevirIdleri`) SIR kalmalı — public yapmak, gün
// sonu ekranını "hangi devir kapanışa bağlı" gibi bir soruyu kendi başına sormaya davet ederdi
// ve o cevabın tek sahibi bu repodur. `part` aynı kütüphanede kalmayı, dolayısıyla `_` gizliliğini
// ve `CashHandoverRepository.db`ye erişimi korur. Çağrı yerleri DEĞİŞMEZ: ana dosyayı import eden
// herkes bu uzantıyı da görür.
//
// NEDEN `extension` (sınıfın kendisi değil): Dart'ta kısmi sınıf yoktur; `part` dosyası bir
// sınıfa gövde ekleyemez. Uzantı aynı kütüphanede olduğu için sınıfın private üyelerine erişir.

part of 'cash_handover_repository.dart';

/// [CashHandoverRepository]nin ara tahsilat yüzeyi — yazma (al/iptal et) + okuma (listele/topla).
extension AraTahsilatIslemleri on CashHandoverRepository {
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
    // `id` GEÇİLMEZ — kayıt RASTGELE id alır. Kapanışın deterministik id'si buraya sızarsa günün
    // ikinci ara tahsilatı aynı satır sayılıp sessizce yutulur (bkz. [devret] uyarısı).
    return devret(
      fromUserId: fromUserId,
      toUserId: toUserId,
      countedCashKurus: countedCashKurus,
      note: note,
    );
  }

  /// ARA TAHSİLAT İPTALİ (kullanıcı kararı 2026-08-13): yönetici yanlış alınmış bir ara tahsilatı
  /// geri alır. Kayıt SİLİNMEZ — ters işaretli İKİNCİ bir `cash_handovers` satırı yazılır
  /// (`reversesHandoverId` = orijinalin id'si). BRIEF kırmızı çizgi #2: para kayıtları
  /// silinmez/ezilmez; `LedgerEntries.reversesEntryId` deseninin aynısı.
  ///
  /// NEDEN [devret] ÜZERİNDEN YAZILMIYOR (pazarlıksız): `devret()` submit anında kendi
  /// [onizle]'sini çağırıp `expected`/`diff` doldurur. İptal satırı oradan geçseydi kendi
  /// "beklenen"i hesaplanır ve tutarı eksi olduğu için devasa bir `diff` üretirdi — yani bir
  /// DÜZELTME kaydı, sistemin gözünde bir MUTABAKAT SAPMASI olarak arşive donardı. O yüzden
  /// insert + outbox burada DOĞRUDAN ve tek transaction içinde yazılır.
  ///
  /// ⚠️ `diffKurus` = 0 ve `expectedCashKurus` = 0 BİLİNÇLİDİR: iptal bir mutabakat değildir,
  /// eksik para İDDİASI da değildir. Orijinal satırdaki `diff` kanıt olarak yerinde durur; iptale
  /// de bir fark yazsaydık aynı sapmayı iki kez suçlamış olurduk.
  ///
  /// ⚠️ `fromUserId` ORİJİNALDEKİYLE AYNI kalır (iptali kim yaptıysa o değil). Pencere matematiği
  /// (`_pencerede`/[_teslimEdilen]) kuryenin cebini `from_user_id` üzerinden ölçüyor; iptali
  /// iptal edenin üstüne yazsaydık orijinal(+) ile iptal(−) farklı ceplere düşer, kuryenin
  /// beklenen nakdi geri gelmezdi. İptal EDEN kişi `toUserId`ye yazılır.
  ///
  /// [handoverId] bulunamazsa / zaten iptal edilmişse / kendisi bir iptal kaydıysa / bir kapanışa
  /// bağlıysa (yani ara tahsilat değil, kapanış deviriyse) [StateError] atar. Mesajlar
  /// kullanıcıya OLDUĞU GİBİ basılır — "bir şeyler ters gitti" demek, NE olduğunu bilirken bilgi
  /// saklamaktır.
  ///
  /// Kapanmış kapsamda iptal de YAPILAMAZ ([araTahsilat] ile AYNI kapı): kapanış o anın gerçeğini
  /// dondurur; kapandıktan sonra o güne düşen bir düzeltme arşivi sessizce yalancı çıkarırdı.
  Future<String> araTahsilatIptal({
    required String handoverId,
    String? iptalEdenUserId,
    String? note,
  }) async {
    final hedef = await (db.select(db.cashHandovers)..where((t) => t.id.equals(handoverId)))
        .getSingleOrNull();
    if (hedef == null) {
      throw StateError('Ara tahsilat kaydı bulunamadı; ekranı yenileyip tekrar deneyin.');
    }
    if (hedef.reversesHandoverId != null) {
      throw StateError('Bu satır zaten bir iptal kaydı; iptal edilemez.');
    }
    if ((await _iptalEdilmisDevirIdleri()).contains(hedef.id)) {
      throw StateError('Bu ara tahsilat zaten iptal edilmiş.');
    }
    // KAPANIŞ DEVİRLERİ İPTAL EDİLEMEZ: "ara" olmanın tanımı ilişkidendir (bkz. [araTahsilatlar]).
    // Bir kapanışa bağlı devri geri almak, arşivdeki mutabakatı sessizce boşa düşürürdü —
    // kapanış hâlâ "5.000 teslim alındı" derken defterde o para geri dönmüş olurdu.
    if ((await _kapanisaBagliDevirIdleri()).contains(hedef.id)) {
      throw StateError('Bu devir bir hesap kapanışına ait; ara tahsilat değildir, iptal edilemez.');
    }

    final engel = await _kapaliKapsamEngeli(hedef.fromUserId, eylem: 'ara tahsilat iptal edilemez');
    if (engel != null) throw StateError(engel);

    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final iptalId = newId();

    await db.transaction(() async {
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: iptalId,
            fromUserId: hedef.fromUserId,
            toUserId: Value(iptalEdenUserId),
            countedCashKurus: -hedef.countedCashKurus,
            expectedCashKurus: 0,
            diffKurus: 0,
            reversesHandoverId: Value(hedef.id),
            occurredAt: at,
            deviceId: Value(meta.deviceId),
            note: Value(note),
          ));
      // OUTBOX'TA YENİ BİR `op` AÇILMAZ: sunucu tarafında bu satır da bir `cash_handover`dır ve
      // aynı "yoksa ekle" yolundan uygulanır. Yeni bir op, sunucuda ikinci bir uygulayıcı dalı
      // ve eski sunucularda sessizce düşen bir olay demekti. Fark tek alanda taşınır.
      await enqueueOutbox(db,
          entityType: 'cash_handover',
          op: 'handover',
          entityId: iptalId,
          occurredAt: at,
          deviceId: meta.deviceId,
          payload: {
            'id': iptalId,
            'from_user_id': hedef.fromUserId,
            'to_user_id': iptalEdenUserId,
            'counted_cash_kurus': -hedef.countedCashKurus,
            'expected_cash_kurus': 0,
            'diff_kurus': 0,
            'period_start': null,
            'reverses_handover_id': hedef.id,
            'note': note,
          });
    });

    return iptalId;
  }

  /// Bugün kapanmış bir kapsam [eylem]i engelliyorsa hata metni, engel yoksa null.
  ///
  /// [eylem] cümlenin sonuna girer ("… kapandı; $eylem."): aynı kapı hem tahsilat ALMAYI hem
  /// İPTALİ tutuyor ve tek bir metin ikisinde de doğru okunmuyordu. Kapıyı ikiye bölmek yerine
  /// cümleyi parçalamak bilinçli — koşul tek yerde kalsın.
  Future<String?> _kapaliKapsamEngeli(
    String fromUserId, {
    String eylem = 'ara tahsilat alınamaz',
  }) async {
    final bugun = await bugunTrDuzeltilmis(db);
    final kapanislar = await db.select(db.dayClosings).get();
    for (final k in kapanislar) {
      final t = DateTime.tryParse(k.occurredAt);
      if (t == null || !ayniTrGunAn(t, bugun)) continue;
      if (k.scope == 'day') return 'Gün hesabı kapandı; $eylem.';
      if (k.scope == 'courier' && k.userId == fromUserId) {
        return 'Bu kuryenin hesabı kapandı; $eylem.';
      }
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Okuma katmanı — ekranın listelediği ve topladığı
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
  ///
  /// İPTAL SATIRLARI LİSTEDE GÖRÜNMEZ, İPTAL EDİLEN ORİJİNAL KALIR (2026-08-13). İptal satırı
  /// bağımsız bir tahsilat değil, bir DÜZELTMEDİR; listeye girseydi bayi "−400,00 ₺ tahsilat
  /// aldım" diye okunacak bir satır görürdü. Orijinal ise kalır ve [AraTahsilatKaydi.iptalEdildi]
  /// ile işaretlenir — BRIEF kırmızı çizgi #2'nin karşılığı budur: olay olmuştur, kanıtı
  /// görünür kalır, yalnız toplamdan düşer.
  Future<List<AraTahsilatKaydi>> araTahsilatlar(DateTime localDate, {String? kuryeId}) async {
    final sorgu = db.select(db.cashHandovers);
    if (kuryeId != null) {
      sorgu.where((t) => t.fromUserId.equals(kuryeId));
    }
    final satirlar = await sorgu.get();
    if (satirlar.isEmpty) return const [];

    final kapanisaBagli = await _kapanisaBagliDevirIdleri();
    // İPTAL KÜMESİ GÜNE GÖRE SÜZÜLMEZ (bilinçli): iptal, orijinalden farklı bir TR gününe
    // düşebilir (23:50'de alınan tahsilat 00:10'da iptal edilir). Kümeyi günle daraltsaydık
    // orijinal, kendi gününde iptal edilmemiş gibi görünmeye devam ederdi.
    final iptalliler = await _iptalEdilmisDevirIdleri();
    final adlar = {for (final u in await db.select(db.users).get()) u.id: u.name};

    final sonuc = <AraTahsilatKaydi>[];
    for (final r in satirlar) {
      if (kapanisaBagli.contains(r.id)) continue;
      if (r.reversesHandoverId != null) continue; // iptal satırının kendisi listelenmez
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
        iptalEdildi: iptalliler.contains(r.id),
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
  ///
  /// İPTAL EDİLMİŞ kayıtlar TOPLAMA GİRMEZ: o para kuryeye geri verildi, "bugün alınan" değildir.
  /// Satır listede görünmeye devam eder (kanıt), yalnız bu toplamın dışında kalır.
  Future<int> araTahsilatToplami(DateTime localDate, {String? kuryeId}) async {
    final kayitlar = await araTahsilatlar(localDate, kuryeId: kuryeId);
    return kayitlar
        .where((k) => !k.iptalEdildi)
        .fold<int>(0, (s, k) => s + k.countedCashKurus);
  }

  /// Bir kapanışa bağlanmış devir id'leri (`day_closings.cash_handover_id`).
  Future<Set<String>> _kapanisaBagliDevirIdleri() async {
    final rows =
        await (db.select(db.dayClosings)..where((t) => t.cashHandoverId.isNotNull())).get();
    return rows.map((r) => r.cashHandoverId!).toSet();
  }

  /// İPTAL EDİLMİŞ devir id'leri — yani bir iptal satırının işaret ettiği ORİJİNALLER.
  Future<Set<String>> _iptalEdilmisDevirIdleri() async {
    final rows = await (db.select(db.cashHandovers)
          ..where((t) => t.reversesHandoverId.isNotNull()))
        .get();
    return rows.map((r) => r.reversesHandoverId!).toSet();
  }
}

/// Gün içinde alınmış TEK bir ara tahsilat (salt-okunur görünüm); kayıt append-only
/// `cash_handovers` satırıdır.
///
/// EKRAN BUGÜN YALNIZ "kim · ne zaman · sayılan" BASIYOR (`AraTahsilatKarti`). [expectedCashKurus]
/// ve [diffKurus] doldurulur ama HİÇBİR YERDE ÇİZİLMEZ — bu doc bir zamanlar "ekran beklenen ve
/// farkı da çizer" diyordu ve o cümle bir sonraki okuyucuyu "kanıt görünür" sanmaya götürürdü.
///
/// ALANLAR YİNE DE KALIR: BRIEF'in kuralı "eksik para KANIT olarak GÖRÜNÜR kalmalı" ve ara
/// tahsilat farkı şu an hiçbir ekranda görünmüyor — yani eksik olan alan değil, o alanı basan
/// satır. Silmek, boşluğu kapatmak yerine kalıcılaştırmak olurdu.
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
    this.iptalEdildi = false,
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

  /// Bu tahsilat sonradan İPTAL edildi mi (2026-08-13)? Kayıt silinmez; ters işaretli ikinci bir
  /// satır ([CashHandoverRepository.araTahsilatIptal]) onu geri alır ve bu bayrak onun izidir.
  ///
  /// Satır listede KALIR (soluk/üstü çizili çizilir) ama [CashHandoverRepository.araTahsilatToplami]
  /// dışındadır: olay olmuştur, kanıtı görünür kalır, parası geri verilmiştir.
  final bool iptalEdildi;
}
