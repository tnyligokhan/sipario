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

// ARŞİV DETAYI AYRI PARÇADA (500 satır kuralı — dosya 569 satıra çıkmıştı): burası bir hesabı
// KAPATIR, orası KAPANMIŞ bir hesabı geri OKUR. `part` seçildi ki bu dosyayı import eden altı
// çağrı yeri hiç değişmesin (`cash_handover_ara_tahsilat.dart` ile aynı desen).
part 'gun_arsiv_detay.dart';

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
/// Döküm şöyle çizilir ve tek kuralı vardır: **üst − gider − orta == alt**.
///   • üst   = [tamNakit]    adı [ustEtiket] ile ÇAĞIRANDAN gelir
///   • gider = [giderTutar]  "Gider (kasadan çıktı)" — sıfırsa satır HİÇ çizilmez
///   • orta  = [ortaTutar]   adı [ortaEtiket] ile ÇAĞIRANDAN gelir
///   • alt   = [beklenen]    "Beklenen nakit"
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
  int giderTutar = 0,
  String? cerceveNotu,
  SenkronTazeligi? senkron,
  bool sayimIstenmiyor = false,
}) {
  return sipSheet<KapatmaSonucu>(
    context,
    // BAŞLIK DÜĞMEYLE AYNI OLMAZ: arkadaki çubukta zaten "Hesabı Kapat" düğmesi duruyor; sheet
    // aynı sözü tekrarlarsa bayi hangi yüzeye baktığını ayırt edemez.
    baslik: sayimIstenmiyor
        ? 'Geçmiş Günü Kapat'
        : (gunHesabi ? 'Günü Kapat' : '$kapsamAdi Hesabı'),
    govde: (ctx) => _KapatmaGovdesi(
      kapsamAdi: kapsamAdi,
      gunHesabi: gunHesabi,
      beklenen: beklenen,
      teslimat: teslimat,
      tamNakit: tamNakit,
      ustEtiket: ustEtiket,
      ortaEtiket: ortaEtiket,
      ortaTutar: ortaTutar,
      giderTutar: giderTutar,
      cerceveNotu: cerceveNotu,
      senkron: senkron,
      sayimIstenmiyor: sayimIstenmiyor,
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
    required this.giderTutar,
    required this.cerceveNotu,
    required this.senkron,
    this.sayimIstenmiyor = false,
  });

  final String kapsamAdi;
  final bool gunHesabi;
  final int beklenen;
  final int teslimat;
  final int tamNakit;
  final String ustEtiket;
  final String? ortaEtiket;
  final int ortaTutar;

  /// KASADAN ÇIKAN gider (POZİTİF kuruş; 2026-08-25). Sıfırsa satır hiç çizilmez — gider
  /// kullanmayan bayide döküm eskisi gibi ÜÇ satırdır, dördüncü bir "Gider 0,00 ₺" her akşam
  /// cevapsız bir soru olurdu (iskonto satırıyla aynı kural).
  final int giderTutar;

  /// Sheet'in çerçevesi ekranınkiyle çakışmıyorsa bunu söyleyen kısa satır; null ise çizilmez.
  final String? cerceveNotu;

  /// null ise tazelik şeridi hiç çizilmez (çağıran o kapsamda göstermemeye karar vermiştir).
  final SenkronTazeligi? senkron;

  /// GEÇMİŞ GÜN KİPİ (2026-08-21): sayım alanı HİÇ ÇİZİLMEZ ve kapanış `sayilan: null` döner.
  ///
  /// ⚠️ BU BİR KOLAYLIK DEĞİL, MUHASEBE KAPISIDIR. Geçmiş bir günün kasası BUGÜN sayılamaz —
  /// para çoktan çekmeceden çıktı. Sayım kutusu açık bırakılsaydı bayi bugünkü çekmecesini
  /// sayıp üç gün önceki güne yazardı ve `diff` arşive KALICI olarak yanlış donardı
  /// (append-only: düzeltmesi ancak ikinci bir kayıtla olur).
  ///
  /// Yani geçmiş gün kapanışı bir MUTABAKAT değil, bir DEFTER KAPANIŞIDIR: "bu gün gözden
  /// geçirildi ve kapatıldı". Fark sıfır yazılır çünkü karşılaştırılacak bir sayım YOKTUR —
  /// sıfır burada "tuttu" demek değil, "sayılmadı" demektir ve ekran bunu açıkça söyler.
  final bool sayimIstenmiyor;

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
          AlanNotu(
            widget.sayimIstenmiyor
                ? 'Bu günde teslimat yok'
                : 'Bugün teslimat yok',
            tur: AlanNotuTuru.uyari,
          ),

        // ARADAKİ FARK VARSA HESABIN TAMAMI YAZILIR (üst → orta → alt). Yalnız "beklenen nakit"
        // yazsaydık, cirosunun 12.000 olduğunu bilen bayi 7.000'lik bir beklenti görüp
        // uygulamanın yanıldığını düşünürdü — BRIEF'in kırmızı çizgisi tam burada kırılırdı:
        // "rakamlar bayinin elle tuttuğu defterle tutmazsa ürüne güven ölür".
        //
        // Orta satırın ADI çağırandan gelir (dosya başındaki gerekçe): gün hesabında
        // "Kuryelerde kalan", kurye hesabında "Gün içinde alınan" — zıt yönlü iki büyüklük.
        // GİDER DÖKÜMÜ TEK BAŞINA DA AÇAR (2026-08-25): kurye hiç devir yapmamışken bile
        // (orta = 0) yolda 200 ₺ benzin almış olabilir ve beklenen tutar o kadar küçüktür.
        // Koşul yalnız `ortaTutar`a baksaydı, açıklaması olan tek fark açıklamasız kalırdı.
        if ((widget.ortaEtiket != null && widget.ortaTutar != 0) || widget.giderTutar != 0) ...[
          DegerKarti(
            satirlar: [
              DegerSatiri(etiket: widget.ustEtiket, deger: sipTutar(widget.tamNakit)),
              if (widget.giderTutar != 0)
                DegerSatiri(
                  etiket: 'Gider (kasadan çıktı)',
                  deger: '− ${sipTutar(widget.giderTutar.abs())}',
                  degerRengi: t.warn,
                ),
              if (widget.ortaEtiket != null && widget.ortaTutar != 0)
                DegerSatiri(
                  etiket: widget.ortaEtiket!,
                  // İŞARET DEĞERDEN TÜRER, SABİT DEĞİLDİR. [ortaTutar] gün kapsamında NEGATİF
                  // olabilir (kurye dünden taşıdığı nakdi bugün teslim ettiyse kasaya günün kendi
                  // nakdinden FAZLASI girer). Sabit "−" ile basıldığında ekran "− -5.000,00 ₺"
                  // yazıyordu: hem bozuk hem yanlış yönlü. `sipTutar` negatifi kendi başına "−"
                  // ile basar; o yüzden mutlak değer verilir ve işareti burası koyar.
                  //
                  // Sheet yine hiçbir ANLAM bilmiyor: işaret aritmetiktir (üst − gider − orta ==
                  // alt), kelime değil. Negatifte ETİKETİN de değişmesi gerekir ("kalan"
                  // demesin) ama o karar ÇAĞIRANINDIR — anlamı bilen odur.
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

        // GEÇMİŞ GÜNDE SAYIM ALANI HİÇ ÇİZİLMEZ (gerekçe [sayimIstenmiyor] üzerinde). Pasif bir
        // kutu çizmek yerine hiç çizmemek bilinçli: pasif kutu "bir gün açılabilir" der, oysa
        // geçmiş bir günün kasası hiçbir koşulda sayılamaz.
        if (widget.sayimIstenmiyor)
          const AlanNotu(
            'Geçmiş günün kasası bugün sayılamaz. Bu gün sayım olmadan kapanır.',
            tur: AlanNotuTuru.bilgi,
          )
        else ...[
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
        ],

        if (!widget.sayimIstenmiyor && sayilan != null) FarkSeridi(fark: fark),
        if (!widget.sayimIstenmiyor && sayilan != null && fark < 0)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.xl),
            child: SipNotKutusu(
              tur: SipNotTuru.hata,
              ikon: SipIcons.alert,
              metin: 'Eksik tutar kayda geçer',
            ),
          ),

        const SipFormEtiket('Not (isteğe bağlı)'),
        SipInput(controller: _not, ipucu: 'Fark açıklaması ya da devreden tutar', satirlar: 2),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Kapat ve Arşivle',
          ikon: SipIcons.lock,
          // GEÇMİŞ GÜNDE DÜĞME KOŞULSUZ AÇIKTIR: bekleyen bir giriş yok. Sayım kipinde ise
          // tutar girilmeden kapatmak, arşive "0 sayıldı" diye donan bir yalan üretirdi.
          onTap: !widget.sayimIstenmiyor && sayilan == null
              ? null
              : () => Navigator.of(context).pop(
                    KapatmaSonucu(
                      sayilan: widget.sayimIstenmiyor ? null : sayilan,
                      not: _not.text.trim(),
                    ),
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
