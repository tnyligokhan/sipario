// MUAF TELEFONLAR ekranı — tasarım s-muaf.jsx + Sipario.html `.muaf-*`, `.md-not`,
// `.ys-ekle`, `.ys-bos`, `.ys-sil`.
//
// Bu listedeki numaralar aradığında çağrı kartı AÇILMAZ. Liste `exempt_numbers` tablosunda
// KALICIDIR (bellekte tutulmaz): native arayan-tanıma tarafı kartı çizmeden önce aynı tabloya
// aynı anahtarla (son 10 hane) bakar — kapı orada, liste burada; ikisi tek satırda buluşur.
//
// Silme TOMBSTONE'dur (repo `deleted_at` yazar): senkronla diğer cihazlara yayılsın ve
// çevrimdışı iki cihazın kararı çakışıp kaybolmasın.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/outbox.dart' show phoneLast10;
import '../../repo/exempt_number_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';

class MuafEkrani extends StatelessWidget {
  const MuafEkrani({
    super.key,
    required this.db,
    this.writable = true,
    this.rol,
  });

  final AppDatabase db;

  /// Abonelik salt-okunur kipinde false — mevcut liste okunur, değiştirilemez.
  final bool writable;

  /// Oturumdaki rol; kurye bu ekranı göremez (K2).
  final String? rol;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final repo = ExemptNumberRepository(db);
    return YoneticiKapisi(
      rol: rol,
      baslik: 'Muaf Telefonlar',
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<ExemptNumber>>(
            stream: repo.watchAll(),
            builder: (context, snap) {
              final liste = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SipUst(
                    baslik: 'Muaf Telefonlar',
                    alt: liste == null
                        ? null
                        : '${liste.length} numara · çağrı kartı çıkmaz',
                    onGeri: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: liste == null
                        ? const SipGovde(children: [SipIskelet(adet: 3)])
                        : _Govde(repo: repo, liste: liste, writable: writable),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.repo, required this.liste, required this.writable});

  final ExemptNumberRepository repo;
  final List<ExemptNumber> liste;
  final bool writable;

  Future<void> _ekle(BuildContext context) async {
    if (!writable) {
      SipToast.goster(context, muafSaltOkunurUyarisi);
      return;
    }
    final girdi = await muafEklemeSheet(context, mevcut: liste);
    if (girdi == null || !context.mounted) return;
    await repo.add(phoneE164: girdi.numara, label: girdi.etiket);
    if (context.mounted) SipToast.goster(context, 'Numara muaf listesine eklendi');
  }

  Future<void> _sil(BuildContext context, ExemptNumber m) async {
    if (!writable) {
      SipToast.goster(context, muafSaltOkunurUyarisi);
      return;
    }
    final onay = await sipOnay(
      context,
      baslik: 'Listeden çıkarılsın mı?',
      mesaj: '${sipTelefon(m.phoneE164)} bundan sonra aradığında çağrı kartı AÇILIR.',
      onayEtiketi: 'Çıkar',
      tehlike: true,
    );
    if (!onay || !context.mounted) return;
    await repo.remove(m.id);
    if (context.mounted) SipToast.goster(context, 'Numara listeden çıkarıldı');
  }

  @override
  Widget build(BuildContext context) {
    return SipGovde(
      children: [
        // CSS `.md-not` — ekranın ne yaptığını tek cümlede söyleyen uyarı bloğu. Tasarımda
        // (`s-muaf.jsx:21`) "Caller ID kartı açılmaz" KALIN yazılır: not okunmadan geçilince
        // ekranın ne yaptığı anlaşılmıyor. Vurgu `onEtiket` ile başa alındı — `SipNotKutusu`
        // cümle ORTASINDA kalınlaştırmayı desteklemiyor (tema kilitli, yeni parametre yok).
        Padding(
          padding: const EdgeInsets.only(bottom: SipSpace.xl),
          child: SipNotKutusu(
            tur: SipNotTuru.uyari,
            ikon: SipIcons.info,
            onEtiket: 'Caller ID kartı açılmaz.',
            metin: 'Kurye, tedarikçi, kişisel numaralar için kullanın.',
          ),
        ),
        EkleSatiri(etiket: 'Muaf numara ekle', onTap: () => _ekle(context)),
        if (liste.isEmpty)
          // Tasarım (`s-muaf.jsx:24`) `phone` ikonu + tek satır: `phoneOff` "çağrı engellendi"
          // gibi okunuyordu ve açıklama satırı üstteki notu kelime kelime tekrar ediyordu.
          const SipBosDurum(
            ikon: SipIcons.phone,
            baslik: 'Muaf numara yok',
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.md),
            child: Column(
              children: [
                for (var i = 0; i < liste.length; i++)
                  MuafSatiri(
                    kayit: liste[i],
                    sonSatir: i == liste.length - 1,
                    onSil: () => _sil(context, liste[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Salt-okunur kip uyarısı — ürün ekranındaki eşdeğeriyle aynı dil.
const String muafSaltOkunurUyarisi = 'Salt-okunur kip: muaf liste değiştirilemez.';

/// CSS `.muaf-row` — yuvarlak ikon + etiket/numara + kırmızı çarpı.
class MuafSatiri extends StatelessWidget {
  const MuafSatiri({
    super.key,
    required this.kayit,
    required this.onSil,
    this.sonSatir = false,
  });

  final ExemptNumber kayit;
  final VoidCallback onSil;
  final bool sonSatir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final etiket = (kayit.label ?? '').trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: sonSatir ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            // CSS `.ara-ic`
            SipIkonKutu(
              ikon: SipIcons.phone,
              cap: 34,
              ikonBoyut: 16,
              kalinlik: 2,
              zemin: t.surface2,
              renk: t.muted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etiket.isEmpty ? 'İsimsiz' : etiket,
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      sipTelefon(kayit.phoneE164),
                      style: SipText.tutar(12, w: 600).copyWith(color: t.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.md),
            // CSS `.ys-sil`
            SipIkonButon(
              ikon: SipIcons.x,
              cap: 30,
              ikonBoyut: 17,
              kalinlik: 2.2,
              renk: t.danger,
              etiket: 'Listeden çıkar',
              onTap: onSil,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ekleme sheet'i — CSS `.sb-form`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Sheet'in sonucu: etiket (boşsa null) + kullanıcının yazdığı numara.
@immutable
class MuafGirdisi {
  const MuafGirdisi({required this.numara, this.etiket});

  final String numara;
  final String? etiket;
}

Future<MuafGirdisi?> muafEklemeSheet(
  BuildContext context, {
  required List<ExemptNumber> mevcut,
}) {
  return sipSheet<MuafGirdisi>(
    context,
    baslik: 'Muaf Numara Ekle',
    govde: (ctx) => _EklemeGovdesi(mevcut: mevcut),
  );
}

class _EklemeGovdesi extends StatefulWidget {
  const _EklemeGovdesi({required this.mevcut});

  final List<ExemptNumber> mevcut;

  @override
  State<_EklemeGovdesi> createState() => _EklemeGovdesiState();
}

class _EklemeGovdesiState extends State<_EklemeGovdesi> {
  final _etiket = TextEditingController();
  final _numara = TextEditingController();

  String? _hata;

  @override
  void dispose() {
    _etiket.dispose();
    _numara.dispose();
    super.dispose();
  }

  void _ekle() {
    final hata = muafNumaraHatasi(
      _numara.text,
      mevcutSon10: widget.mevcut.map((m) => m.phoneLast10).toList(),
    );
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    final etiket = _etiket.text.trim();
    Navigator.of(context).pop(MuafGirdisi(
      numara: _numara.text.trim(),
      etiket: etiket.isEmpty ? null : etiket,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('ETİKET', ustBosluk: 2),
        SipInput(
          controller: _etiket,
          ipucu: 'Ör. Kurye Ali, Tedarikçi',
          otomatikOdak: true,
        ),
        // Yıldız = zorunlu (tasarım `s-muaf.jsx:40`); etiket zorunlu, telefon değil.
        const SipFormEtiket('TELEFON *'),
        SipInput(
          controller: _numara,
          ipucu: '05XX XXX XX XX',
          klavye: TextInputType.phone,
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]'))],
          stil: SipText.tutar(15, w: 500),
          hata: _hata != null,
          onChanged: (_) {
            if (_hata != null) setState(() => _hata = null);
          },
        ),
        if (_hata != null) AlanNotu(_hata!),
        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Listeye Ekle', onTap: _ekle),
      ],
    );
  }
}

/// Numara doğrulaması — ekrandan BAĞIMSIZ (saf testle sınanır).
/// Geçerliyse null; değilse kullanıcıya gösterilecek tek satır hata.
///
/// Karşılaştırma SON 10 HANE üzerinden: +905321112233 / 05321112233 / 5321112233 aynı numaradır
/// (DECISIONS arayan tanıma kuralı; native taraf da aynı anahtara bakar).
/// Üst sınır artık hata metniyle TUTARLIDIR: eskiden 13 haneye kadar kabul ediliyordu ama hata
/// "10-11 hane" diyordu — kullanıcıya yalan söyleyen bir kapıydı. Ülke kodu sınırdan ÖNCE
/// ayıklanır, yoksa "+90 532…" (12 hane) yazan kullanıcı, numarası geçerli olduğu hâlde
/// reddedilirdi.
String? muafNumaraHatasi(String ham, {required List<String> mevcutSon10}) {
  var haneler = ham.replaceAll(RegExp(r'\D'), '');
  if (haneler.length > 11 && haneler.startsWith('90')) haneler = haneler.substring(2);
  if (haneler.length < 10 || haneler.length > 11) {
    return 'Geçerli telefon girin (10-11 hane)';
  }
  final son10 = phoneLast10(ham);
  if (mevcutSon10.contains(son10)) return 'Bu numara zaten muaf listesinde';
  return null;
}
