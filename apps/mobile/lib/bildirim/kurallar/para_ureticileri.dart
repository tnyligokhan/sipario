// PARA/VERESİYE bildirimlerinin ÜRETİCİLERİ — kural ile veritabanı arasındaki ince katman.
//
// NEDEN AYRI DOSYA: `para_kurallari.dart` SAFTIR (veri okumaz, saat okumaz) ve öyle kalmalı —
// kural testleri sahte veritabanı kurmadan koşuyor. Üreticiler ise Drift'e dokunur, yani saf
// değildir. İkisini ayırmak kural saflığını koruyan sınırdır.
//
// Her üretici `TaslakUretici` (= `Future<BildirimTaslagi?> Function()`) döner:
// defterden oku → saf kurala ver → taslağı döndür. Bildirimi GÖSTERMEK altyapının işidir
// (`BildirimTetikleyici` + `BildirimServisi`); burada hiçbir gösterim kararı yoktur.
//
// HATA YUTAR, null DÖNER: tetikleyici zaten bir üretici patlarsa diğerlerini koşturmaya devam
// ediyor; yine de burada yutuyoruz ki tek bir bozuk kayıt yüzünden log gürültüsü çıkmasın ve
// diğer bildirimler etkilenmesin. Bildirim bir KOLAYLIKTIR — hiçbir hâlde uygulamayı bloke etmez.
//
// GÜN DAMGALI KİMLİKLER SAYESİNDE TEKRAR GÜVENLİDİR: tetikleyici açılışta da koşuyor (Xiaomi
// zamanlanmış bildirimi öldürebilir); gün içinde kaç kez çağrılırsa çağrılsın aynı kimlik
// tazelenir, yeni bildirim doğmaz ve günlük bütçeden ikinci kez düşmez.

import 'package:flutter/foundation.dart';

import '../../data/tr_gun.dart';
import '../../repo/day_end_repository.dart';
import '../bildirim_ayarlari.dart';
import '../bildirim_tetikleyici.dart' show TaslakUretici;
import 'para_kurallari.dart';

/// Bildirimin konuştuğu "bugün" — EKRANLA AYNI KAYNAKTAN (inceleme bulgusu #4, 2026-08-06).
///
/// Bu depoda "bildirim ile gün özeti ekranı aynı günü konuşsun" bilinçli bir tasarım kararıdır
/// (`DayEndRepository.gunSonuBildirimVerisi` yorumları). Ekranlar düzeltilmiş sunucu saatine
/// geçerken burası cihaz saatinde kalsaydı, kapatılan uyuşmazlık bildirim katmanında geri gelir
/// ve bayi akşam 23:40'ta ekranda bir gün, bildirimde başka bir gün görürdü.
///
/// [simdi] TEST DİKİŞİDİR ve korunur: verildiğinde db'ye hiç gidilmez, o an olduğu gibi kullanılır.
/// `bugunTrDuzeltilmis` sahte saat parametresi almıyor — dikişi burada tutmak, o imzayı
/// değiştirmekten ucuz ve üretim yolunu (dikişsiz dal) aynen bırakıyor.
Future<DateTime> _bugun(DayEndRepository repo, DateTime Function()? simdi) async =>
    simdi != null ? trGunu(simdi()) : await bugunTrDuzeltilmis(repo.db);

/// GÜN SONU ÖZETİ üreticisi — akşam sabit saatte zamanlanır.
/// Boş günde (hiç tahsilat, teslim, veresiye yok) kural `null` döner ve bildirim atılmaz.
TaslakUretici gunSonuOzetiUretici(
  DayEndRepository repo, {
  DateTime Function()? simdi,
}) {
  return () async {
    try {
      final gun = await _bugun(repo, simdi);
      return gunSonuOzeti(await repo.gunSonuBildirimVerisi(gun));
    } catch (e) {
      debugPrint('Gün sonu bildirimi üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}

/// BORÇ EŞİĞİ üreticisi — açılışta ve gün içinde koşar (anlık tarama).
///
/// Eşik AYAR DEPOSUNDAN gelir ve Faz 1'de VARSAYILAN KAPALIdır (0). Kapalıyken burada erken
/// dönülür: `bugunEsigiAsanlar` zaten eşik 0'da defteri hiç okumuyor, ama ayar dosyasını bile
/// beklememek için kapı önce burada kapanır.
///
/// Gün içinde kaç kez koşarsa koşsun TEK taslak üretir (kimlik gün damgalı); yeni bir müşteri
/// eşiği aştığında aynı bildirim güncellenir — bayi tek ve güncel satır görür.
TaslakUretici borcEsigiUretici(
  DayEndRepository repo,
  BildirimAyarlari ayarlar, {
  DateTime Function()? simdi,
}) {
  return () async {
    try {
      await ayarlar.yukle();
      final esik = ayarlar.borcEsigiKurus;
      if (esik <= kBorcEsigiKapali) return null; // bayi henüz eşik belirlemedi

      final gun = await _bugun(repo, simdi);
      final asanlar = await repo.bugunEsigiAsanlar(gun, esikKurus: esik);
      return borcEsigiBildirimi(asanlar, gun: gun, esikKurus: esik);
    } catch (e) {
      debugPrint('Borç eşiği bildirimi üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}

/// VADESİ GEÇEN BORÇLAR üreticisi — haftalık (Pazartesi) zamanlanır.
///
/// Gecikmiş tutar FIFO alacak yaşlandırmasıyla hesaplanır (ödemeler en eski borcu kapatır);
/// gecikmiş müşteri yoksa kural `null` döner ve bildirim atılmaz.
TaslakUretici vadesiGecenUretici(
  DayEndRepository repo, {
  DateTime Function()? simdi,
  int gunEsigi = kVadeGunEsigi,
}) {
  return () async {
    try {
      final an = simdi?.call() ?? DateTime.now();
      final gecikmisler = await repo.gecikmisBorclular(simdi: an, gunEsigi: gunEsigi);
      return vadesiGecenBorclar(
        gecikmisler,
        // Kimlik haftanın PAZARTESİsine bağlanır: aynı hafta içinde tekrar koşulursa
        // (açılış taraması, zamanlayıcı çakışması) aynı bildirim tazelenir. Hafta başı da
        // DÜZELTİLMİŞ günden türer — cihaz saati Pazartesi 00:20'de bir gün ileriyse kimlik
        // yanlış haftaya bağlanır ve aynı hafta içinde İKİNCİ bir bildirim doğardı.
        haftaBasi: haftaninBasi(await _bugun(repo, simdi)),
        gunEsigi: gunEsigi,
      );
    } catch (e) {
      debugPrint('Vadesi geçen borç bildirimi üretilemedi: ${e.runtimeType}');
      return null;
    }
  };
}
