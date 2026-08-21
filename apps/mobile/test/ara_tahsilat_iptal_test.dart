import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';

/// ARA TAHSİLAT İPTALİ (kullanıcı kararı 2026-08-13).
///
/// Yönetici yanlış alınmış bir ara tahsilatı geri alır. İPTAL, SİLME DEĞİLDİR: `cash_handovers`a
/// ters işaretli İKİNCİ bir satır yazılır (`reversesHandoverId` = orijinalin id'si). Orijinal satır
/// listede KALIR ve "iptal edildi" işaretlenir; yalnız toplamlardan düşer. BRIEF kırmızı çizgi #2:
/// para kayıtları silinmez/ezilmez, telafi kaydıyla düzeltilir.
///
/// ⚠️ BU DOSYANIN ASIL İŞİ [teslimEdilenNakit] KAPANIŞIDIR (aşağıdaki "para kapanışı" grubu).
/// İptal, kuryenin cebindeki parayı GERİ VERİR: orijinal(+) ile ters satır(−) birlikte sayılıp net
/// sıfır olmazsa, iptal edilen tutar hem patronun kasasında hem kuryenin cebinde YOK sayılır ve
/// akşam kapanışında açıklanamayan bir eksik olarak donar (kayıtlar append-only). Yani bu grup
/// kırılırsa özellik para kaybettiriyor demektir — diğer bütün iddialar ikincildir.
///
/// NEDEN AYRI DOSYA: `ara_tahsilat_test.dart` 1126 satır ve depo sınırı 500. Ayrım konuya göre:
/// orası tahsilatın ALINMASINI, burası GERİ ALINMASINI kilitler.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();

  /// TR takvim gününün UTC gün başı.
  DateTime gunBasiUtc(DateTime trGun) =>
      DateTime.utc(trGun.year, trGun.month, trGun.day).subtract(const Duration(hours: 3));

  /// Bugünün TR gününde KALMASI garanti "daha önce" damgası.
  ///
  /// `araTahsilat()` kaydı gerçek ŞİMDİ ile yazar; ledger kayıtlarını ona göre konumlandırmak
  /// zorundayız. Aynı milisaniyeye düşen iki kayıtta pencere süzgeci yazı-tura döner ve sahte
  /// kırık üretir — 5 dakikalık aralık bırakılıyor, gün sınırını aşacaksa gün içine kırpılıyor.
  String oncekiIso() {
    final simdi = DateTime.now().toUtc();
    final erken = simdi.subtract(const Duration(minutes: 5));
    final sinir = gunBasiUtc(bugun);
    return (erken.isBefore(sinir) ? sinir : erken).toIso8601String();
  }

  Future<void> kurye(String id, String ad) => db.into(db.users).insert(
      UsersCompanion.insert(id: id, name: ad, role: 'kurye', status: 'active'));

  Future<void> nakit(int kurus, {required String kuryeId, required String at}) =>
      writeLedgerEntry(db,
          entryType: 'payment',
          amountKurus: -kurus, // tahsilat NEGATİF yazılır; kasaya giren = −amount
          paymentType: 'nakit',
          collectedByUserId: kuryeId,
          occurredAt: at);

  /// Emre 90,00 ₺ topladı; patron 40,00 + 20,00 iki ara tahsilat aldı. Dönen id'ler sırayla
  /// birinci ve ikinci tahsilattır. Çoğu senaryo bu kurulumdan yürüyor: TEK tahsilatlı kurulum
  /// "iptal edilen satır toplamdan düşer" iddiasını 0'a karşı ölçerdi ve 0, her hatayı yutar.
  Future<(String, String)> ikiTahsilat() async {
    await kurye('k1', 'Emre');
    await nakit(9000, kuryeId: 'k1', at: oncekiIso());
    final devirler = CashHandoverRepository(db);
    final birinci = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
    final ikinci = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 2000);
    return (birinci, ikinci);
  }

  group('iptal TERS SATIR yazar (silme yok)', () {
    test('kurye korunur · tutar negatif · beklenen ve fark 0 · bağ dolu', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);
      final id = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final iptalId = await devirler.araTahsilatIptal(handoverId: id, iptalEdenUserId: 'p1');

      final satirlar = await db.select(db.cashHandovers).get();
      expect(satirlar, hasLength(2), reason: 'orijinal SİLİNMEZ; iptal ikinci satırdır');

      final ters = satirlar.firstWhere((r) => r.id == iptalId);
      // `from_user_id` ORİJİNALDEKİYLE AYNI kalmak ZORUNDA: pencere matematiği kuryenin cebini
      // bu alandan ölçüyor. İptali İPTAL EDENİN üstüne yazsaydık orijinal(+) ile ters satır(−)
      // farklı ceplere düşer ve kuryenin beklenen nakdi geri GELMEZDİ.
      expect(ters.fromUserId, 'k1', reason: 'iptal eden değil, PARANIN SAHİBİ kurye');
      expect(ters.toUserId, 'p1', reason: 'iptali kim yaptı — denetim izi');
      expect(ters.countedCashKurus, -4000);
      expect(ters.reversesHandoverId, id);
      // İptal bir MUTABAKAT DEĞİLDİR: eksik para iddiası da değildir. Orijinaldeki fark kanıt
      // olarak yerinde durur; iptale de fark yazsaydık aynı sapmayı iki kez suçlardık.
      expect(ters.expectedCashKurus, 0);
      expect(ters.diffKurus, 0);

      final orijinal = satirlar.firstWhere((r) => r.id == id);
      expect(orijinal.countedCashKurus, 4000, reason: 'orijinal EZİLMEZ');
      expect(orijinal.diffKurus, -5000, reason: 'orijinalin kanıtı yerinde kalır');
      expect(orijinal.reversesHandoverId, isNull);
    });

    test('sunucuya giden zarf iptal bağını taşır (damga UTC "Z")', () async {
      // Bağ zarfta gitmezse başka cihaz iptali TANIYAMAZ: orijinal orada hâlâ geçerli görünür ve
      // iki telefon aynı gün için farklı kasa rakamı gösterir.
      await db.syncState();
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);
      final id = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
      final iptalId = await devirler.araTahsilatIptal(handoverId: id);

      final olay = await (db.select(db.outbox)..where((t) => t.entityId.equals(iptalId)))
          .getSingle();
      expect(olay.entityType, 'cash_handover',
          reason: 'yeni bir op AÇILMAZ; eski sunucuda sessizce düşerdi');
      final zarf = jsonDecode(olay.payload) as Map<String, dynamic>;
      expect(zarf['reverses_handover_id'], id);
      expect(zarf['counted_cash_kurus'], -4000);
      expect(zarf['expected_cash_kurus'], 0);
      expect(zarf['diff_kurus'], 0);
      expect(olay.occurredAt, endsWith('Z'), reason: 'offset taşıyan damga sunucuda 3 saat kayar');
    });
  });

  group('okuma katmanı: satır KALIR, toplam DÜŞER', () {
    test('araTahsilatlar iptal SATIRINI listelemez, orijinali iptalEdildi:true döndürür',
        () async {
      final (birinci, ikinci) = await ikiTahsilat();
      await CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci);

      final liste = await CashHandoverRepository(db).araTahsilatlar(bugun);
      expect(liste.map((k) => k.id), [birinci, ikinci],
          reason: 'ters satır bağımsız bir tahsilat değil, DÜZELTMEDİR — listeye girseydi bayi '
              '"−40,00 ₺ tahsilat aldım" diye okunacak bir satır görürdü');
      expect(liste.first.iptalEdildi, isTrue);
      expect(liste.first.countedCashKurus, 4000, reason: 'kanıt görünür kalır');
      expect(liste.last.iptalEdildi, isFalse);
    });

    test('araTahsilatToplami iptal edilmiş kaydı SAYMAZ', () async {
      final (birinci, _) = await ikiTahsilat();
      final devirler = CashHandoverRepository(db);
      expect(await devirler.araTahsilatToplami(bugun), 6000, reason: 'iptalden önce');

      await devirler.araTahsilatIptal(handoverId: birinci);

      expect(await devirler.araTahsilatToplami(bugun), 2000,
          reason: 'o para kuryeye geri verildi; "bugün alınan" değildir');
      expect(await devirler.araTahsilatToplami(bugun, kuryeId: 'k1'), 2000);
    });

    test('gün sonu görünümü listeyi ve toplamı BİRLİKTE günceller', () async {
      // Ekran ikisini yan yana basıyor; ayrı yollardan gelselerdi kart "2 tahsilat · 60,00 ₺"
      // derken toplam 20,00 ₺ olabilirdi ve bayi hangisinin doğru olduğunu soramazdı.
      final (birinci, _) = await ikiTahsilat();
      await CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci);

      final g = await gunSonuGorunumu(db, bugun);
      expect(g.araTahsilatlar, hasLength(2));
      expect(g.araTahsilatlar.where((k) => !k.iptalEdildi), hasLength(1));
      expect(g.araTahsilatToplamiKurus, 2000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // PARA KAPANIŞI — bu grup kırılırsa özellik PARA KAYBETTİRİYOR demektir.
  //
  // `teslimEdilenNakit` ARA ve KAPANIŞ devirlerini birlikte sayar ve İPTAL SATIRLARINI SÜZMEZ —
  // bilinçli: o katman kuryenin CEBİNİ ölçer, cep ise paranın hangi gerekçeyle girip çıktığını
  // bilmez. Ters satır negatif olduğu için orijinaliyle birlikte NET SIFIR verir; kuryenin cebi
  // iptalden önceki hâline döner. Süzseydik orijinal(+) tek başına kalır ve iptal edilen para
  // kuryenin cebinden KALICI olarak silinirdi.
  // ═══════════════════════════════════════════════════════════════════════════════════════════
  group('para kapanışı: iptal parayı kuryeye GERİ VERİR', () {
    test('tek tahsilat iptal edilince beklenen nakit iptal ÖNCESİNE döner', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);

      final oncesi = (await devirler.onizle('k1')).expectedKurus;
      expect(oncesi, 9000, reason: 'hiç teslim yok; para tamamen kuryede');

      final id = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
      expect((await devirler.onizle('k1')).expectedKurus, 5000);
      expect(await devirler.teslimEdilenNakit(bugun, kuryeId: 'k1'), 4000);

      await devirler.araTahsilatIptal(handoverId: id);

      expect(await devirler.teslimEdilenNakit(bugun, kuryeId: 'k1'), 0,
          reason: 'orijinal(+4.000) ve ters satır(−4.000) BİRLİKTE sayılır → net sıfır');
      expect((await devirler.onizle('k1')).expectedKurus, oncesi,
          reason: 'kuryenin cebindeki para iptalden sonra doğru görünmeli');
    });

    test('duran tahsilat etkilenmez: yalnız iptal edilen geri döner', () async {
      final (birinci, _) = await ikiTahsilat();
      final devirler = CashHandoverRepository(db);
      expect((await devirler.onizle('k1')).expectedKurus, 3000, reason: '9.000 − 4.000 − 2.000');

      await devirler.araTahsilatIptal(handoverId: birinci);

      expect(await devirler.teslimEdilenNakit(bugun, kuryeId: 'k1'), 2000,
          reason: 'ayakta duran ikinci tahsilat cepten çıkmaya devam eder');
      expect((await devirler.onizle('k1')).expectedKurus, 7000, reason: '9.000 − 2.000');
      // Kuryeler kümesi bazlı gün okuması da aynı rakamı vermeli: iki farklı yol, tek gerçek.
      expect(await devirler.kuryelerinGunlukNetDegisimi(bugun), 7000);
    });

    test('ARDIŞIK iptal: iki tahsilat da geri alınınca cep başlangıca döner', () async {
      final (birinci, ikinci) = await ikiTahsilat();
      final devirler = CashHandoverRepository(db);

      await devirler.araTahsilatIptal(handoverId: birinci);
      await devirler.araTahsilatIptal(handoverId: ikinci);

      expect(await devirler.teslimEdilenNakit(bugun, kuryeId: 'k1'), 0);
      expect((await devirler.onizle('k1')).expectedKurus, 9000,
          reason: 'hiç tahsilat alınmamış gibi');
      expect(await devirler.araTahsilatToplami(bugun), 0);
      expect(await db.select(db.cashHandovers).get(), hasLength(4),
          reason: 'iki orijinal + iki ters satır; hiçbiri silinmedi');
    });
  });

  group('gün kapanışı iptali doğru yansıtır', () {
    test('KURYE kapsamı: kapanış sheet\'ine iptal öncesi rakam gitmez', () async {
      final (birinci, _) = await ikiTahsilat();
      final kapanislar = DayClosingRepository(db);

      final iptalOncesi =
          await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(iptalOncesi.expectedCashKurus, 3000);
      expect(iptalOncesi.dusulenKurus, 6000);

      await CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci);

      final on = await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(on.expectedCashKurus, 7000, reason: 'kuryede fiilen 70,00 ₺ var');
      expect(on.dusulenKurus, 2000, reason: 'teslim edilen yalnız ayakta duran tahsilat');
      expect(on.gunNakitKurus - on.dusulenKurus, on.expectedCashKurus,
          reason: 'üçlü kimlik iptalden sonra da kapanmalı');
      expect(on.dusulenKalem, DusulenKalem.teslimEdilen);
    });

    test('GÜN kapsamı: patronun kasasından iptal edilen tutar DÜŞER', () async {
      final (birinci, _) = await ikiTahsilat();
      await CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.gunNakitKurus, 9000, reason: 'günün nakdi devirle/iptalle KÜÇÜLMEZ');
      expect(on.expectedCashKurus, 2000,
          reason: 'patron 60,00 ₺ almıştı, 40,00 ₺ geri verdi; kasasında 20,00 ₺ kaldı');
      expect(on.dusulenKurus, 7000, reason: 'geri verilen para yeniden KURYEDE');
      expect(on.expectedCashKurus + on.dusulenKurus, on.gunNakitKurus);
    });

    test('iptal sonrası kurye hesabı kapatılınca arşive DOĞRU tutar donar, fark 0', () async {
      // Kayıtlar append-only: buraya yanlış bir "beklenen" donarsa yalan KALICI olur.
      final (birinci, _) = await ikiTahsilat();
      await CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci);

      final id = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 7000, // kurye cebindekinin tamamını verdi
        alsoHandover: true,
        localDate: bugun,
      );

      final kapanis = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      expect(kapanis.expectedCashKurus, 7000,
          reason: 'iptal görülmeseydi 3.000 donardı ve kurye "FAZLA 4.000" damgası yerdi');
      expect(kapanis.diffKurus, 0);
    });
  });

  // Reddedilen hâllerin HEPSİ `StateError` atar ve mesaj kullanıcıya OLDUĞU GİBİ basılır —
  // "bir şeyler ters gitti" demek, tam olarak NE olduğunu bilirken bilgi saklamaktır. Metinler
  // SÖZLEŞMEDİR: ekran onları toast olarak gösteriyor.
  group('reddedilen iptaller', () {
    /// Hata mesajını da doğrulayan eşleştirici.
    Matcher hataMetni(String mesaj) =>
        throwsA(isA<StateError>().having((e) => e.message, 'mesaj', mesaj));

    test('olmayan id', () async {
      await ikiTahsilat();
      expect(
        () => CashHandoverRepository(db).araTahsilatIptal(handoverId: 'yok-boyle-bir-kayit'),
        hataMetni('Ara tahsilat kaydı bulunamadı; ekranı yenileyip tekrar deneyin'),
      );
    });

    test('ZATEN iptal edilmiş kayıt ikinci kez iptal edilemez', () async {
      // İkinci iptal parayı İKİNCİ kez geri verirdi: kuryenin cebi 40,00 ₺ şişer ve akşam
      // sayımda açıklanamayan bir FAZLA çıkardı.
      final (birinci, _) = await ikiTahsilat();
      final devirler = CashHandoverRepository(db);
      await devirler.araTahsilatIptal(handoverId: birinci);

      expect(() => devirler.araTahsilatIptal(handoverId: birinci),
          hataMetni('Bu ara tahsilat zaten iptal edilmiş'));
      expect(await db.select(db.cashHandovers).get(), hasLength(3),
          reason: 'reddedilen iptal HİÇBİR satır yazmaz');
      expect((await devirler.onizle('k1')).expectedKurus, 7000, reason: 'para iki kez dönmedi');
    });

    test('İPTAL SATIRININ KENDİSİ iptal edilemez', () async {
      final (birinci, _) = await ikiTahsilat();
      final devirler = CashHandoverRepository(db);
      final iptalId = await devirler.araTahsilatIptal(handoverId: birinci);

      expect(() => devirler.araTahsilatIptal(handoverId: iptalId),
          hataMetni('Bu satır zaten bir iptal kaydı; iptal edilemez'));
    });

    test('KAPANIŞA BAĞLI devir (ara tahsilat değil) iptal edilemez', () async {
      // "Ara" olmanın tanımı ilişkidendir. Kapanışa bağlı devri geri almak, arşivdeki mutabakatı
      // sessizce boşa düşürürdü: kapanış hâlâ "90,00 ₺ teslim alındı" derken defterde o para
      // geri dönmüş olurdu.
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 9000,
        alsoHandover: true,
        localDate: bugun,
      );
      final devir = (await db.select(db.cashHandovers).get()).single;

      expect(
        () => CashHandoverRepository(db).araTahsilatIptal(handoverId: devir.id),
        hataMetni('Bu devir bir hesap kapanışına ait; ara tahsilat değildir, iptal edilemez'),
        reason: 'kapsam da kapalı ama ÖNCE bu kapı konuşmalı — sebep daha kesin',
      );
    });

    test('GÜN kapandıysa iptal edilemez', () async {
      final (birinci, _) = await ikiTahsilat();
      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 6000, localDate: bugun);

      expect(() => CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci),
          hataMetni('Gün hesabı kapandı; ara tahsilat iptal edilemez'));
    });

    test('KURYENİN hesabı kapandıysa iptal edilemez; diğer kurye serbest kalır', () async {
      final (birinci, _) = await ikiTahsilat();
      await kurye('k2', 'Deniz');
      await nakit(3000, kuryeId: 'k2', at: oncekiIso());
      final devirler = CashHandoverRepository(db);
      final k2Tahsilat = await devirler.araTahsilat(fromUserId: 'k2', countedCashKurus: 3000);

      // `alsoHandover: false` — k1'in ara tahsilatları hiçbir kapanışa BAĞLANMAZ, yani hâlâ
      // "ara"dır. Reddin sebebi ilişki değil, KİLİTTİR.
      await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier, userId: 'k1', countedCashKurus: 3000, localDate: bugun);

      expect(() => devirler.araTahsilatIptal(handoverId: birinci),
          hataMetni('Bu kuryenin hesabı kapandı; ara tahsilat iptal edilemez'));
      // Kapı KAPSAM BAZLIDIR: bir kuryenin hesabının kapanması ötekini kilitlemez.
      await devirler.araTahsilatIptal(handoverId: k2Tahsilat);
      expect((await devirler.araTahsilatlar(bugun, kuryeId: 'k2')).single.iptalEdildi, isTrue);
    });

    test('ALMA yolunun kapalı-kapsam metni DEĞİŞMEDİ', () async {
      // Aynı kapı iki eylemi tutuyor ve cümlenin sonu eyleme göre değişiyor. Alma yolundaki
      // eski metin bir sözleşmedir: `ui_ara_tahsilat_test.dart` onu ekranda arıyor.
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 5000, localDate: bugun);

      expect(
        () => CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 1000),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'mesaj', 'Gün hesabı kapandı; ara tahsilat alınamaz')),
      );
    });
  });
}
