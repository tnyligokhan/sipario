// ARŞİV DETAYI — kapatılmış bir hesabı kuruşu kuruşuna geri okuyan alt sayfa.
//
// NEDEN AYRI DOSYA: `gun_kapatma_sheet.dart` 569 satıra çıkmıştı (depo sınırı 500). Ayrım
// KONUYA göre: ana dosya bir hesabı KAPATIR (form, sayım, fark), burası KAPANMIŞ bir hesabı
// GÖSTERİR ve — yetki verilmişse — geri almayı başlatır.
//
// NEDEN `part` (ayrı kütüphane değil): `gun_kapatma_sheet.dart`ı import eden altı dosya var ve
// hepsi `arsivDetaySheet`i oradan alıyor. Ayrı bir kütüphane, altı import satırını yalnız
// dosya taşındığı için oynatmak demekti; `part` çağrı yerlerini HİÇ değiştirmez ve dosyanın
// private yardımcılarına (`gunSaatBicimi` gibi) erişimi de korur.

part of 'gun_kapatma_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Arşiv detayı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Arşivlenmiş kapanışı kuruşu kuruşuna geri okur. [kapsamAdi] gün hesabında "Gün hesabı",
/// kurye kapanışında kuryenin adıdır (kayıtta yalnız `user_id` durur, ad `users` aynasından çözülür).
/// [bugun] "Bugün/Dün" şeridinin referans günüdür — DÜZELTİLMİŞ saatten gelmeli.
Future<void> arsivDetaySheet(
  BuildContext context,
  DayClosing k, {
  required String kapsamAdi,
  required DateTime bugun,
  bool geriAlinmis = false,
  Future<void> Function()? onGeriAl,
}) {
  return sipSheet<void>(
    context,
    baslik: '$kapsamAdi arşivi',
    govde: (ctx) => _ArsivDetay(
      kapanis: k,
      bugun: bugun,
      geriAlinmis: geriAlinmis,
      onGeriAl: onGeriAl,
    ),
  );
}

class _ArsivDetay extends StatelessWidget {
  const _ArsivDetay({
    required this.kapanis,
    required this.bugun,
    this.geriAlinmis = false,
    this.onGeriAl,
  });

  final DayClosing kapanis;
  final DateTime bugun;

  /// Bu kapanış SONRADAN geri alındı mı (2026-08-18). Kayıt yerinde durur, geçerliliği düşer.
  final bool geriAlinmis;

  /// "Hesabı Geri Al" eylemi. `null` ise düğme HİÇ çizilmez — yetki kapısı ÇAĞIRANDADIR
  /// (`yetkiler().gunuKapatma`), bu sheet karar vermez, yalnız taşır.
  final Future<void> Function()? onGeriAl;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final k = kapanis;
    final fark = k.diffKurus;
    final farkRengi = fark < 0 ? t.danger : (fark > 0 ? t.warn : t.ok);
    final not = (k.note ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KapaliSerit(
          metin: '${gunSaatBicimi(k.occurredAt, bugun: bugun)} saatinde kapatıldı, '
              '${k.deliveryCount} teslimat',
          ikon: SipIcons.lock,
        ),
        const SizedBox(height: SipSpace.xl),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Nakit', deger: sipTutar(k.cashNakitKurus)),
            DegerSatiri(etiket: 'Kart', deger: sipTutar(k.cashKartKurus)),
            DegerSatiri(etiket: 'Havale', deger: sipTutar(k.cashHavaleKurus)),
            DegerSatiri(
              etiket: 'Toplam Tahsilat',
              deger: sipTutar(k.totalCollectedKurus),
              toplam: true,
            ),
          ],
        ),
        const SizedBox(height: SipSpace.lg),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Beklenen nakit', deger: sipTutar(k.expectedCashKurus)),
            DegerSatiri(
              etiket: 'Sayılan nakit',
              deger: k.countedCashKurus == null ? '—' : sipTutar(k.countedCashKurus!),
            ),
            DegerSatiri(
              etiket: 'Fark',
              deger: fark == 0 ? 'Tam' : sipTutar(fark),
              degerRengi: farkRengi,
            ),
          ],
        ),
        if (not.isNotEmpty) ...[
          const SizedBox(height: SipSpace.lg),
          SipNotKutusu(metin: not),
        ],

        // GERİ ALINMIŞ KAPANIŞ: kayıt DURUR, geçersizliği yazıyla söylenir (2026-08-18).
        // Satırı listeden silmek "olay hiç olmadı" demek olurdu; oysa olmuştu ve düzeltildi.
        if (geriAlinmis) ...[
          const SizedBox(height: SipSpace.lg),
          const SipNotKutusu(
            metin: 'Bu kapanış geri alındı. Rakamlar kapanış anındaki hâli gösterir.',
            ikon: SipIcons.info,
            tur: SipNotTuru.uyari,
          ),
        ],

        // "HESABI GERİ AL" — yalnız GEÇERLİ bir kapanışta ve yalnız yetkili kullanıcıda.
        // Geri alınmış bir kaydı ikinci kez geri almak anlamsızdır (repo da reddeder); düğmeyi
        // çizip dokunuşta reddetmek yerine hiç çizmiyoruz.
        if (onGeriAl != null && !geriAlinmis) ...[
          const SizedBox(height: SipSpace.x4),
          SipButon(
            etiket: 'Hesabı Geri Al',
            tur: SipButonTuru.tehlike,
            onTap: () async {
              // Sheet ÖNCE kapanır: geri alma akışı kendi onay diyaloğunu ve parola sheet'ini
              // açıyor, üst üste üç katman modal kullanıcıyı nerede olduğunu bilmez hâle
              // getirirdi. Ayrıca akış bitince ekranın tazelenmesi gerekiyor ve bu sheet
              // tazelenmiş veriyi zaten taşımıyor.
              Navigator.of(context).maybePop();
              await onGeriAl!();
            },
          ),
        ],
      ],
    );
  }
}

