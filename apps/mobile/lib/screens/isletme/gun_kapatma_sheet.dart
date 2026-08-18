// Gün sonu KAPATMA ve ARŞİV DETAYI alt sayfaları — tasarım s-gunsonu.jsx içindeki
// iki `Sheet` + Sipario.html `.kd-*` (kasa devri) ve `.gs-*` sınıfları.
//
// Kapatma sheet'i, gün/kurye hesabını sayılan nakitle mutabık kılıp arşive taşır. FARK ≠ 0
// KAPATMAYI ENGELLEMEZ (BRIEF: eksik para görünür kalmalı) — kanıt olarak arşive yazılır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/tr_gun.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_sonu_ozet.dart' show SenkronTazeligi;
import 'isletme_atomlari.dart';
import 'senkron_seridi.dart';

/// Kapatma sheet'inin sonucu: sayılan nakit (girilmediyse null) + not.
@immutable
class KapatmaSonucu {
  const KapatmaSonucu({required this.sayilan, required this.not});

  final int? sayilan;
  final String not;
}

/// Hesabı kapat · kasa devri.
///
/// [beklenen] kasada olması gereken nakittir; sayılan tutar bununla karşılaştırılır.
///
/// ══ SHEET HİÇBİR FORMÜL VE HİÇBİR ANLAM BİLMEZ (lead kararı 2026-08-06) ════════════════════
/// Üçlü şöyle çizilir ve tek kuralı vardır: **üst − orta == alt**.
///   • üst  = [tamNakit]   adı [ustEtiket] ile ÇAĞIRANDAN gelir
///   • orta = [ortaTutar]  adı [ortaEtiket] ile ÇAĞIRANDAN gelir
///   • alt  = [beklenen]   "Beklenen nakit"
///
/// İKİ ETİKET DE NEDEN PARAMETRE: her ikisi de kapsama göre BAŞKA BİR ŞEYİ ölçüyor.
///   • orta → gün hesabında "Kuryelerde kalan" (henüz teslim EDİLMEMİŞ), kurye hesabında
///     "Teslim edilen" (teslim EDİLMİŞ) — zıt yönlü iki büyüklük.
///   • üst → gün hesabında günün tamamı, kurye hesabında o kuryenin PENCERE nakdi (son
///     kapanışından beri topladığı). Kurye o gün bir kez kapatıp yeniden çalışmışsa ikisi
///     AYNI DEĞİLDİR ve orada "Günün nakdi" yazmak yanlış olur.
///
/// [ortaTutar] NEGATİF OLABİLİR ve o zaman satır "+ tutar" olarak çizilir (gerekçe çizim
/// yerinde). Kimlik yine aynıdır: üst − (−x) == üst + x. Etiketi de çağıran değiştirir.
///
/// Bu etiketleri sheet'in `gunHesabi` bayrağından çıkarması, bu vardiyada ALTI kez yakalanan
/// hatanın tam kalıbıdır: anlamı değişen sayıyı eski kelimesiyle taşımak. Kopyayı çağıran verir,
/// çünkü anlamı bilen odur.
///
/// Sayıların hepsi REPO'DAN gelir; sheet ne toplar ne çıkarır. Kimlik tutmuyorsa çizim değil VERİ
/// hatalıdır — o yüzden kural testle kilitlenir, kodda `assert` ile değil.
///
/// [ortaTutar] sıfırsa orta satır (ve onunla birlikte üst satır) HİÇ çizilmez: düşülecek bir şey
/// yokken üçlü açıklamaya gerek yoktur ve "− 0,00 ₺" her akşam cevapsız bir soru olurdu.
///
/// [cerceveNotu] de aynı disiplinle ÇAĞIRANDAN gelir: bu sheet'in rakamları kurye kapsamında
/// PENCERE çerçevesindendir, arkasındaki ekran ise GÜN konuşur. İkisinin aynı parayı kapsamadığı
/// günlerde bayi yan yana iki farklı rakam görüyor ve arayı açıklayan hiçbir satır yoktu. Metin
/// FORMÜL İDDİA ETMEZ, yalnız ÇERÇEVEYİ söyler; null ise (çoğu gün) hiç çizilmez.
Future<KapatmaSonucu?> gunKapatmaSheet(
  BuildContext context, {
  required String kapsamAdi,
  required bool gunHesabi,
  required int beklenen,
  required int teslimat,
  int tamNakit = 0,
  String ustEtiket = 'Günün nakdi',
  String? ortaEtiket,
  int ortaTutar = 0,
  String? cerceveNotu,
  SenkronTazeligi? senkron,
}) {
  return sipSheet<KapatmaSonucu>(
    context,
    baslik: 'Hesabı Kapat · Kasa Devri',
    govde: (ctx) => _KapatmaGovdesi(
      kapsamAdi: kapsamAdi,
      gunHesabi: gunHesabi,
      beklenen: beklenen,
      teslimat: teslimat,
      tamNakit: tamNakit,
      ustEtiket: ustEtiket,
      ortaEtiket: ortaEtiket,
      ortaTutar: ortaTutar,
      cerceveNotu: cerceveNotu,
      senkron: senkron,
    ),
  );
}

class _KapatmaGovdesi extends StatefulWidget {
  const _KapatmaGovdesi({
    required this.kapsamAdi,
    required this.gunHesabi,
    required this.beklenen,
    required this.teslimat,
    required this.tamNakit,
    required this.ustEtiket,
    required this.ortaEtiket,
    required this.ortaTutar,
    required this.cerceveNotu,
    required this.senkron,
  });

  final String kapsamAdi;
  final bool gunHesabi;
  final int beklenen;
  final int teslimat;
  final int tamNakit;
  final String ustEtiket;
  final String? ortaEtiket;
  final int ortaTutar;

  /// Sheet'in çerçevesi ekranınkiyle çakışmıyorsa bunu söyleyen kısa satır; null ise çizilmez.
  final String? cerceveNotu;

  /// null ise tazelik şeridi hiç çizilmez (çağıran o kapsamda göstermemeye karar vermiştir).
  final SenkronTazeligi? senkron;

  @override
  State<_KapatmaGovdesi> createState() => _KapatmaGovdesiState();
}

class _KapatmaGovdesiState extends State<_KapatmaGovdesi> {
  final _sayilan = TextEditingController();
  final _not = TextEditingController();

  @override
  void dispose() {
    _sayilan.dispose();
    _not.dispose();
    super.dispose();
  }

  int? get _sayilanKurus {
    final s = _sayilan.text.trim();
    if (s.isEmpty) return null;
    return kurusaCevir(s);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final sayilan = _sayilanKurus;
    final fark = sayilan == null ? 0 : sayilan - widget.beklenen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TAZELİK EN ÜSTTE: rakamları okumadan ÖNCE görünmeli. Altına konsaydı, bayi tutarı
        // okuyup sayıma başladıktan sonra "bu rakam eksik olabilir" uyarısıyla karşılaşırdı.
        if (widget.senkron != null)
          SenkronTazeligiSeridi(
            tazelik: widget.senkron!,
            // Gün kapanışında YALNIZ bayatken konuşur; kurye kapanışında taze durumu da
            // soluk bir satırla söyler (gerekçe widget'ın içinde).
            yalnizBayatta: widget.gunHesabi,
          ),

        if (widget.teslimat == 0)
          const AlanNotu(
            'Bu hesapta bugün hiç teslimat yok — yine de kapatabilirsiniz.',
            tur: AlanNotuTuru.uyari,
          ),

        // ARADAKİ FARK VARSA HESABIN TAMAMI YAZILIR (üst → orta → alt). Yalnız "beklenen nakit"
        // yazsaydık, cirosunun 12.000 olduğunu bilen bayi 7.000'lik bir beklenti görüp
        // uygulamanın yanıldığını düşünürdü — BRIEF'in kırmızı çizgisi tam burada kırılırdı:
        // "rakamlar bayinin elle tuttuğu defterle tutmazsa ürüne güven ölür".
        //
        // Orta satırın ADI çağırandan gelir (dosya başındaki gerekçe): gün hesabında
        // "Kuryelerde kalan", kurye hesabında "Gün içinde alınan" — zıt yönlü iki büyüklük.
        if (widget.ortaEtiket != null && widget.ortaTutar != 0) ...[
          DegerKarti(
            satirlar: [
              DegerSatiri(etiket: widget.ustEtiket, deger: sipTutar(widget.tamNakit)),
              DegerSatiri(
                etiket: widget.ortaEtiket!,
                // İŞARET DEĞERDEN TÜRER, SABİT DEĞİLDİR. [ortaTutar] gün kapsamında NEGATİF
                // olabilir (kurye dünden taşıdığı nakdi bugün teslim ettiyse kasaya günün kendi
                // nakdinden FAZLASI girer). Sabit "−" ile basıldığında ekran "− -5.000,00 ₺"
                // yazıyordu: hem bozuk hem yanlış yönlü. `sipTutar` negatifi kendi başına "−"
                // ile basar; o yüzden mutlak değer verilir ve işareti burası koyar.
                //
                // Sheet yine hiçbir ANLAM bilmiyor: işaret aritmetiktir (üst − orta == alt),
                // kelime değil. Negatifte ETİKETİN de değişmesi gerekir ("kalan" demesin) ama o
                // karar ÇAĞIRANINDIR — anlamı bilen odur.
                deger: '${widget.ortaTutar < 0 ? '+' : '−'} '
                    '${sipTutar(widget.ortaTutar.abs())}',
                degerRengi: t.ink2,
              ),
            ],
          ),
          const SizedBox(height: SipSpace.md),
        ],

        // CSS `.kd-row`
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  widget.gunHesabi
                      ? 'Beklenen nakit'
                      : 'Beklenen nakit (${widget.kapsamAdi})',
                  style: SipText.gsSatirEtiket.copyWith(color: t.ink2),
                ),
              ),
              const SizedBox(width: SipSpace.lg),
              Text(
                sipTutar(widget.beklenen),
                style: SipText.tutar20.copyWith(color: t.ink),
              ),
            ],
          ),
        ),

        // ÇERÇEVE NOTU RAKAMLARIN ALTINDA: yukarıdaki üç sayının hangi aralığı kapsadığını
        // söyler. Üstüne konsaydı bayi henüz hangi rakamdan söz edildiğini bilmeden okurdu.
        if (widget.cerceveNotu != null)
          AlanNotu(widget.cerceveNotu!, tur: AlanNotuTuru.bilgi),

        const SipFormEtiket('SAYILAN NAKİT (₺)', ustBosluk: 2),
        // CSS `.kd-input` — 56 yüksek, 22 punto rakam.
        SipInput(
          controller: _sayilan,
          ipucu: '0',
          klavye: const TextInputType.numberWithOptions(decimal: true),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
          stil: SipText.tutar(22),
          yukseklik: 56,
          otomatikOdak: true,
          onChanged: (_) => setState(() {}),
        ),

        if (sayilan != null) FarkSeridi(fark: fark),
        if (sayilan != null && fark < 0)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.xl),
            child: SipNotKutusu(
              tur: SipNotTuru.hata,
              ikon: SipIcons.alert,
              metin: 'Eksik tutar kanıt olarak arşive geçer; kapatma engellenmez.',
            ),
          ),

        const SipFormEtiket('NOT (OPSİYONEL)'),
        SipInput(controller: _not, ipucu: 'Fark açıklaması, devreden…', satirlar: 2),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Kapat ve Arşivle',
          ikon: SipIcons.lock,
          onTap: sayilan == null
              ? null
              : () => Navigator.of(context).pop(
                    KapatmaSonucu(sayilan: sayilan, not: _not.text.trim()),
                  ),
        ),
      ],
    );
  }
}

/// CSS `.kd-fark` — tam / eksik / fazla şeridi. Kasa devri ekranı da aynısını kullanır.
class FarkSeridi extends StatelessWidget {
  const FarkSeridi({super.key, required this.fark});

  final int fark;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final (etiket, renk, zemin) = switch (fark) {
      < 0 => ('EKSİK', t.danger, t.dangerSoft),
      > 0 => ('FAZLA', t.warn, t.warnSoft),
      _ => ('TAM', t.ok, t.okSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.br2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                etiket,
                style: SipText.metin(11.5, w: 700)
                    .copyWith(color: renk, letterSpacing: 0.69),
              ),
            ),
            Text(
              sipTutar(fark.abs()),
              style: SipText.tutar(19, w: 800).copyWith(color: renk),
            ),
          ],
        ),
      ),
    );
  }
}

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
    baslik: '$kapsamAdi · Arşiv',
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
          metin: '${gunSaatBicimi(k.occurredAt, bugun: bugun)} · kapatıldı · '
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
            metin: 'Bu kapanış geri alındı. Rakamlar o anki kaydı gösterir; '
                'hesabın güncel durumu için sonraki kapanışa bakın.',
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

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Paylaşılan küçük parçalar
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.gs-kapali` — yeşil zeminli "kapatıldı" şeridi.
class KapaliSerit extends StatelessWidget {
  const KapaliSerit({super.key, required this.metin, this.ikon = SipIcons.check});

  final String metin;
  final String ikon;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      decoration: BoxDecoration(color: t.okSoft, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2.2, renk: t.ok),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12.5, w: 700).copyWith(color: t.ok),
            ),
          ),
        ],
      ),
    );
  }
}

/// "45" → 4500 · "45,5" → 4550. Geçersizse null (para: sessiz yuvarlama YOK).
int? kurusaCevir(String metin) {
  final s = metin.trim().replaceAll('.', '');
  if (s.isEmpty) return null;
  final parcalar = s.split(',');
  if (parcalar.length > 2) return null;
  final lira = int.tryParse(parcalar[0].isEmpty ? '0' : parcalar[0]);
  if (lira == null) return null;
  if (parcalar.length == 1) return lira * 100;
  final kurusMetni = parcalar[1];
  if (kurusMetni.isEmpty) return lira * 100;
  if (kurusMetni.length > 2) return null;
  if (int.tryParse(kurusMetni) == null) return null;
  return lira * 100 + int.parse(kurusMetni.padRight(2, '0'));
}

/// ISO8601 → "Bugün 18:05" · "Dün 09:20" · "24.07 18:05" (tasarım `s-gunsonu.jsx:85` `{a.tarih}`).
///
/// Arşiv birden çok günün kapanışını taşır; yalnız saat basılınca (eski `saatBicimiKisa`)
/// satırlar birbirinden ayırt edilemiyordu.
///
/// [bugun] ZORUNLUDUR ve DÜZELTİLMİŞ saatten gelen TR takvim günü olmalıdır
/// (`bugunTrDuzeltilmis`). Eskiden imza `{DateTime? simdi}` idi ve boş bırakılınca CİHAZ saatine
/// düşüyordu: kaydın GÜNÜ düzeltilmiş saatten, "Bugün/Dün" kelimesi cihaz saatinden çıkıyordu —
/// telefonu ileri kurulmuş bayi, bugün kapattığı hesabın altında "Dün 09:20" okuyordu. Varsayılan
/// bırakmıyoruz: sessiz bir yedek, bu kusurun tam olarak nasıl doğduğudur; parametre zorunlu
/// olunca her çağrı yerini derleyici sorar.
String gunSaatBicimi(String iso, {required DateTime bugun}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final tr = t.toUtc().add(kTrOffset); // yalnız SAAT için; gün kararı `trGunu`nun
  final gun = trGunu(t);
  // Fark UTC üzerinden ölçülür: yerel takvimde gün uzunluğu DST'yle 23/25 saate kayabilir ve
  // `inDays` 23 saatlik bir farkı 0 sayardı. Türkiye'de DST yok ama test makinesinde olabilir.
  final fark = DateTime.utc(bugun.year, bugun.month, bugun.day)
      .difference(DateTime.utc(gun.year, gun.month, gun.day))
      .inDays;
  final saat = '${_iki(tr.hour)}:${_iki(tr.minute)}';
  // İleri tarihli kayıt (cihaz saati geri alınmış) gün.ay ile basılır — "-3 gün" saçmalığı yok.
  if (fark == 0) return 'Bugün $saat';
  if (fark == 1) return 'Dün $saat';
  return '${_iki(tr.day)}.${_iki(tr.month)} $saat';
}

String _iki(int n) => n.toString().padLeft(2, '0');
