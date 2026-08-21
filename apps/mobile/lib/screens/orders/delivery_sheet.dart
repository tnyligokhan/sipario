// Teslim & Ödeme sheet'i — CSS `.teslim`, `.teslim-tut`, `.odeme-grid`, `.odeme-b`,
// `.teslim-uyari`. Kaynak: s-siparisler.jsx `SiparisDetay` içindeki "Teslim & Ödeme" sheet'i.
//
// ÖDEME TİPİ 'nakit' ÖN-SEÇİLİ başlar (tasarım s-siparisler.jsx:443). Bir süre "hiçbiri seçili
// değil + düğme pasif" denendi; 2026-07-26'da tasarıma dönüldü: nakit teslimlerin ezici
// çoğunluğudur, her teslimde fazladan bir dokunuş istemek işi yavaşlatıyordu. Yanlış tipe karşı
// koruma kaydın kendisinde: tutar ekranda yazılı, defter append-only ve düzeltme yolu var.
//
// Veresiye karosu müşterisiz siparişte GİZLENMEZ, PASİF çizilir (tasarım `disabled` + `opacity
// .45`) — altındaki açıklama neden kapalı olduğunu söyler.
//
// TAHSİL EDİLEN TUTAR DÜZENLENEBİLİR (2026-07-27, saha eksiği 7): tasarım tutarı salt-okunur
// gösteriyordu ve teslim "ya tamamı peşin ya tamamı veresiye" ikilisine sıkışmıştı. Sahada
// müşteri 200 ₺'lik teslimatın 120 ₺'sini verip gerisini borca yazdırıyor; bayi bunu ancak
// "peşin" deyip sonra elle bakiye düzeltmesiyle telafi edebiliyordu — ki `correction` KASAYA
// girmez, kasa özeti yanlış çıkardı. Artık tek gerçek yazılır: ne alındıysa o.
//
// KAPIDA İSKONTO (kullanıcı isteği 2026-07-30: *"420 liralık siparişte 400 lira ödeme alınabilir;
// 'borçlu gösterme' kutusu olması gerekiyor"*). Kısmi tahsilat zaten yazılabiliyordu ama TEK bir
// anlamı vardı: kalan BORÇTUR. Sahada ikinci bir anlam var — bayi kapıda 20 ₺ kırıyor ve o 20 ₺
// tahsil edilmeyecek, İSKONTODUR. İkisi aynı ekrandan doğduğu için ayrımı kullanıcı yapar:
// tutar sipariş tutarının altına düşünce "Kalanı borç yazma (iskonto)" anahtarı belirir.
//
// İSKONTO NEDEN "TAHSİLAT" DEĞİL: kasa sayımı 400 ₺ görmeli, 420 değil. Kırılan 20 ₺ kasaya hiç
// girmedi; onu `payment` yazmak gün sonunda sayılan nakitle defteri çeliştirirdi (bayi 20 ₺ eksik
// sayar ve fark KANIT olarak kapanışa geçerdi — hem de her iskontoda). Bu yüzden iskonto AYRI bir
// defter tipidir ve `payment_type` TAŞIMAZ: kasanın değişmezi zaten "payment_type taşıyan kayıt
// kasaya dokundu"dur (DECISIONS Faz 3), yani kasa kodu TEK SATIR değişmeden doğru kalır.
//
// DEFTERE NE DÜŞER (mevcut çift-satır modelinin GENELLEMESİ):
//   debit(+sipariş tutarı)   — satış her hâlükârda borç doğurur,
//   payment(−tahsil edilen)  — yalnız para alındıysa (tahsil > 0), ödeme tipiyle,
//   discount(−iskonto)       — yalnız kutu işaretliyse; ödeme tipi YOK, kasaya dokunmaz.
// Kalan fark AYRI BİR KAYIT DEĞİLDİR: ödenmemiş `debit`in kendisi borçtur, bakiye zaten
// `SUM(amount_kurus)`. Veresiye = tahsil 0 (yalnız debit), peşin = tahsil tutarın tamamı — ikisi
// de bu kuralın uç noktası. İskonto da bakiyeyi kendi satırıyla kapatır, `debit`i DÜZELTMEZ:
// append-only (kırmızı çizgi #2) hiçbir noktada esnetilmiyor — sipariş 420 ₺ satıldı, 400 ₺
// tahsil edildi, 20 ₺ kırıldı; üçü de defterde ayrı ayrı okunur.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../money.dart';
import 'delivery_rules.dart';
import 'order_queries.dart';

// Saf kurallar (teslimOdemeTipi · teslimBorcFarki · teslimTahsilatHatasi · teslimIskonto*) ayrı
// dosyada yaşar ama BURADAN da görünür: mevcut testler ve çağıranlar tek import'la çalışıyordu,
// dosya 500 satır sınırı için bölünürken o sözleşme kırılmasın.
export 'delivery_rules.dart';

/// Teslim sheet'inin sonucu: hangi ödeme tipiyle, NE KADAR tahsil edildi.
///
/// İkisi ayrı bilgidir — "nakit" tipi tutarın tamamının alındığı anlamına GELMEZ (kısmi ödeme).
class TeslimSonucu {
  const TeslimSonucu({
    required this.odemeTipi,
    required this.tahsilKurus,
    this.iskontoKurus = 0,
  });

  /// 'nakit' | 'kart' | 'havale' | 'veresiye'. Hiç para alınmadıysa DAİMA 'veresiye'
  /// (bkz. [teslimOdemeTipi]) — sipariş kaydı "nakit" deyip kasaya sıfır girmesin.
  final String odemeTipi;

  /// Tahsil edilen tutar (int kuruş, ≥ 0). 0 = tamamı veresiye.
  final int tahsilKurus;

  /// Kırılan (borç YAZILMAYAN) tutar — pozitif kuruş, 0 = iskonto yok. [tahsilKurus] ile
  /// KARIŞTIRILMAZ: biri kasaya giren para, diğeri hiç girmeyen ve borç da doğurmayan tutardır.
  final int iskontoKurus;
}

/// Teslim sheet'ini açar; kullanıcı onaylarsa [TeslimSonucu] döner, `null` = vazgeçildi.
/// ÇAĞIRAN TARAF teslim işini `OrderRepository.deliver` ile yapar — bu dosya hiçbir yazma yapmaz
/// (defter/olay yazımı tek yerden geçsin).
///
/// [oncekiBakiyeKurus] müşterinin teslimden ÖNCEKİ defter bakiyesidir (imzalı: + borç). Yalnız
/// uyarı metnini zenginleştirir; verilmezse akış aynen çalışır.
/// [iskontoYetkisi] false ise "Kalanı borç yazma (iskonto)" anahtarı HİÇ çizilmez ve deftere
/// iskonto düşemez (kullanıcı isteği 2026-08-04 — bayi kuryenin para kırmasını kapatabilmeli).
/// Kısmi tahsilat yine yapılabilir: eksik kalan tutar BORÇ olur, kırılmaz. İkisi ayrı kararlardır
/// ve kuryenin para tahsil etme yeteneğini kısmak bu anahtarın işi değildir.
Future<TeslimSonucu?> teslimSheetAc(
  BuildContext context, {
  required int toplamKurus,
  required bool musteriVar,
  int oncekiBakiyeKurus = 0,
  bool iskontoYetkisi = true,
}) =>
    sipSheet<TeslimSonucu>(
      context,
      baslik: 'Teslim ve Ödeme',
      govde: (ctx) => _TeslimGovde(
        toplamKurus: toplamKurus,
        musteriVar: musteriVar,
        oncekiBakiyeKurus: oncekiBakiyeKurus,
        iskontoYetkisi: iskontoYetkisi,
      ),
    );

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sheet gövdesi
// ═══════════════════════════════════════════════════════════════════════════════════════════

class _TeslimGovde extends StatefulWidget {
  const _TeslimGovde({
    required this.toplamKurus,
    required this.musteriVar,
    required this.oncekiBakiyeKurus,
    required this.iskontoYetkisi,
  });

  final int toplamKurus;
  final bool musteriVar;
  final int oncekiBakiyeKurus;
  final bool iskontoYetkisi;

  @override
  State<_TeslimGovde> createState() => _TeslimGovdeState();
}

class _TeslimGovdeState extends State<_TeslimGovde> {
  /// Tasarım `React.useState('nakit')` — ön-seçili gelir.
  String _odeme = 'nakit';

  /// Ön dolgu sipariş tutarının TAMAMI: teslimlerin çoğu tam tahsilattır, kısmi olan istisnadır.
  /// İstisnayı yazmak bir alan düzenlemesi, kuralı yazmak sıfır dokunuş.
  late final TextEditingController _tutar =
      TextEditingController(text: teslimTutarGirdisi(widget.toplamKurus));

  String? _hata;

  /// "Kalanı borç yazma (iskonto)" — KAPALI başlar. Varsayılanın kapalı olması pazarlıksızdır:
  /// açık gelseydi, kısmi ödemeyi bugünkü anlamıyla (kalan borç) yazan bayi tek dokunuşla
  /// müşterisinin borcunu SİLMİŞ olurdu ve bunu ancak ay sonu hesabında fark ederdi.
  bool _borcYazma = false;

  @override
  void dispose() {
    _tutar.dispose();
    super.dispose();
  }

  /// Veresiye seçiliyken tahsilat alanı kilitlidir (veresiye = hiç para alınmadı) ve müşterisiz
  /// siparişte de kilitlidir (tek geçerli değer sipariş tutarıdır — [teslimTahsilatHatasi]).
  bool get _tutarDuzenlenebilir => _odeme != 'veresiye' && widget.musteriVar;

  void _odemeSec(String tip) {
    setState(() {
      final oncekiVeresiye = _odeme == 'veresiye';
      _odeme = tip;
      _hata = null;
      // Ödeme tipi değişince iskonto niyeti SIFIRLANIR: karo değiştirmek tutarı da değiştiriyor
      // (veresiyeye geçişte 0, dönüşte tam tutar) ve önceki tutara verilmiş "kırdım" kararının
      // yeni tutara sessizce taşınması, kullanıcının görmediği bir iskonto yazardı.
      _borcYazma = false;
      if (tip == 'veresiye') {
        _tutar.text = teslimTutarGirdisi(0);
      } else if (oncekiVeresiye) {
        // Veresiyeden dönüşte alan tam tutara sıfırlanır: 0 kalsaydı "nakit" karosu seçili
        // görünürken kayıt yine veresiye düşerdi (teslimOdemeTipi), kullanıcı bunu görmezdi.
        _tutar.text = teslimTutarGirdisi(widget.toplamKurus);
      }
    });
  }

  void _kaydet() {
    final tahsil = parseKurus(_tutar.text);
    final hata = teslimTahsilatHatasi(
      tahsilKurus: tahsil,
      toplamKurus: widget.toplamKurus,
      musteriVar: widget.musteriVar,
    );
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    Navigator.of(context).pop(TeslimSonucu(
      odemeTipi: teslimOdemeTipi(_odeme, tahsil!),
      tahsilKurus: tahsil,
      iskontoKurus: _iskonto(tahsil),
    ));
  }

  /// Anahtar GÖRÜNMÜYORSA iskonto da yoktur — görünürlük koşulu ile yazma koşulu TEK yerden
  /// çıkar ki ekranda olmayan bir işaret deftere kayıt düşüremesin.
  int _iskonto(int tahsil) => _iskontoSorulur(tahsil)
      ? teslimIskontoKurus(
          toplamKurus: widget.toplamKurus, tahsilKurus: tahsil, borcYazma: _borcYazma)
      : 0;

  /// Veresiye karosunda anahtar HİÇ çıkmaz: "tamamı borç" ile "kalanı borç yazma" birbirinin
  /// zıddıdır ve orada tutar alanı 0'a kilitli olduğu için anahtar, tek dokunuşla siparişin
  /// TAMAMINI kıran bir yol açardı.
  /// Yetki kapalıysa anahtar hiç sorulmaz — ve yukarıdaki `_iskonto` "görünmüyorsa yazılmaz"
  /// kuralı sayesinde deftere de düşemez. Tek kapı, iki sonuç.
  bool _iskontoSorulur(int? tahsil) =>
      widget.iskontoYetkisi &&
      _odeme != 'veresiye' &&
      teslimIskontoSorulur(tahsilKurus: tahsil, toplamKurus: widget.toplamKurus);

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final tahsil = parseKurus(_tutar.text);
    final fark = tahsil == null
        ? 0
        : teslimBorcFarki(toplamKurus: widget.toplamKurus, tahsilKurus: tahsil);
    final iskontoSorulur = _iskontoSorulur(tahsil);
    final iskonto = tahsil == null ? 0 : _iskonto(tahsil);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .teslim-tut — siparişin tutarı: tahsilatın karşılaştırıldığı SABİT büyüklük.
        Padding(
          padding: const EdgeInsets.fromLTRB(2, SipSpace.xs, 2, SipSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Sipariş tutarı',
                    style: SipText.gsSatirEtiket.copyWith(color: t.ink2)),
              ),
              Text(sipTutar(widget.toplamKurus),
                  style: SipText.tutar22.copyWith(color: t.ink)),
            ],
          ),
        ),
        const SipFormEtiket('Ödeme tipi'),
        // .odeme-grid — 3 sütun; karo yüksekliği CSS'te SABİT 44 px (_sayfa.html:645).
        // `childAspectRatio` kullanılırsa yükseklik cihaz genişliğine göre kayar (dar telefonda
        // 44, geniş ekranda 55) — `mainAxisExtent` ölçüyü sabitler.
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            mainAxisExtent: 44,
          ),
          children: [
            for (final tip in odemeTipleri)
              _OdemeKarosu(
                etiket: odemeTipiEtiketi(tip),
                secili: _odeme == tip,
                // Pasif karo DOKUNMAYI YUTAR (tasarım `disabled`): veresiye müşterisiz
                // siparişte seçilemez — borç yazılacak müşteri yoktur.
                onTap: odemeTipiSecilebilir(tip, musteriVar: widget.musteriVar)
                    ? () => _odemeSec(tip)
                    : null,
              ),
          ],
        ),
        if (!widget.musteriVar) ...[
          const SizedBox(height: SipSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SipIcon(SipIcons.info, boyut: 13, kalinlik: 2.2, renk: t.muted),
              ),
              const SizedBox(width: 5),
              Expanded(
                // METİN SÖZLEŞMEDİR (ui_siparis_test.dart): kısmi ödeme geldiğinde bu cümleye
                // "ve eksik tahsilat" eklemiştim — mevcut testi kırdı ve gereksizdi. Alanın
                // müşterisizken kilitli olması zaten hemen altında görünüyor.
                child: Text(
                  'Tezgâh satışında veresiye yazılamaz, kayıtlı müşteri gerekir',
                  style: SipText.metin(12, w: 600).copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ],
        const SipFormEtiket('Tahsil edilen tutar (₺)'),
        SipInput(
          controller: _tutar,
          aktif: _tutarDuzenlenebilir,
          // Rakam + ayraç: sipariş tutarı kuruşlu olabilir (120,50) ve tam tahsilat da kısmi
          // tahsilat da kuruşu yazılabilmeden doğru girilemez. TR yazımını `parseKurus` çözer;
          // çözemezse SESSİZ YUVARLAMA yapmadan null döner ve kullanıcı hatayı görür.
          klavye: const TextInputType.numberWithOptions(decimal: true),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
          ipucu: '0',
          stil: SipText.tutar(22),
          yukseklik: 56,
          hata: _hata != null,
          onChanged: (_) => setState(() => _hata = null),
        ),
        // Hata da `_Uyari` şeridiyle çizilir: `SipHataSatiri` müşteri ekranlarının dosyasında
        // yaşıyor ve sipariş ekranları oradan sembol almıyor (order_queries.dart sözleşmesi).
        if (_hata != null) ...[
          const SizedBox(height: SipSpace.sm),
          _Uyari(metin: _hata!, renk: t.danger, zemin: t.dangerSoft, ikon: SipIcons.alert),
        ],
        if (iskontoSorulur) ...[
          const SizedBox(height: SipSpace.md),
          // METİN SÖZLEŞMEDİR (ui_iskonto_test.dart): kullanıcının istediği kutu budur ve
          // "iskonto" kelimesi parantez içinde DURUR — bayi kırma işlemini o adla biliyor,
          // "borç yazma" ise ne olacağını anlatır. İkisi birden yazılmazsa kutu ya muhasebe
          // terimi ya da belirsiz bir emir olurdu.
          SipToggle(
            etiket: 'Kalanı borç yazma (iskonto)',
            altEtiket: 'İşaretlenirse ${sipTutar(fark)} kırılır; müşteri borçlu görünmez',
            acik: _borcYazma,
            onDegis: (v) => setState(() => _borcYazma = v),
          ),
        ],
        ..._uyarilar(t, tahsil: tahsil, fark: fark, iskonto: iskonto),
        const SizedBox(height: 18),
        SipButon(
          etiket: 'Teslim Et ve Kaydet',
          ikon: SipIcons.check,
          onTap: _kaydet,
        ),
      ],
    );
  }

  /// Tutarın sonucunu SÖZLE anlatan şerit. Kısmi/fazla/veresiye üç ayrı gerçektir; hepsi aynı
  /// alandan doğduğu için kullanıcı ne kaydedeceğini alanın altında okur.
  List<Widget> _uyarilar(
    SipTokens t, {
    required int? tahsil,
    required int fark,
    required int iskonto,
  }) {
    if (tahsil == null) return const [];
    // İskonto varken kalan borç YOKTUR: şerit borcu değil KIRILAN tutarı anlatır, yoksa aynı
    // ekranda "kalan borca yazılacak" ile "borç yazılmayacak" yan yana durur ve bayi hangisinin
    // kaydedileceğini ekrandan okuyamaz.
    if (iskonto > 0) {
      return [
        const SizedBox(height: SipSpace.xl),
        _Uyari(
          metin: 'Kalan ${sipTutar(iskonto)} borç yazılmayacak, sipariş kapanacak',
          renk: t.accent,
          zemin: t.accentSoft,
          ikon: SipIcons.check,
        ),
      ];
    }
    final sonrakiBakiye = widget.oncekiBakiyeKurus + fark;

    if (tahsil == 0) {
      // METİN SÖZLEŞMEDİR (ui_siparis_test.dart `.teslim-uyari`): tutarı cümleye gömmüştüm,
      // mevcut testi kırdı. Tutar zaten hemen üstteki "Sipariş tutarı" satırında yazılı.
      return [
        const SizedBox(height: SipSpace.xl),
        _Uyari(
          metin: 'Tutar müşterinin borcuna eklenecek',
          renk: t.danger,
          zemin: t.dangerSoft,
          ikon: SipIcons.alert,
        ),
      ];
    }
    if (fark > 0) {
      return [
        const SizedBox(height: SipSpace.xl),
        _Uyari(
          metin: 'Kalan ${sipTutar(fark)} müşterinin borcuna yazılacak',
          renk: t.warn,
          zemin: t.warnSoft,
          ikon: SipIcons.alert,
        ),
      ];
    }
    if (fark < 0) {
      // Fazla ödeme: önce varsa önceki borcu kapatır, artarsa müşteri alacaklı kalır.
      final metin = sonrakiBakiye < 0
          ? 'Önceki borç kapanıyor, müşteri ${sipTutar(-sonrakiBakiye)} alacaklı duruma '
              'geçecek.'
          : 'Aradaki ${sipTutar(-fark)} müşterinin önceki borcundan düşülecek';
      return [
        const SizedBox(height: SipSpace.xl),
        _Uyari(metin: metin, renk: t.accent, zemin: t.accentSoft, ikon: SipIcons.info),
      ];
    }
    return const [];
  }
}

/// CSS `.odeme-b` — seçilince accent kenarlık + accent-soft zemin. [onTap] null ise tasarımdaki
/// `disabled` karo: `opacity: .45` ile soluk çizilir ama YERİNDE DURUR (kullanıcı seçeneğin var
/// olduğunu ve neden kapalı olduğunu görsün).
class _OdemeKarosu extends StatelessWidget {
  const _OdemeKarosu({required this.etiket, required this.secili, required this.onTap});

  final String etiket;
  final bool secili;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: SipDokun(
        onTap: onTap,
        zemin: secili ? t.accentSoft : t.surface2,
        basiliZemin: secili ? t.accentSoft : t.line,
        radius: SipRadius.br2,
        kenarlik: Border.all(
          color: secili ? t.accent : Colors.transparent,
          width: 1.5,
        ),
        child: Center(
          child: Text(
            etiket,
            style: SipText.metin(13, w: secili ? 700 : 600)
                .copyWith(color: secili ? t.accent : t.ink2),
          ),
        ),
      ),
    );
  }
}

/// CSS `.teslim-uyari` — tek satırlık renkli uyarı şeridi.
class _Uyari extends StatelessWidget {
  const _Uyari({
    required this.metin,
    required this.renk,
    required this.zemin,
    required this.ikon,
  });

  final String metin;
  final Color renk;
  final Color zemin;
  final String ikon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.br1),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2.2, renk: renk),
          const SizedBox(width: 7),
          Expanded(
            child: Text(metin, style: SipText.metin(12, w: 700).copyWith(color: renk)),
          ),
        ],
      ),
    );
  }
}
