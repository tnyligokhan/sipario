// GÜNÜN VERESİYELERİ — "bugün ne kadar borç yazdım" sorusunun read-model'i.
//
// ══ NEDEN AYRI BİR OKUMA GEREKTİ (saha isteği 2026-08-18) ═══════════════════════════════════
// Gün özetinde "Açık Veresiye" kartı vardı ama o kart ANLIK BAKİYELERİ gösterir
// (`customers.balance_kurus`): aylardır birikmiş borcun toplamı. Bugün yazılan veresiye orada
// diğer her şeyin içinde erir — bayi "bugün kaç lira veresiye verdim" sorusunu SORAMAZ, çünkü
// 48.000 ₺'lik toplamın hangi kısmının bugüne ait olduğunu hiçbir ekran söylemiyordu.
//
// ══ NEDEN "GÜNÜN DEBIT'LERİ" DEĞİL ════════════════════════════════════════════════════════
// ⚠️ Bu, en kolay yanlış cevaptır. `OrderRepository.deliver` HER TESLİMDE tutarın TAMAMI kadar
// `debit` yazar — nakit teslimde bile. Borç, hemen ardından gelen `payment` satırıyla kapanır.
// Yani günün `debit` toplamı ciroya eşittir, veresiyeye değil; o rakamı "veresiye" diye
// göstermek nakit satışları da borç saymak olurdu.
//
// DOĞRU CEVAP SİPARİŞ BAZINDA NETTİR: bir siparişin o güne düşen hareketleri toplanır
// (`debit` + `payment` + `discount`) ve kalan POZİTİF fark o siparişin veresiyesidir. Kısmi
// ödeme kendiliğinden doğru çıkar: 200 ₺'lik siparişin 120'si alınmışsa veresiye 80'dir.
//
// ⚠️ NET **SİPARİŞ BAZINDA** ALINIR, GÜN GENELİNDE DEĞİL. Gün geneli tek bir toplam alınsaydı
// bir müşterinin fazla ödemesi (eski borcunu da kapatması) başka bir siparişin veresiyesini
// SESSİZCE gizlerdi — iki ayrı olay birbirini götürür, liste ile toplam ayrışırdı. Bu depoda
// `gunSonuBildirimVerisi` tam olarak öyle hesaplıyordu ve negatife düşmesin diye sonucu sıfıra
// kırpıyordu; kırpma, sorunun kendisini değil belirtisini örtüyordu.
//
// GEÇMİŞ SİPARİŞİN BUGÜNKÜ TAHSİLATI BU LİSTEYE GİRMEZ ve girmemelidir: o siparişin `debit`i
// bugüne düşmediği için grubun neti negatif çıkar ve grup elenir. Yani bugün kapanan eski bir
// borç, "bugün yazılmış veresiye"yi azaltamaz — iki farklı gündür.


import '../data/app_database.dart';
import '../data/tr_gun.dart';
import 'islem_sahibi.dart';

/// Bugün yazılmış TEK bir veresiye kalemi.
class VeresiyeSatiri {
  const VeresiyeSatiri({
    required this.musteriAd,
    required this.kurus,
    required this.occurredAt,
    this.adres,
    this.orderId,
    this.elle = false,
  });

  final String musteriAd;

  /// Müşterinin birincil adresi; yoksa null.
  final String? adres;

  /// Bugün borçta KALAN tutar (pozitif kuruş) — kısmi ödemede yalnız ödenmeyen kısım.
  final int kurus;

  /// Grubun EN GEÇ hareketinin anı (UTC ISO) — sıralama ve saat gösterimi bundan.
  final String occurredAt;

  /// Bağlı sipariş; elle borç girişinde null.
  final String? orderId;

  /// Siparişten değil ELLE yazılmış borç (`LedgerRepository.borcEkle`).
  ///
  /// Ayırt edilir çünkü ikisi farklı sorulara cevaptır: sipariş veresiyesi "sattım, parasını
  /// almadım", elle borç "defteri düzelttim / eski hesabı taşıdım". Aynı rozetle göstermek,
  /// düzeltmeleri satış sanmaya yol açardı.
  final bool elle;
}

/// Bir siparişin (ya da elle girişin) günlük net borç hesabı — SAF, doğrudan testlenir.
///
/// Ekranın ve toplamın AYNI koddan çıkması için ayrı bir sınıf: gruplama kuralı iki yerde
/// yazılsaydı liste ile başlıktaki rakam ayrışırdı (bu depoda gün sonu tanımında üç kez oldu).
class VeresiyeGrubu {
  VeresiyeGrubu({required this.anahtar, required this.orderId, required this.customerId});

  /// Gruplama anahtarı: sipariş kimliği ya da elle girişin kendi kayıt kimliği.
  final String anahtar;
  final String? orderId;
  final String? customerId;

  int net = 0;
  String enGecOccurredAt = '';
  bool elleGiris = false;

  void ekle(LedgerEntry e) {
    net += e.amountKurus;
    if (e.occurredAt.compareTo(enGecOccurredAt) > 0) enGecOccurredAt = e.occurredAt;
  }

  /// Bu grup bugün bir veresiye bıraktı mı?
  bool get veresiyeVar => net > 0;
}

/// Günün veresiye hareketlerini gruplar. [kayitlar] YALNIZ o güne düşen defter satırları olmalı.
///
/// `credit` (elle alacak/indirim) de nette sayılır: borcu azaltan her hareket aynı gün içinde
/// yazıldıysa o borcu gerçekten azaltmıştır. Dışarıda bırakmak, aynı gün düzeltilmiş bir hatayı
/// hâlâ borç göstermek olurdu.
List<VeresiyeGrubu> veresiyeGruplari(List<LedgerEntry> kayitlar) {
  final gruplar = <String, VeresiyeGrubu>{};
  for (final e in kayitlar) {
    // ⚠️ GİDER BURAYA GİREMEZ (2026-08-25) ve bu satır bir savunma değil, ZORUNLULUKTUR: gider
    // satırının müşterisi de siparişi de YOKTUR ve tutarı POZİTİFTİR — yani aşağıdaki gruplama
    // onu kendi başına bir gruba koyar, `net > 0` çıkar ve akşam benzin parası bayiye
    // "Müşterisiz kayıt · bugün yazılan veresiye" diye görünürdü. Kasadan çıkan para bir alacak
    // değildir; tipin kendisi elenir, tutarın işareti bunu yakalayamaz.
    if (e.entryType == 'expense') continue;
    // Kasaya dokunmayan `debit`/`credit`/`discount` ve siparişe bağlı `payment` hepsi girer;
    // ayrım grubun netinde kendiliğinden oluşur.
    final orderId = e.relatedOrderId;
    final anahtar = orderId ?? e.id;
    final grup = gruplar.putIfAbsent(
      anahtar,
      () => VeresiyeGrubu(anahtar: anahtar, orderId: orderId, customerId: e.customerId),
    );
    // Siparişsiz kayıt tek başına bir gruptur ve yalnız `debit` ise anlamlıdır: siparişsiz bir
    // `payment` (eski borç tahsilatı) kendi grubunda negatif net verir ve zaten elenir.
    if (orderId == null && e.entryType == 'debit') grup.elleGiris = true;
    grup.ekle(e);
  }
  return gruplar.values.where((g) => g.veresiyeVar).toList();
}

/// Günün veresiye okumaları. Hiçbir tabloya YAZMAZ.
class GunVeresiyeRepository {
  GunVeresiyeRepository(this.db);
  final AppDatabase db;

  /// [localDate] gününde yazılan veresiyeler, EN YENİ ÜSTTE.
  ///
  /// [userId] verilirse kapsam daralır ve KAPSAM İKİ KAYNAKTAN çözülür, çünkü iki kayıt tipi
  /// atfını farklı yerde taşır: sipariş veresiyesinin sahibi siparişi TESLİM EDEN kişidir
  /// ([siparisSahibi] — `delivered_by_user_id`, yoksa eski kayıtlarda atama), elle borç
  /// girişinin sahibi ise onu YAZAN kişidir (`collected_by_user_id`). Tek alana bakılsaydı
  /// kurye kapsamında sipariş veresiyeleri toptan kaybolurdu.
  ///
  /// ⚠️ ESKİDEN SİPARİŞ VERESİYESİNİN SAHİBİ "ATANAN KURYE"YDİ (2026-08-20'de düzeltildi).
  /// Saha bulgusu: 1.200 ₺lik sipariş Ali'ye aktarıldı, patron siparişi kendisi teslim edip
  /// veresiye işaretledi — borç ALİ'nin hesabında göründü. Atama bir niyettir; borcu doğuran
  /// olay teslimdir ve onu kim yaptıysa borç onundur.
  Future<List<VeresiyeSatiri>> gununVeresiyeleri(
    DateTime localDate, {
    String? userId,
    String? haric,
  }) async {
    final hepsi = await db.select(db.ledgerEntries).get();
    final gunun = hepsi.where((e) => ayniTrGunIso(e.occurredAt, localDate)).toList();
    if (gunun.isEmpty) return const [];

    final gruplar = veresiyeGruplari(gunun);
    if (gruplar.isEmpty) return const [];

    final siparisIdler = {
      for (final g in gruplar)
        if (g.orderId != null) g.orderId!,
    };
    final siparisler = siparisIdler.isEmpty
        ? const <Order>[]
        : await (db.select(db.orders)..where((t) => t.id.isIn(siparisIdler))).get();
    final sahip = {
      for (final o in siparisler)
        o.id: siparisSahibi(
          deliveredByUserId: o.deliveredByUserId,
          assignedUserId: o.assignedUserId,
        ),
    };
    // İPTAL EDİLEN SİPARİŞ ELENİR: iptalde borç ters kayıtla kapanmıyorsa bile o sipariş
    // teslim edilmemiştir ve veresiye üretmez. `deleted_at` dolu olan da aynı sebeple düşer.
    final gecerli = {
      for (final o in siparisler)
        if (o.deletedAt == null && o.status != 'cancelled') o.id,
    };

    // Elle girişlerin atfı kayıttan gelir; sipariş grubunun atfı siparişten.
    final elleAtif = {
      for (final e in gunun) e.id: e.collectedByUserId,
    };

    final secilen = <VeresiyeGrubu>[];
    for (final g in gruplar) {
      if (g.orderId != null && !gecerli.contains(g.orderId)) continue;
      if (userId != null || haric != null) {
        final grupSahibi = g.orderId != null ? sahip[g.orderId] : elleAtif[g.anahtar];
        if (!kapsamaDusuyor(grupSahibi, userId: userId, haric: haric)) continue;
      }
      secilen.add(g);
    }
    if (secilen.isEmpty) return const [];

    final musteriIdler = {
      for (final g in secilen)
        if (g.customerId != null) g.customerId!,
    };
    final musteriler = musteriIdler.isEmpty
        ? const <Customer>[]
        : await (db.select(db.customers)..where((t) => t.id.isIn(musteriIdler))).get();
    final adresler = musteriIdler.isEmpty
        ? const <CustomerAddressesData>[]
        : await (db.select(db.customerAddresses)
              ..where((t) => t.customerId.isIn(musteriIdler))
              ..where((t) => t.deletedAt.isNull()))
            .get();

    final adMap = {for (final m in musteriler) m.id: m.name};
    final adresMap = <String, String>{};
    for (final a in adresler) {
      if (a.isPrimary || !adresMap.containsKey(a.customerId)) {
        adresMap[a.customerId] = a.addressText;
      }
    }

    final satirlar = [
      for (final g in secilen)
        VeresiyeSatiri(
          // ⚠️ MÜŞTERİSİZ VERESİYE OLMAZ ama savunma bırakılıyor: müşterisiz tezgâh satışı
          // veresiye kalamaz (borcu kime yazacağız?). Yine de böyle bir kayıt görülürse
          // listede GÖRÜNSÜN — sessizce elemek, bir veri hatasını gizlemek olurdu.
          musteriAd: g.customerId == null
              ? 'Müşterisiz kayıt'
              : (adMap[g.customerId] ?? 'Müşteri'),
          adres: g.customerId == null ? null : adresMap[g.customerId],
          kurus: g.net,
          occurredAt: g.enGecOccurredAt,
          orderId: g.orderId,
          elle: g.elleGiris,
        ),
    ];
    satirlar.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return satirlar;
  }

  /// Günün veresiye TOPLAMI (pozitif kuruş). [gununVeresiyeleri] ile AYNI koddan çıkar —
  /// liste ile başlıktaki rakam ayrışamaz.
  Future<int> toplam(DateTime localDate, {String? userId, String? haric}) async {
    final satirlar = await gununVeresiyeleri(localDate, userId: userId, haric: haric);
    return satirlar.fold<int>(0, (s, v) => s + v.kurus);
  }
}
