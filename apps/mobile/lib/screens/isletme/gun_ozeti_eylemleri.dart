// GÜN ÖZETİ ekranının ARA TAHSİLAT eylemleri — al · iptal et · çerçeve notu.
//
// NEDEN AYRI DOSYA: `day_end_screen.dart` iptal akışıyla 614 satıra çıkmıştı (depo sınırı 500) ve
// `gun_ozeti_govdesi.dart` bir tur önce tam olarak bu sebeple ayrılmıştı. Sınır KEYFİ DEĞİL: o
// ekran bu vardiyada yedi kez düzeltme aldı ve her turda okunması gereken yüzey büyüdü.
//
// AYRIM: burada UI AKIŞI vardır (önizle → sheet/onay göster → repo'ya yaz → sonucu bildir),
// EKRANDA ise DURUM ve YETKİ kalır. Yetki kapıları BİLEREK taşınmadı — K2 kuralı "ekran düğmeyi
// kapatır VE eylem fonksiyonu yetkiyi yeniden sorar" diyor ve iki kapının ikisi de rolü/kapsamı
// bilen tarafta, yani ekranda yaşamalı. Buradaki fonksiyonlar yetkiyi VARSAYAR; çağıran zaten
// sormuş olur.
//
// HİÇBİRİ PARA FORMÜLÜ YAZMAZ: beklenen nakit `CashHandoverRepository.onizle()`den, iptalin
// geçerliliği `araTahsilatIptal()`in kapılarından gelir. Bu dosya yalnız sırayı kurar.
//
// DÖNÜŞ DEĞERİ `bool` = "EKRAN TAZELENSİN Mİ". Hata yolunda da `true` döner ve bu bilinçli:
// repo bir engel bildirdiyse ekranın bildiği durum BAYATTIR (başka bir cihazdan kapanış ya da
// iptal inmiş olabilir) ve kullanıcıya hatayı gösterip ekranı eski hâlinde bırakmak, aynı
// düğmeye bir daha basmaya davet ederdi.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/cash_handover_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import 'ara_tahsilat_sheet.dart';
import 'gun_sonu_ozet.dart';

/// KURYE KAPSAMINDA SHEET İLE EKRAN AYNI ARALIĞI KONUŞMAYABİLİR — bunu söyleyen satırın metni.
///
/// Sheet'lerin rakamları o kuryenin PENCERESİNDEN gelir (son hesap kapanışından beri; kapanışı
/// yoksa alttan açık), ekrandaki kasa kartı ve ara tahsilat kartı ise TAKVİM GÜNÜNDEN. Hiç
/// kapanış yapmamış bir kurye dün 5.000, bugün 3.000 topladıysa ekran 3.000, sheet 8.000 der ve
/// bir tur boyunca bu ikisinin arasını açıklayan HİÇBİR satır yoktu — bayi hangisinin doğru
/// olduğunu soramıyordu.
///
/// KARŞILAŞTIRMA, HESAP DEĞİLDİR: burada hiçbir para türetilmiyor, iki çerçevenin AYNI parayı
/// kapsayıp kapsamadığı soruluyor. Rakamların ikisi de repo'dan geliyor. Çakışıyorlarsa (çoğu
/// gün böyle) satır çizilmez — açıklanacak bir fark yokken yazılan uyarı gürültüdür.
///
/// TEK METİN VAR, çünkü tek hâl ULAŞILABİLİR: pencere ancak kuryenin BUGÜNKÜ bir kapanışıyla
/// günün içinden başlayabilirdi, ama o kapanış kapsamı KİLİTLER (`kapsamKapali`) ve o hâlde ne
/// kapatma ne ara tahsilat sheet'i açılır. Yani ayrışma her zaman "pencere geriye sarkıyor"
/// yönündedir. İkinci bir dal yazmak, hiç oluşamayacak bir hâl için test edilemeyen kopya
/// yazmak olurdu.
Future<String?> cerceveNotu(
  AppDatabase db,
  GunSonuGorunumu g,
  String kuryeId,
  DateTime gun, {
  required int pencereNakit,
  required int pencereTeslim,
}) async {
  final gunTeslim = await CashHandoverRepository(db).teslimEdilenNakit(gun, kuryeId: kuryeId);
  if (pencereNakit == g.kapsam.kasa.nakit && pencereTeslim == gunTeslim) return null;
  // Metin FORMÜL İDDİA ETMEZ (beklenen nakdin tanımı repo'nundur ve bu vardiyada iki kez
  // değişti) — yalnız hangi ARALIĞIN kapsandığını söyler.
  return 'Önceki günden devreden nakit dahil — ekrandaki gün toplamıyla aynı aralık değil.';
}

/// Kuryeden ARA TAHSİLAT alır (sheet → kayıt). Ekran tazelensin mi diye `bool` döner.
///
/// ⚠️ YETKİYİ SORMAZ: çağıran (`day_end_screen.dart`) K2 kapısını zaten tutuyor. Burada ikinci
/// kez sormak, aynı kararın iki yerde yaşaması ve bir gün ayrışması demekti.
Future<bool> araTahsilatAl(
  BuildContext context, {
  required AppDatabase db,
  required GunSonuGorunumu gorunum,
  required String kuryeId,
  required String kuryeAdi,
  required String? alanUserId,
  required DateTime bugun,
}) async {
  // Beklenen tutar REPO'DAN gelir, ekranın kasa kartından DEĞİL. Kasa kartı günün TOPLAM
  // nakdini gösterir; kuryede fiilen kalan tutar ondan farklıdır ve tanımı repo'nundur
  // (2026-08-06'da kümülatife döndü). Ekran kendi çıkarmasını yapsaydı her tanım değişikliğinde
  // sessizce ayrışır, sheet'te yazan tutar kayda geçenden farklı olurdu.
  final repo = CashHandoverRepository(db);
  final onizleme = await repo.onizle(kuryeId);
  final not = await cerceveNotu(
    db,
    gorunum,
    kuryeId,
    bugun,
    pencereNakit: onizleme.toplananKurus,
    pencereTeslim: onizleme.teslimEdilenKurus,
  );
  if (!context.mounted) return false;

  final sonuc = await araTahsilatSheet(
    context,
    kuryeAdi: kuryeAdi,
    beklenen: onizleme.expectedKurus,
    cerceveNotu: not,
    senkron: gorunum.senkron,
  );
  if (sonuc == null || !context.mounted) return false;

  // ÜÇÜNCÜ KAPI repoda: kapsam kapalıysa `araTahsilat` StateError atar. Ekran kapıyı zaten
  // tutuyor (düğme çizilmiyor), ama sheet açıkken senkron başka bir cihazdan gelen kapanışı
  // indirebilir — o an ekranın bildiği durum bayattır. Mesaj repo'dan geldiği gibi basılır:
  // kullanıcıya "bir şeyler ters gitti" demek, tam olarak NE olduğunu bilirken bilgi saklamaktır.
  try {
    // Gün AÇIK kalır: `araTahsilat` kapanış yazmaz (bkz. repo'daki gerekçe).
    await repo.araTahsilat(
      fromUserId: kuryeId,
      toUserId: alanUserId,
      countedCashKurus: sonuc.sayilan,
      note: sonuc.not.isEmpty ? null : sonuc.not,
    );
  } on StateError catch (e) {
    if (!context.mounted) return false;
    SipToast.goster(context, e.message);
    return true; // ekranı gerçeğe döndür: kapanmış kapsam artık kilitli görünsün
  }
  if (!context.mounted) return false;

  SipToast.goster(context, '$kuryeAdi · ${sipTutar(sonuc.sayilan)} tahsil edildi');
  return true;
}

/// Bir ara tahsilatı İPTAL eder (kullanıcı kararı 2026-08-13). Kayıt SİLİNMEZ — repo ters
/// işaretli ikinci bir devir satırı yazar (BRIEF kırmızı çizgi #2). Ekran tazelensin mi diye
/// `bool` döner.
///
/// ⚠️ YETKİYİ SORMAZ (bkz. [araTahsilatAl]); GEÇERLİLİĞİ de sormaz. İptalin mümkün olup
/// olmadığını REPO bilir ve orada dört kapı var (kayıt var mı · zaten iptal mi · kendisi iptal
/// kaydı mı · kapanışa bağlı mı) + kapalı kapsam engeli. Burada tekrarlasaydık ikisi bir gün
/// ayrışır ve satır dokunulabilir görünürken eylem patlardı.
Future<bool> araTahsilatIptalEt(
  BuildContext context, {
  required AppDatabase db,
  required AraTahsilatKaydi kayit,
  required String? iptalEdenUserId,
}) async {
  // ONAY ADIMI ZORUNLU: satır kaydırılan bir listenin ortasında duruyor ve kazara dokunuş
  // kalıcı bir düzeltme kaydı yazardı (iptalin iptali yoktur — yeni bir tahsilat girmek gerekir).
  final onay = await araTahsilatIptalOnayi(
    context,
    kuryeAdi: kayit.kuryeAdi,
    tutarKurus: kayit.countedCashKurus,
    occurredAt: kayit.occurredAt,
  );
  if (!onay || !context.mounted) return false;

  // ÜÇÜNCÜ KAPI REPODA (ara tahsilat/kapatma ile aynı desen): kayıt bu arada senkronla bir
  // kapanışa bağlanmış ya da başka bir cihazdan iptal edilmiş olabilir — o an ekranın bildiği
  // durum bayattır. Mesaj repo'dan geldiği gibi basılır: NE olduğunu bilirken "bir şeyler ters
  // gitti" demek bilgi saklamaktır.
  try {
    await CashHandoverRepository(db).araTahsilatIptal(
      handoverId: kayit.id,
      iptalEdenUserId: iptalEdenUserId,
    );
  } on StateError catch (e) {
    if (!context.mounted) return false;
    SipToast.goster(context, e.message);
    return true; // ekranı gerçeğe döndür
  }
  if (!context.mounted) return false;

  SipToast.goster(context, '${sipTutar(kayit.countedCashKurus)} tahsilat iptal edildi');
  return true;
}
