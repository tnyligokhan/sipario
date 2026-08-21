// SİPARİŞ AÇMA KAPISI — yeni siparişin müşterisi belli olduğu anda koşan TEK doğrulama.
//
// NEDEN TEK DOSYA, TEK FONKSİYON: sipariş oluşturmanın birden çok giriş noktası var (sipariş
// listesindeki FAB, müşteri kartındaki "Sipariş Oluştur", çağrı kartı, form içindeki müşteri
// seçimi). Kuralı her birine kopyalamak, kopyalardan birinin güncellenmediği gün kapıyı SESSİZCE
// delmek demektir — kara liste kuralı bunu bir kez yaşadı (`kara_liste.dart` başlığı).
//
// KAPI FORMUN İÇİNDE DURUR, ÇAĞIRANLARDA DEĞİL. Bütün giriş noktaları `OrderFormScreen`e varır ve
// müşteri forma yalnız İKİ yoldan girer: dışarıdan hazır gelir (`initialCustomerId`) ya da adım
// 1'de seçilir. Kapıyı bu iki noktaya bağlamak, yarın eklenecek dördüncü giriş noktasını da
// kendiliğinden kapsar; çağıranlara dağıtılmış bir kapı ise yeni çağıranı kapsamaz.
//
// Ekran metinleri SÖZLEŞMEDİR — testler bu sabitlere/üreticilere bağlanır, dizgeye değil.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/overlays.dart';
import '../customers/kara_liste.dart';
import 'order_queries.dart';

const String acikSiparisUyariBasligi = 'Bu müşterinin açık siparişi var';
const String acikSiparisOnayEtiketi = 'Yine de oluştur';
const String acikSiparisVazgecEtiketi = 'Vazgeç';

/// Uyarı cümlesi. "Emin misiniz?" TEK BAŞINA hiçbir şey anlatmaz ve kullanıcıyı her seferinde
/// aynı refleksle onaylamaya alıştırır; karar ancak SAYIYLA verilir:
///  • kaç açık sipariş var (bir tane mi, yoksa müşteri üst üste mi arıyor),
///  • en yenisi ne zaman ve hangi kodla girildi (kullanıcı onu listede bulup bakabilsin).
///
/// Kod henüz atanmamışsa (sipariş senkronlanmadı — `siparisKodu` kuralı: uydurma numara YAZILMAZ)
/// satırda yalnız zaman kalır; eksik parça cümleyi bozmaz.
String acikSiparisUyariMesaji({
  required String musteriAd,
  required int adet,
  required Order enYeni,
  DateTime? simdi,
}) {
  final parcalar = [
    ?siparisKodu(enYeni.code),
    saatBicimi(enYeni.occurredAt, simdi: simdi),
  ];
  return '$musteriAd için $adet açık sipariş kayıtlı.\n'
      'En yenisi: ${parcalar.join(', ')}\n\n'
      'Yine de yeni bir sipariş oluşturulsun mu?';
}

/// Siparişi açmadan önce koşan kapı. `true` = devam edilebilir.
///
/// İKİ kural sırayla uygulanır ve sırası önemlidir:
///  1. KARA LİSTE — sert engel, onaylanamaz (yetkisi olan müşteri kaydından kaldırır).
///  2. AÇIK SİPARİŞ — yumuşak uyarı, onaylanabilir. Aynı müşteriye ikinci siparişi açmak MEŞRU
///     bir iştir (müşteri gerçekten bir şey daha isteyebilir); engellenmez, yalnız görünür kılınır.
///
/// AÇIK SİPARİŞİ OLMAYAN MÜŞTERİDE HİÇBİR ŞEY GÖSTERİLMEZ. Yanlış alarm, gerçek alarmı görünmez
/// yapar: her siparişte onaylanan bir diyalog iki gün içinde okunmadan kapatılan bir engele döner.
Future<bool> siparisAcmadanOnceDogrula(
  BuildContext context, {
  required AppDatabase db,
  required Customer musteri,
}) async {
  if (karaListede(musteri)) {
    SipToast.goster(context, karaListeSiparisMesaji(musteri.name));
    return false;
  }

  final acik = await acikSiparisler(db, musteri.id);
  if (acik.isEmpty || !context.mounted) return acik.isEmpty;

  return sipOnay(
    context,
    baslik: acikSiparisUyariBasligi,
    mesaj: acikSiparisUyariMesaji(
      musteriAd: musteri.name,
      adet: acik.length,
      enYeni: acik.first,
    ),
    onayEtiketi: acikSiparisOnayEtiketi,
    vazgecEtiketi: acikSiparisVazgecEtiketi,
  );
}
