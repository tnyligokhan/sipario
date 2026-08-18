// TESLİM AKIŞI — teslimin İKİ GİRİŞİ, TEK KAPISI.
//
// NEDEN AYRI DOSYA (2026-08-18): teslim artık iki yerden başlatılıyor — sipariş DETAYINDAKİ
// "Teslim Et" düğmesi ve LİSTE kartındaki eylem şeridinin dördüncü düğmesi (kullanıcı isteği:
// "WhatsApp/Ara butonları gibi teslim et butonu en sağa"). İkisi ayrı yazılsaydı zamanla
// ayrışırlardı ve bu depoda tam olarak öyle bir açık doğdu: aynı ekranın iki girişi farklı
// yetkiyle açılıyordu (`CustomerDetailScreen.yetki`, `home_shell_gezinme.dart` başlığı).
//
// Bu yüzden akış tek bir NESNEDE toplandı: teslim için gereken her şey (hangi sipariş, tutarı,
// müşterisi, veritabanı) kurucuda kapsüllenir; dışarıya açılan tek yüzey [calistir]dır.
// Çağıran taraf ne sheet'i, ne yetkiyi, ne de deposu bilir.
//
// HİÇBİR KURAL BURADA DEĞİL: tutar hesabı `delivery_sheet.dart`ın saf fonksiyonlarında
// (`teslimBorcFarki`, `teslimOdemeTipi`), yazma `OrderRepository.deliver`da. Burası yalnız
// SIRAYI tutar: bakiyeyi oku → yetkiyi oku → sheet'i aç → yaz → sonucu duyur.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/bicim.dart';
import '../../theme/components/overlays.dart';
import '../team.dart';
import 'delivery_sheet.dart';
import 'order_queries.dart';

/// Tek bir siparişin teslim akışı.
///
/// Kısa ömürlüdür: dokunuşta kurulur, [calistir] biter ve atılır. Durumu kurucuda donar —
/// akış ortasında hangi siparişin teslim edildiği DEĞİŞEMEZ (liste akışı altından yeniden
/// sıralanırken yanlış siparişi kapatmanın önü bu şekilde kesilir).
class TeslimAkisi {
  const TeslimAkisi({
    required this.db,
    required this.siparisId,
    required this.toplamKurus,
    required this.musteriId,
  });

  /// Liste satırından kurar: satırın elindeki kalemlerden tutarı kendisi hesaplar.
  ///
  /// Tutarı çağıranın hesaplamasını istemiyoruz — detay ekranı `satirlarToplami` kullanıyor,
  /// liste başka bir toplam kullansaydı iki giriş aynı siparişe farklı tutar yazardı.
  factory TeslimAkisi.satirdan({
    required AppDatabase db,
    required Order siparis,
    required List<OrderLine> satirlar,
  }) =>
      TeslimAkisi(
        db: db,
        siparisId: siparis.id,
        toplamKurus: satirlarToplami(satirlar),
        musteriId: siparis.customerId,
      );

  final AppDatabase db;
  final String siparisId;
  final int toplamKurus;
  final String? musteriId;

  /// Sheet'i açar, kullanıcı onaylarsa teslimi YAZAR ve sonucu [onBildir] ile duyurur.
  ///
  /// `true` döner: teslim yazıldı (çağıran ekranını kapatabilir). `false`: vazgeçildi ya da
  /// akış ortasında ekran ağaçtan düştü — hiçbir şey yazılmadı.
  Future<bool> calistir(BuildContext context, {ValueChanged<String>? onBildir}) async {
    // Teslimden ÖNCEKİ bakiye tek atış okunur: sheet yalnız sipariş tutarını görür, "fazla
    // ödemede müşteri ne kadar alacaklı kalacak" sorusunu bu olmadan yanıtlayamaz.
    final id = musteriId;
    final oncekiBakiye = id == null ? 0 : (await musteriOku(db, id))?.balanceKurus ?? 0;
    // İskonto yetkisi EYLEM ANINDA okunur (2026-08-04): sheet kabuktan bağımsız açılıyor ve
    // yetkileri taşımıyor; patron ayarı az önce kapatmış olabilir.
    final yetki = await oturumYetkileri(db);
    if (!context.mounted) return false;

    final sonuc = await teslimSheetAc(
      context,
      toplamKurus: toplamKurus,
      musteriVar: id != null,
      oncekiBakiyeKurus: oncekiBakiye,
      iskontoYetkisi: yetki.iskonto,
    );
    if (sonuc == null || !context.mounted) return false;

    await OrderRepository(db).deliver(
      siparisId,
      paymentType: sonuc.odemeTipi,
      tahsilKurus: sonuc.tahsilKurus,
      iskontoKurus: sonuc.iskontoKurus,
    );
    if (!context.mounted) return true;

    final mesaj = _ozet(sonuc);
    if (onBildir != null) {
      onBildir(mesaj);
    } else {
      SipToast.goster(context, mesaj);
    }
    return true;
  }

  /// Bayi teslim anında en çok "borç kaldı mı" diye merak eder — kısmi teslimde özet onu söyler.
  /// İskontoda borç KALMAZ, o yüzden metin borcu değil kırılan tutarı yazar: aynı farkın iki
  /// ayrı anlamı var ve hangisinin kaydedildiği teslimden sonra da okunabilmeli.
  String _ozet(TeslimSonucu sonuc) {
    final kalan =
        teslimBorcFarki(toplamKurus: toplamKurus, tahsilKurus: sonuc.tahsilKurus) -
            sonuc.iskontoKurus;
    final ek = sonuc.iskontoKurus > 0
        ? ' · ${sipTutar(sonuc.iskontoKurus)} iskonto'
        : (kalan > 0 && sonuc.odemeTipi != 'veresiye' ? ' · ${sipTutar(kalan)} borç' : '');
    return 'Sipariş teslim edildi · ${odemeTipiEtiketi(sonuc.odemeTipi)}$ek';
  }
}
