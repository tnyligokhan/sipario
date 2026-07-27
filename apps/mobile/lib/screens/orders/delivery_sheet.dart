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
// DEFTERE NE DÜŞER (mevcut çift-satır modelinin GENELLEMESİ, yeni kayıt tipi YOK):
//   debit(+sipariş tutarı)  — satış her hâlükârda borç doğurur,
//   payment(−tahsil edilen) — yalnız para alındıysa (tahsil > 0), ödeme tipiyle.
// Kalan fark AYRI BİR KAYIT DEĞİLDİR: ödenmemiş `debit`in kendisi borçtur, bakiye zaten
// `SUM(amount_kurus)`. Veresiye = tahsil 0 (yalnız debit), peşin = tahsil tutarın tamamı — ikisi
// de bu kuralın uç noktası. Append-only (kırmızı çizgi #2) hiçbir noktada esnetilmiyor.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../money.dart';
import 'order_queries.dart';

/// Teslim sheet'inin sonucu: hangi ödeme tipiyle, NE KADAR tahsil edildi.
///
/// İkisi ayrı bilgidir — "nakit" tipi tutarın tamamının alındığı anlamına GELMEZ (kısmi ödeme).
class TeslimSonucu {
  const TeslimSonucu({required this.odemeTipi, required this.tahsilKurus});

  /// 'nakit' | 'kart' | 'havale' | 'veresiye'. Hiç para alınmadıysa DAİMA 'veresiye'
  /// (bkz. [teslimOdemeTipi]) — sipariş kaydı "nakit" deyip kasaya sıfır girmesin.
  final String odemeTipi;

  /// Tahsil edilen tutar (int kuruş, ≥ 0). 0 = tamamı veresiye.
  final int tahsilKurus;
}

/// Teslim sheet'ini açar; kullanıcı onaylarsa [TeslimSonucu] döner, `null` = vazgeçildi.
/// ÇAĞIRAN TARAF teslim işini `OrderRepository.deliver` ile yapar — bu dosya hiçbir yazma yapmaz
/// (defter/olay yazımı tek yerden geçsin).
///
/// [oncekiBakiyeKurus] müşterinin teslimden ÖNCEKİ defter bakiyesidir (imzalı: + borç). Yalnız
/// uyarı metnini zenginleştirir; verilmezse akış aynen çalışır.
Future<TeslimSonucu?> teslimSheetAc(
  BuildContext context, {
  required int toplamKurus,
  required bool musteriVar,
  int oncekiBakiyeKurus = 0,
}) =>
    sipSheet<TeslimSonucu>(
      context,
      baslik: 'Teslim & Ödeme',
      govde: (ctx) => _TeslimGovde(
        toplamKurus: toplamKurus,
        musteriVar: musteriVar,
        oncekiBakiyeKurus: oncekiBakiyeKurus,
      ),
    );

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Saf kurallar — ekrandan AYRI (widget kurmadan test edilir; sipariş ekranlarının deseni)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Kaydedilecek ödeme tipi. Hiç para alınmadıysa seçili karo ne olursa olsun kayıt VERESİYEDİR:
/// `orders.payment_type` "nakit" derken defterde tek kuruş `payment` bulunmaması, gün sonu kasa
/// özetiyle sipariş listesini birbirine düşürürdü.
String teslimOdemeTipi(String secilen, int tahsilKurus) =>
    tahsilKurus <= 0 ? 'veresiye' : secilen;

/// Teslimden sonra müşterinin borcuna yazılacak İMZALI fark: + kalan borç, − fazla ödeme.
/// Bu fark deftere ayrı satır olarak YAZILMAZ (debit − payment farkı zaten budur); yalnız
/// ekranda ne olacağını söylemek için hesaplanır.
int teslimBorcFarki({required int toplamKurus, required int tahsilKurus}) =>
    toplamKurus - tahsilKurus;

/// Girilen tahsilat tutarının hata metni; geçerliyse `null`.
///
/// Müşterili siparişte HER tutar geçerlidir — 0 (tamamı veresiye) de, sipariş tutarından fazlası
/// da. Fazlası kasaya gerçekten giren paradır ve müşterinin ÖNCEKİ borcunu kapatır; reddetmek
/// bayiyi "önce teslim et, sonra ayrı tahsilat gir" iki adımına zorlar ve saha o ikinci adımı
/// atlar (para cebe girer, kayıt kaçar). Bakiyenin eksiye düşmesi modelde zaten mümkün.
///
/// Müşterisiz (tezgâh) siparişte tutar TAM olmalıdır: eksiğini yazacak da fazlasını alacak
/// yazacak bir cari yok — veresiye karosunun müşterisizken kilitli olmasıyla aynı gerekçe.
String? teslimTahsilatHatasi({
  required int? tahsilKurus,
  required int toplamKurus,
  required bool musteriVar,
}) {
  if (tahsilKurus == null) return 'Tutarı okuyamadım — ör. 120 ya da 120,50 yazın';
  if (!musteriVar && tahsilKurus != toplamKurus) {
    return 'Tezgâh satışında sipariş tutarının tamamı tahsil edilir '
        '(${sipTutar(toplamKurus)}) — eksiği yazılacak müşteri yok';
  }
  return null;
}

/// Kuruşu girdi kutusuna yazılabilir metne çevirir ("12050" → "120,50"). Binlik ayracı YOK:
/// `parseKurus` "1.234"ü binlik sayar, geri okumada belirsizlik kalmasın.
///
/// `screens/customers/customer_widgets.dart`teki `tutarGirdisi` ile aynı kuraldır; oradan ödünç
/// ALINMADI çünkü sipariş ekranları başka ajanların ekran dosyalarından sembol almıyor
/// (order_queries.dart başlığındaki sözleşme). Asıl yeri `money.dart` — taşınması lead'e bildirildi.
String _tutarGirdisi(int kurus) =>
    '${kurus ~/ 100},${(kurus % 100).toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sheet gövdesi
// ═══════════════════════════════════════════════════════════════════════════════════════════

class _TeslimGovde extends StatefulWidget {
  const _TeslimGovde({
    required this.toplamKurus,
    required this.musteriVar,
    required this.oncekiBakiyeKurus,
  });

  final int toplamKurus;
  final bool musteriVar;
  final int oncekiBakiyeKurus;

  @override
  State<_TeslimGovde> createState() => _TeslimGovdeState();
}

class _TeslimGovdeState extends State<_TeslimGovde> {
  /// Tasarım `React.useState('nakit')` — ön-seçili gelir.
  String _odeme = 'nakit';

  /// Ön dolgu sipariş tutarının TAMAMI: teslimlerin çoğu tam tahsilattır, kısmi olan istisnadır.
  /// İstisnayı yazmak bir alan düzenlemesi, kuralı yazmak sıfır dokunuş.
  late final TextEditingController _tutar =
      TextEditingController(text: _tutarGirdisi(widget.toplamKurus));

  String? _hata;

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
      if (tip == 'veresiye') {
        _tutar.text = _tutarGirdisi(0);
      } else if (oncekiVeresiye) {
        // Veresiyeden dönüşte alan tam tutara sıfırlanır: 0 kalsaydı "nakit" karosu seçili
        // görünürken kayıt yine veresiye düşerdi (teslimOdemeTipi), kullanıcı bunu görmezdi.
        _tutar.text = _tutarGirdisi(widget.toplamKurus);
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final tahsil = parseKurus(_tutar.text);
    final fark = tahsil == null
        ? 0
        : teslimBorcFarki(toplamKurus: widget.toplamKurus, tahsilKurus: tahsil);

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
                  'Tezgâh satışında veresiye kullanılamaz — kayıtlı müşteri gerekir.',
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
        ..._uyarilar(t, tahsil: tahsil, fark: fark),
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
  List<Widget> _uyarilar(SipTokens t, {required int? tahsil, required int fark}) {
    if (tahsil == null) return const [];
    final sonrakiBakiye = widget.oncekiBakiyeKurus + fark;

    if (tahsil == 0) {
      // METİN SÖZLEŞMEDİR (ui_siparis_test.dart `.teslim-uyari`): tutarı cümleye gömmüştüm,
      // mevcut testi kırdı. Tutar zaten hemen üstteki "Sipariş tutarı" satırında yazılı.
      return [
        const SizedBox(height: SipSpace.xl),
        _Uyari(
          metin: 'Tutar müşterinin borcuna eklenecek.',
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
          metin: 'Kısmi tahsilat — kalan ${sipTutar(fark)} müşterinin borcuna yazılacak.',
          renk: t.warn,
          zemin: t.warnSoft,
          ikon: SipIcons.alert,
        ),
      ];
    }
    if (fark < 0) {
      // Fazla ödeme: önce varsa önceki borcu kapatır, artarsa müşteri alacaklı kalır.
      final metin = sonrakiBakiye < 0
          ? 'Fazla ödeme — önceki borç kapanıyor, müşteri ${sipTutar(-sonrakiBakiye)} '
              'alacaklı duruma geçecek.'
          : 'Fazla ödeme — aradaki ${sipTutar(-fark)} müşterinin önceki borcundan düşülecek.';
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
