// Müşteri ilişkisi kurallarının VERİ BAĞLANTISI — `BildirimTetikleyici`ye verilen üreticiler.
//
// NEDEN AYRI DOSYA: `musteri_kurallari.dart` SAFTIR (yalnız `dart:math` + sözleşme) ve saflığı
// bilinçli bir tasarım özelliğidir — kurallar veritabanı olmadan, sahte zaman olmadan, düz
// `test()` ile sınanıyor. Üreticiler Drift'e dokunur; onları kural dosyasına koymak o özelliği
// bitirirdi. Sınır burada: bu dosya OKUR ve kurala VERİR, başka hiçbir şey yapmaz.
//
// Bildirimi göstermek de bu dosyanın işi değildir: üretici yalnız taslak döner, `goster`/`zamanla`
// kararı tetikleyicide ve serviste kalır.

import 'package:flutter/foundation.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart' show musteriTeslimGecmisleri;
import '../bildirim_sozlesmesi.dart';
import '../bildirim_tetikleyici.dart' show TaslakUretici;
import 'musteri_kurallari.dart';

/// "Gecikmiş müşteri" üreticisi — `BildirimKategori.musteriGecikti`.
///
/// [simdi] enjekte edilebilir: kural `bugun:` parametresi alıyor ve testler sabit bir güne
/// çakılabilmeli. Verilmezse gerçek saat.
TaslakUretici gecikmisMusteriUreticisi(AppDatabase db, {DateTime Function()? simdi}) =>
    () => _uret(
          db,
          simdi,
          'gecikmiş müşteri',
          (gecmisler, bugun) => gecikmisMusteriBildirimi(gecmisler, bugun: bugun),
        );

/// "Rutin teslim günü" üreticisi — `BildirimKategori.rutinTeslimGunu`.
TaslakUretici rutinTeslimUreticisi(AppDatabase db, {DateTime Function()? simdi}) =>
    () => _uret(
          db,
          simdi,
          'rutin teslim',
          (gecmisler, bugun) => rutinTeslimBildirimi(gecmisler, bugun: bugun),
        );

/// İki üreticinin ortak gövdesi: oku → kurala ver → taslağı dön.
///
/// HER ÜRETİCİ KENDİ OKUMASINI YAPAR, paylaşılan önbellek YOKTUR. Bilinçli:
///  • Önbellek nesne ömrü boyunca yaşasaydı, uygulama arka plandan geri geldiğinde tetikleyici
///    BAYAT veriyle koşar ve dün teslim edilmiş bir siparişi görmezdi — bildirim yanlış çıkar,
///    ki bu kuralın tek kırmızı çizgisi ("yanlış tahmin güven kaybettirir").
///  • Kazanç da yok sayılır: sorgu yerel SQLite'ta birkaç yüz satırlık tek taramadır ve günde
///    bir avuç kez koşar. Tazelik için ödenen bedel ölçülemeyecek kadar küçük.
///
/// HATA YUTAR: bildirim bir kolaylıktır, uygulamayı düşüremez. Tetikleyici zaten üretici başına
/// try/catch tutuyor; buradaki ikinci katman, bir kuralın hatasının diğerini etkilememesini
/// üretici seviyesinde de garantiler.
Future<BildirimTaslagi?> _uret(
  AppDatabase db,
  DateTime Function()? simdi,
  String ad,
  BildirimTaslagi? Function(List<MusteriGecmisi> gecmisler, DateTime bugun) kural,
) async {
  try {
    final gecmisler = await musteriTeslimGecmisleri(db);
    return kural(gecmisler, (simdi ?? DateTime.now)());
  } on Object catch (e) {
    // KVKK: yalnız hata nesnesi loglanır — müşteri adı/telefonu ASLA.
    debugPrint('Bildirim üreticisi okuyamadı ($ad): $e');
    return null;
  }
}
