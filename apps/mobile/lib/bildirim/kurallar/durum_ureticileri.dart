// DURUM bildirimlerinin ÜRETİCİLERİ — kural ile veritabanı arasındaki ince katman.
//
// NEDEN AYRI DOSYA: `durum_kurallari.dart` SAFTIR (veri okumaz, saat okumaz) ve öyle kalmalı —
// kural testleri sahte veritabanı kurmadan koşuyor. Üreticiler ise Drift'e dokunur.
//
// HATA YUTAR, null DÖNER: tetikleyici zaten bir üretici patlarsa diğerlerini koşturmaya devam
// ediyor; yine de burada yutuluyor ki tek bir bozuk kayıt log gürültüsü çıkarmasın.
// Bildirim bir KOLAYLIKTIR — hiçbir hâlde uygulamayı bloke etmez.

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/app_database.dart';
import '../../data/tr_gun.dart';
import '../../repo/cash_handover_repository.dart';
import '../../repo/day_closing_repository.dart';
import '../../repo/day_end_repository.dart';
import '../../repo/kapanmamis_gunler.dart';
import '../bildirim_tetikleyici.dart' show TaslakUretici;
import 'durum_kurallari.dart';

/// SENKRON UYARISI üreticisi — açılışta koşar.
///
/// "Son başarılı senkron" ölçüsü `sync_meta.lastServerTimeIso`dur: sunucunun her push/pull
/// yanıtında yazdığı damga. Cihaz saatine DEĞİL sunucununkine bakmak bilinçli — telefonun
/// saati ileri alınmışsa cihaz-yerel bir damga "3 gündür bağlanılamıyor" derdi.
TaslakUretici senkronUyarisiUretici(
  AppDatabase db, {
  DateTime Function()? simdi,
}) {
  return () async {
    try {
      final meta = await db.syncState();
      final son = DateTime.tryParse(meta.lastServerTimeIso ?? '')?.toLocal();

      return senkronUyarisi(
        sonBasariliSenkron: son,
        simdi: simdi?.call() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Senkron uyarısı üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}

/// KULLANIM HAKKI üreticisi — açılışta koşar.
///
/// `routeCredits` ve `routeCreditsMonthly` SUNUCU SAHİPLİ alanlardır (senkronla iner, istemci
/// yazamaz). Bu yüzden bildirim de yalnız senkron sonrası doğru olur; açılışta koşması
/// yeterlidir çünkü açılışta zaten bir senkron turu başlar.
TaslakUretici kullanimHakkiUretici(
  AppDatabase db, {
  DateTime Function()? simdi,
}) {
  return () async {
    try {
      final meta = await db.syncState();

      return kullanimHakkiUyarisi(
        kalan: meta.routeCredits,
        aylik: meta.routeCreditsMonthly,
        gun: simdi != null ? trGunu(simdi()) : await bugunTrDuzeltilmis(db),
      );
    } catch (e) {
      debugPrint('Kullanım hakkı uyarısı üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}

/// KASA DEVRİ HATIRLATMASI üreticisi — akşam zamanlanır.
///
/// Kuryelerin cebindeki para `CashHandoverRepository.onizle` ile kurye kurye okunur ve
/// TOPLANIR. Tek sorguyla toplamak mümkün değil: her kuryenin penceresi kendi son
/// kapanışından başlar (`_pencere`), yani "kuryede kalan" kişiye özel bir hesaptır.
TaslakUretici kasaDevriHatirlatmasiUretici(
  AppDatabase db, {
  DateTime Function()? simdi,
}) {
  return () async {
    try {
      final gun = simdi != null ? trGunu(simdi()) : await bugunTrDuzeltilmis(db);
      final repo = CashHandoverRepository(db);

      // AKTİF KURYELER: pasifleştirilmiş bir kullanıcının eski bakiyesi hatırlatma üretmemeli
      // — o kişi artık sahada değildir ve "devret" diyecek muhatap yoktur.
      final kuryeler = await (db.select(db.users)
            ..where((t) => t.role.equals('kurye') & t.status.equals('active')))
          .get();

      var toplam = 0;
      var sayi = 0;
      for (final k in kuryeler) {
        final onizleme = await repo.onizle(k.id, localDate: gun);
        if (onizleme.expectedKurus > 0) {
          toplam += onizleme.expectedKurus;
          sayi++;
        }
      }

      return kasaDevriHatirlatmasi(
        kuryedeKalanKurus: toplam,
        kuryeSayisi: sayi,
        gun: gun,
      );
    } catch (e) {
      debugPrint('Kasa devri hatırlatması üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}

/// "DÜN GÜN KAPATILMADI" üreticisi — sabah zamanlanır.
///
/// ⚠️ BİLDİRİM YARIN SABAH ÇIKAR AMA VERİ BUGÜN OKUNUR — ve bu, bu kuralın en ince yeridir.
/// `zonedSchedule` bildirimi METNİYLE BİRLİKTE sisteme teslim eder; ateşlendiği anda bizim
/// kodumuz koşmaz (süreç ölü olabilir). Yani "dün kapatıldı mı" sorusu, bildirimin
/// KURULDUĞU anda cevaplanır: bugün akşam bakıp "bugün kapatılmamış" gördüysek, yarın sabah
/// için hatırlatma kurarız.
///
/// Bunun ölçülmüş sonucu şudur: bayi bildirim kurulduktan SONRA günü kapatırsa hatırlatma
/// yine çıkar (yanlış pozitif). Kabul edildi, çünkü alternatifi bildirimi hiç kurmamaktı —
/// gerçekten kapatmayan bayiyi hiç uyarmamak, kapatanı bir kez fazladan uyarmaktan pahalı.
TaslakUretici gunKapatilmadiUretici(
  AppDatabase db, {
  DateTime Function()? simdi,
}) {
  return () async {
    try {
      final bugun = simdi != null ? trGunu(simdi()) : await bugunTrDuzeltilmis(db);
      final kapandi = await DayClosingRepository(db).kapaliMi(
        ClosingScope.day,
        localDate: bugun,
      );

      // BUGÜNÜN hareketi sorulur (bildirim yarın sabah "dün" diye çıkacak). Hareketsiz gün
      // kapatılmaz ve bu bir eksiklik değildir — kural o ayrımı kendisi yapar.
      final veri = await DayEndRepository(db).gunSonuBildirimVerisi(bugun);

      // BUGÜNDEN ÖNCEKİ kapanmamış günler (2026-08-21). `gunler()` bugünü zaten dışarıda
      // bırakır, yani bildirim yarın "dün" dediği güne kadar olan HER şeyi sayar ve iki kaynak
      // (bu satır + yukarıdaki `kapandi`) hiçbir günü ne iki kez sayar ne atlar.
      final onceki = await KapanmamisGunlerRepository(db).sayi();

      return gunKapatilmadiHatirlatmasi(
        dunKapatildi: kapandi,
        dunHareketVardi: !veri.bosGun,
        dun: bugun,
        oncekiKapanmamis: onceki,
      );
    } catch (e) {
      debugPrint('Gün kapanışı hatırlatması üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}
