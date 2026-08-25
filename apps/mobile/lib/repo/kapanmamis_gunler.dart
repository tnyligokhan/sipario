// KAPANMAMIŞ GÜNLER — "kapatmadığınız gün/günleriniz var" (kullanıcı isteği 2026-08-21).
//
// ══ HANGİ ŞİKÂYETİ KAPATIYOR ════════════════════════════════════════════════════════════════
// "Kapanmayan günler bir sonraki güne aktarılıyor." Doğru gözlem, ama AKTARMA BİR HATA DEĞİL:
// kuryenin mutabakat penceresi bilerek ALTTAN AÇIKTIR (`CashHandoverRepository._pencere`) —
// cep gece yarısında boşalmaz. Dün toplanıp teslim edilmemiş para bugün de kuryededir ve
// beklenen nakit onu göstermek ZORUNDADIR; pencereyi her gece sıfırlamak, teslim edilmemiş
// parayı sessizce silmek olurdu.
//
// Yanlış olan şey ARİTMETİK değil GÖRÜNÜRLÜKtü: bayi devreden tutarı görüyor ama nereden
// geldiğini göremiyordu. Bu dosya eksik yarıyı ekler — hangi günlerin kapanmadığını SÖYLER ve
// kapatılabilir kılar. Para formüllerinin hiçbirine dokunulmadı.
//
// ══ NEDEN SINIRLI BİR PENCERE (kural) ═══════════════════════════════════════════════════════
// Kapanış bu üründe ZORUNLU DEĞİLDİR; hiç kapanış yapmayan bayi çoktur (BRIEF: tek kişilik
// bayi). "Kapanmamış gün" tanımını kurulumdan bugüne uzatsaydık o bayi 200 satırlık bir duvar
// görür ve uyarı KÖRLEŞİRDİ — hiç uyarmamaktan daha kötü bir sonuç.
//
// İki sınır birlikte uygulanır ve DAR OLANI kazanır:
//   1. Bugünden geriye en fazla [kVarsayilanGerideMax] gün.
//   2. Son GEÇERLİ gün kapanışından öncesine İNİLMEZ — kapatılmış bir gün zaten kapalıdır ve
//      ondan öncesi bilinçli olarak geride bırakılmıştır.
//
// 14 günün gerekçesi mutabakattır, estetik değil: daha eski bir günün kasası artık SAYILAMAZ
// (para çoktan çekmeceden çıktı). O günü "kapatmak" bir mutabakat değil, tarih düşürmektir.
//
// ══ BUGÜN LİSTEDE YOKTUR ════════════════════════════════════════════════════════════════════
// Bugün henüz kapanmadı, KAPANMAMIŞ değil. Onu listeye koymak, her sabah kendiliğinden doğan
// bir uyarı üretirdi.

import '../data/app_database.dart';
import '../data/tr_gun.dart';
import 'day_closing_repository.dart';
import 'day_end_repository.dart';

/// Taramanın varsayılan derinliği (gün). Gerekçe dosya başlığında.
const int kVarsayilanGerideMax = 14;

/// Kapanmamış TEK bir gün — bandın ve listenin satırı.
class KapanmamisGun {
  const KapanmamisGun({
    required this.gun,
    required this.teslimat,
    required this.kasaKurus,
    required this.acikSiparis,
  });

  final DateTime gun;

  /// O gün teslim edilen sipariş sayısı.
  final int teslimat;

  /// O gün kasaya giren toplam (nakit+kart+havale, kuruş).
  final int kasaKurus;

  /// O günden kalan AÇIK sipariş sayısı. > 0 ise gün KAPATILAMAZ — kapanmış bir gün açık bir
  /// siparişi gizlerdi (mevcut kural, `GunOzetiAltCubugu`). Listede sebep olarak yazılır ki
  /// bayi "kapat düğmesi neden yok" diye sormasın.
  final int acikSiparis;

  bool get kapatilabilir => acikSiparis == 0;
}

/// Taranacak günler — SAF KURAL, doğrudan testlenir. YENİDEN ESKİYE sıralı.
///
/// [bugun] TR takvim günü (00:00). [sonKapanisGunu] son GEÇERLİ gün kapanışının TR günü; hiç
/// kapanış yoksa null. Dönen liste bugünü ve son kapanış gününü İÇERMEZ.
///
/// ⚠️ İki sınırdan DAR OLANI kazanır (dosya başlığı). `sonKapanisGunu` dünse liste BOŞ döner:
/// arada kapanmamış gün yoktur.
List<DateTime> taranacakGunler({
  required DateTime bugun,
  DateTime? sonKapanisGunu,
  int gerideMax = kVarsayilanGerideMax,
}) {
  if (gerideMax <= 0) return const [];

  // İKİ SINIRIN KAPSAYICILIĞI FARKLIDIR ve bu bir ayrıntı değil, kuralın kendisidir:
  //  • `gerideMax` sınırı DAHİLDİR — "14 gün geriye bak" tam 14 gün demektir.
  //  • Son kapanış sınırı HARİÇTİR — kapatılmış günün kendisi kapanmamış olamaz; tarama onun
  //    ERTESİ gününden başlar.
  // İkisini aynı kapsayıcılıkla yazmak ya bir günü kaybettirir ya kapalı bir günü listeler.
  final maxAlt = DateTime(bugun.year, bugun.month, bugun.day - gerideMax);
  final kapanisAlt = sonKapanisGunu == null
      ? null
      : DateTime(sonKapanisGunu.year, sonKapanisGunu.month, sonKapanisGunu.day + 1);
  final alt = (kapanisAlt != null && kapanisAlt.isAfter(maxAlt)) ? kapanisAlt : maxAlt;

  final gunler = <DateTime>[];
  var g = DateTime(bugun.year, bugun.month, bugun.day - 1); // dünden başla
  while (!g.isBefore(alt)) {
    gunler.add(g);
    g = DateTime(g.year, g.month, g.day - 1);
  }
  return gunler;
}

/// Kapanmamış günlerin SALT-OKUNUR read-model'i. Hiçbir tabloya YAZMAZ.
class KapanmamisGunlerRepository {
  KapanmamisGunlerRepository(this.db);
  final AppDatabase db;

  /// HAREKET GÖRMÜŞ TR günlerinin anahtar kümesi — "o gün çalışıldı mı" sorusunun TEK tanımı.
  ///
  /// Dört kaynak: sipariş · kasaya dokunan defter hareketi · kapanış · kasa devri. Tanım
  /// `gunKayitVarMi` ile AYNIDIR ve o fonksiyon artık buraya delege eder — iki kopya olsaydı
  /// "boş gün" ile "kapanmamış gün" farklı cevaplar verirdi ve bayi hareketsiz bir pazar günü
  /// için uyarı alırdı.
  ///
  /// TEK GEÇİŞ, GÜN BAŞINA SORGU DEĞİL: 14 günü tek tek sormak aynı dört taramayı 56 kez
  /// koşturmak demekti.
  Future<Set<String>> hareketliGunler() async {
    final anahtarlar = <String>{};
    void ekle(String iso) {
      final t = DateTime.tryParse(iso);
      if (t != null) anahtarlar.add(trGunAnahtari(trGunu(t.toUtc())));
    }

    for (final o in await (db.select(db.orders)..where((t) => t.deletedAt.isNull())).get()) {
      ekle(o.occurredAt);
    }
    for (final e in await db.select(db.ledgerEntries).get()) {
      ekle(e.occurredAt);
    }
    for (final k in await db.select(db.dayClosings).get()) {
      ekle(k.occurredAt);
    }
    for (final h in await db.select(db.cashHandovers).get()) {
      ekle(h.occurredAt);
    }
    return anahtarlar;
  }

  /// Kapanmamış günlerin TARİHLERİ (yeniden eskiye) — ayrıntı okumadan, ucuz.
  ///
  /// Banda yazan sayı buradan gelir. Ayrıntılı liste ([bul]) gün başına üç okuma daha yapar ve
  /// yalnız liste AÇILDIĞINDA çağrılır: her ekran çizimine 42 tarama bindirmenin anlamı yok.
  Future<List<DateTime>> gunler({int gerideMax = kVarsayilanGerideMax}) async {
    final bugun = await bugunTrDuzeltilmis(db);
    final kapaliAnahtarlar = await DayClosingRepository(db).kapaliGunAnahtarlari();
    final hareketli = await hareketliGunler();

    // Son kapanışın GÜNÜ: taramanın alt sınırı. Anahtar kümesinden türer — ayrı bir sorgu
    // açmak "geçerli kapanış" tanımının üçüncü bir kopyası olurdu.
    DateTime? sonKapanis;
    for (final a in kapaliAnahtarlar) {
      final t = DateTime.tryParse('${a}T00:00:00');
      if (t == null) continue;
      if (sonKapanis == null || t.isAfter(sonKapanis)) sonKapanis = t;
    }

    return [
      for (final g in taranacakGunler(
        bugun: bugun,
        sonKapanisGunu: sonKapanis,
        gerideMax: gerideMax,
      ))
        if (hareketli.contains(trGunAnahtari(g)) && !kapaliAnahtarlar.contains(trGunAnahtari(g)))
          g,
    ];
  }

  /// Kapanmamış gün SAYISI — bandın tek ihtiyacı.
  Future<int> sayi({int gerideMax = kVarsayilanGerideMax}) async =>
      (await gunler(gerideMax: gerideMax)).length;

  /// Kapanmamış günler + her birinin özeti (yeniden eskiye). Liste açıldığında çağrılır.
  Future<List<KapanmamisGun>> bul({int gerideMax = kVarsayilanGerideMax}) async {
    final gunListesi = await gunler(gerideMax: gerideMax);
    if (gunListesi.isEmpty) return const [];

    final dayEnd = DayEndRepository(db);
    final sonuc = <KapanmamisGun>[];
    for (final g in gunListesi) {
      final kasa = await dayEnd.kasaOzeti(g);
      sonuc.add(KapanmamisGun(
        gun: g,
        teslimat: await dayEnd.teslimatSayisi(g),
        kasaKurus: kasa.toplam,
        acikSiparis: await _acikSiparis(g),
      ));
    }
    return sonuc;
  }

  /// O güne düşen AÇIK sipariş sayısı (kapatmanın önündeki tek engel).
  ///
  /// `acikSiparisSayisi` (ekran katmanı) ile aynı soruyu sorar ama kapsam süzgeci YOKTUR:
  /// gün kapanışı dükkânın tamamını kapatır, kimin siparişi olduğu değişmez.
  Future<int> _acikSiparis(DateTime gun) async {
    final satirlar = await (db.select(db.orders)
          ..where((t) => t.deletedAt.isNull())
          ..where((t) => t.status.equals('open')))
        .get();
    return satirlar.where((o) => ayniTrGunIso(o.occurredAt, gun)).length;
  }
}
