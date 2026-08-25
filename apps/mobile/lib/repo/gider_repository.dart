// SAHA GİDERİ — kasadan çıkan nakdin defter kaydı (kullanıcı isteği 2026-08-25).
//
// ══ NEDEN VAR ═══════════════════════════════════════════════════════════════════════════════
// Yetki matrisinde "Saha Gideri Girme (Benzin vb.)" satırı aylardır duruyordu ve açıklaması
// "Benzin, tamir gibi masrafları kasadan düşer" diyordu — ama BÖYLE BİR YOL YOKTU. Yetkiyi açan
// bayi hiçbir şey açmıyordu. Ürün tarafındaki karşılığı şuydu: kuryenin yolda 200 ₺ benzin
// alması akşam kasada 200 ₺ EKSİK olarak çıkıyor ve mutabakat farkı kalıcı olarak "eksik para"
// diye arşive donuyordu. Gider, o farkın adıdır.
//
// ══ NEDEN YENİ TABLO DEĞİL, DEFTER SATIRI ═══════════════════════════════════════════════════
// Gider bir PARA HAREKETİDİR ve bu ürünün para hareketleri `ledger_entries`tedir. Yeni bir tablo
// açmak; yeni bir senkron `op`u, yeni bir RLS ilkesi, yeni bir çakışma kuralı ve — en pahalısı —
// kasa mutabakatının İKİNCİ bir kaynağı demekti. Defter satırı olarak yazıldığında kuryenin
// cebindeki para (`CashHandoverRepository._pencerede`), günün kasası (`DayEndRepository`) ve
// kapanış beklentisi (`DayClosingRepository.onizle`) gideri KENDİLİĞİNDEN görür; üç yerin de
// ayrı ayrı öğrenmesi gerekmez. Şemaya eklenen tek şey `entry_type`a bir DEĞER olmuştur.
//
// ══ ALANLARIN ANLAMI ════════════════════════════════════════════════════════════════════════
//  • `entry_type = 'expense'`, `amount_kurus` POZİTİF (kasadan çıkan), iptalinde NEGATİF.
//  • `payment_type = 'nakit'` ZORUNLU — "kasaya dokundu" invariant'ı (DECISIONS Faz 3) bu alanla
//    işler; taşımayan satırı kasa sorguları hiç görmez ve gider görünmez bir kayda dönerdi.
//    v1'de gider YALNIZ NAKİTTİR: bu ekranın sorusu "kasada ne kalmalı"dır ve karttan ödenen bir
//    masraf çekmecedeki paraya dokunmaz. Kâr-zarar defteri ayrı bir iştir, burada başlatılmaz.
//  • `customer_id = null` — giderin müşterisi yoktur. Dolu olsaydı sunucudaki bakiye yeniden
//    hesabı o müşterinin borcunu gidere göre şişirirdi (tüm entry_type'lar borç-deltasıdır).
//  • `collected_by_user_id` = parayı HARCAYAN. Alanın adı "tahsil eden"dir ama işlevi "bu para
//    kimin kasasından geçti"dir ve kapsam süzgeçlerinin tamamı (gün özeti, kurye penceresi) bu
//    alandan okur. İkinci bir atıf alanı açmak, kapsamın iki yerden çözülmesi olurdu.
//
// ══ KİME YAZILIR ════════════════════════════════════════════════════════════════════════════
// Ekranda SEÇİLİ KAPSAM kimse ona (kurye kapsamındaysa o kuryeye), gün hesabında ise gideri
// GİREN kullanıcıya. Ayrı bir "kim harcadı" seçicisi konmadı: patron Ali'nin benzinini yazmak
// istiyorsa kapsamı Ali'ye çevirir — ara tahsilat almak için yaptığı hareketin aynısı. İki ayrı
// yol açmak, aynı kararın iki yerden verilmesi demekti.
//
// ══ YALNIZ BUGÜNE YAZILIR ═══════════════════════════════════════════════════════════════════
// `occurred_at` HER ZAMAN ŞİMDİdir (düzeltilmiş sunucu saati). Geçmiş bir güne gider yazmak,
// kapanmış ya da kapanmaya hazır bir günün kasasını geriye dönük değiştirmek olurdu — ara
// tahsilatta da aynı kapı kapalıdır. Ekran geçmiş bir gündeyken düğmeyi hiç çizmez.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/tr_gun.dart';
import 'day_closing_repository.dart';
import 'islem_sahibi.dart';
import 'ledger_ops.dart';

/// Gün özetinde listelenen TEK bir gider (salt-okunur görünüm).
class GiderSatiri {
  const GiderSatiri({
    required this.id,
    required this.kurus,
    required this.occurredAt,
    required this.harcayanId,
    required this.harcayanAd,
    this.aciklama,
    this.iptalEdildi = false,
  });

  final String id;

  /// Kasadan çıkan tutar (POZİTİF kuruş).
  final int kurus;

  /// UTC ISO. Ekran TR saatine çevirir.
  final String occurredAt;

  /// `collected_by_user_id` — parayı harcayan kişi; eski/atıfsız kayıtta null.
  final String? harcayanId;

  /// `users` aynasından çözülen ad; kullanıcı silinmişse boş (kayıt KANIT olarak kalır).
  final String harcayanAd;

  /// Serbest açıklama ("Benzin", "Lastik tamiri"). Boş olabilir.
  final String? aciklama;

  /// Sonradan İPTAL edildi mi? Kayıt silinmez; ters işaretli ikinci bir satır onu geri alır ve
  /// bu bayrak onun izidir (ara tahsilat iptalinin birebir aynı deseni).
  ///
  /// Satır listede KALIR (üstü çizili) ama toplamdan düşer: olay olmuştur, kanıtı görünür kalır.
  final bool iptalEdildi;
}

/// Saha gideri yazma + okuma. Tek yazma yolu burasıdır.
class GiderRepository {
  GiderRepository(this.db);
  final AppDatabase db;

  /// Kasadan nakit çıkışı yazar ve kayıt kimliğini döner.
  ///
  /// [kurus] POZİTİF verilir; sıfır ya da negatif [ArgumentError] atar — "0 ₺ gider" bir olay
  /// değildir ve negatif gider, iptalin adı çalınmış hâlidir ([iptal] kullanılır).
  ///
  /// [harcayanId] verilmezse oturumdaki kullanıcıya yazılır. KAPANMIŞ KAPSAMA YAZMAZ
  /// ([StateError]): kapanış o anın gerçeğini dondurur ve kapandıktan sonra o güne düşen yeni bir
  /// gider, arşivi sessizce yalancı çıkarırdı (ara tahsilatla AYNI kapı).
  Future<String> ekle({
    required int kurus,
    String? aciklama,
    String? harcayanId,
  }) async {
    if (kurus <= 0) {
      throw ArgumentError.value(kurus, 'kurus', 'Gider tutarı sıfırdan büyük olmalı');
    }
    final meta = await db.syncState();
    final harcayan = harcayanId ?? meta.userId;

    final engel = await _kapaliKapsamEngeli(harcayan, eylem: 'gider eklenemez');
    if (engel != null) throw StateError(engel);

    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final not = (aciklama ?? '').trim();

    late String id;
    await db.transaction(() async {
      id = await writeLedgerEntry(
        db,
        entryType: 'expense',
        amountKurus: kurus, // POZİTİF: kasadan çıkan
        paymentType: 'nakit',
        collectedByUserId: harcayan,
        note: not.isEmpty ? null : not,
        occurredAt: at,
        deviceId: meta.deviceId,
      );
    });
    return id;
  }

  /// Bir gideri İPTAL eder — kayıt SİLİNMEZ, ters işaretli İKİNCİ bir gider satırı yazılır
  /// (BRIEF kırmızı çizgi #2; `cash_handovers.reversesHandoverId` deseninin aynısı).
  ///
  /// Ters satır ORİJİNALİN atfını ve ödeme türünü devralır: para hangi cepten çıktıysa oraya geri
  /// döner. İptali yazan kişinin üstüne yazsaydık orijinal(−) ile iptal(+) farklı ceplere düşer,
  /// kuryenin beklenen nakdi geri gelmezdi (ara tahsilat iptalinde ödenmiş ders).
  ///
  /// Kayıt yoksa / gider değilse / zaten iptal edilmişse / kendisi bir iptal satırıysa / o günün
  /// kapsamı kapanmışsa [StateError] atar. Mesajlar kullanıcıya OLDUĞU GİBİ basılır.
  Future<String> iptal({required String giderId, String? iptalEdenUserId}) async {
    final hedef = await (db.select(db.ledgerEntries)..where((t) => t.id.equals(giderId)))
        .getSingleOrNull();
    if (hedef == null) {
      throw StateError('Gider kaydı bulunamadı; ekranı yenileyip tekrar deneyin');
    }
    if (hedef.entryType != 'expense') {
      throw StateError('Bu kayıt bir gider değil; iptal edilemez');
    }
    if (hedef.reversesEntryId != null) {
      throw StateError('Bu satır zaten bir iptal kaydı; iptal edilemez');
    }
    if ((await _iptalEdilmisIdler()).contains(hedef.id)) {
      throw StateError('Bu gider zaten iptal edilmiş');
    }

    // KAPI GİDERİN KENDİ GÜNÜNE BAKAR, bugüne değil: dün yazılmış bir gideri bugün iptal etmek,
    // dünün kapanmış kasasını değiştirmek olurdu. `ekle` bugüne yazdığı için orada iki gün aynı
    // gündür; burada değildir.
    final gun = trGunu(DateTime.parse(hedef.occurredAt).toUtc());
    final engel = await _kapaliKapsamEngeli(
      hedef.collectedByUserId,
      gun: gun,
      eylem: 'gider iptal edilemez',
    );
    if (engel != null) throw StateError(engel);

    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);

    late String id;
    await db.transaction(() async {
      id = await writeLedgerEntry(
        db,
        entryType: 'expense',
        amountKurus: -hedef.amountKurus, // ters işaret: para kasaya geri döner
        paymentType: hedef.paymentType,
        collectedByUserId: hedef.collectedByUserId,
        reversesEntryId: hedef.id,
        note: hedef.note,
        occurredAt: at,
        deviceId: meta.deviceId,
      );
    });
    // İptali YAZAN kişi kayda geçmez ve bu bilinçli: `ledger_entries`te "işlemi yapan" diye bir
    // alan yok, `collected_by_user_id` ise cebin sahibidir. Uydurma bir alana yazmaktansa
    // eksikliği dürüstçe taşımak doğru — cihaz kimliği (`device_id`) yine de kayıtta durur.
    return id;
  }

  /// [localDate] TR gününe düşen giderler, EN YENİ ÜSTTE.
  ///
  /// İPTAL SATIRLARI LİSTEDE GÖRÜNMEZ, İPTAL EDİLEN ORİJİNAL KALIR: iptal bağımsız bir gider
  /// değil bir DÜZELTMEDİR; listeye girseydi bayi "−200,00 ₺ gider" diye okunacak bir satır
  /// görürdü. Orijinal kalır ve [GiderSatiri.iptalEdildi] ile işaretlenir.
  ///
  /// Kapsam süzgeci gün özetiyle ORTAKTIR ([defterKapsamSuzgeci]) — "Elemanlar" ve tek kurye
  /// kapsamları burada da aynı kuralla çözülür.
  Future<List<GiderSatiri>> gunGiderleri(
    DateTime localDate, {
    String? userId,
    String? haric,
  }) async {
    final sorgu = db.select(db.ledgerEntries)
      ..where((t) => t.entryType.equals('expense'));
    sorgu.where((t) =>
        defterKapsamSuzgeci(t, userId: userId, haric: haric) ?? const Constant(true));
    final satirlar = await sorgu.get();
    if (satirlar.isEmpty) return const [];

    // İPTAL KÜMESİ GÜNE GÖRE SÜZÜLMEZ: iptal, orijinalden farklı bir TR gününe düşebilir
    // (23:50'de yazılan gider 00:10'da iptal edilir). Kümeyi günle daraltsaydık orijinal, kendi
    // gününde iptal edilmemiş gibi görünmeye devam ederdi.
    final iptalliler = await _iptalEdilmisIdler();
    final adlar = {for (final u in await db.select(db.users).get()) u.id: u.name};

    final sonuc = <GiderSatiri>[];
    for (final e in satirlar) {
      if (e.reversesEntryId != null) continue; // iptal satırının kendisi listelenmez
      if (!ayniTrGunIso(e.occurredAt, localDate)) continue;
      sonuc.add(GiderSatiri(
        id: e.id,
        kurus: e.amountKurus,
        occurredAt: e.occurredAt,
        harcayanId: e.collectedByUserId,
        harcayanAd: adlar[e.collectedByUserId] ?? '',
        aciklama: e.note,
        iptalEdildi: iptalliler.contains(e.id),
      ));
    }
    sonuc.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sonuc;
  }

  /// İPTAL EDİLMİŞ gider id'leri — bir iptal satırının işaret ettiği ORİJİNALLER.
  Future<Set<String>> _iptalEdilmisIdler() async {
    final rows = await (db.select(db.ledgerEntries)
          ..where((t) => t.entryType.equals('expense') & t.reversesEntryId.isNotNull()))
        .get();
    return rows.map((r) => r.reversesEntryId!).toSet();
  }

  /// [gun] gününde kapanmış bir kapsam [eylem]i engelliyorsa hata metni, engel yoksa null.
  /// [gun] verilmezse düzeltilmiş saatle bugün.
  Future<String?> _kapaliKapsamEngeli(
    String? harcayanId, {
    DateTime? gun,
    required String eylem,
  }) async {
    final hedefGun = gun ?? await bugunTrDuzeltilmis(db);
    final kapanislar = DayClosingRepository(db);
    if (await kapanislar.kapaliMi(ClosingScope.day, localDate: hedefGun)) {
      return 'Gün hesabı kapandı; $eylem';
    }
    if (harcayanId != null &&
        await kapanislar.kapaliMi(ClosingScope.courier,
            userId: harcayanId, localDate: hedefGun)) {
      return 'Bu kişinin hesabı kapandı; $eylem';
    }
    return null;
  }
}
