// AYARLAR → MESAJLAR — müşteriye giden metinlerin şablonları.
//
// ══ NEDEN AYRI SAYFA (kullanıcı eleştirisi 2026-08-13) ═════════════════════════════════════
// Hatırlatma şablonu "İşletme Profili" formunun içinde, vergi numarasıyla çalışma saatlerinin
// arasında duruyordu. Kullanıcının tespiti aynen şuydu: *"mesaj şablonları ilerleyen zamanlarda
// mesaj sayısı artacak, orada olmaya devam mı edecek?"*
//
// Cevap hayır ve bu sayfa TAM DA O BÜYÜMEYE GÖRE kuruldu. Bugün tek şablon var (borç
// hatırlatma); yarın sipariş onayı, yola çıktı bildirimi, teslimat teşekkürü gelebilir. Bu
// yüzden ekran "bir alan" değil BİR LİSTE çizer: yeni şablon eklemek [_sablonlar] listesine bir
// kayıt yazmaktır, yeni bir ekran ya da yeni bir bölüm açmak değil.
//
// ⚠️ HER ŞABLON KENDİ ALANINA YAZAR: liste büyürken hepsini tek `save` çağrısında toplamak
// cazip ama yanlış olurdu — kısmi kayıt (`Value.absent()`) tam da dokunulmayan alanın
// korunması için var. Kaydet düğmesi yalnız DEĞİŞEN şablonları gönderir.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../data/app_database.dart';
import '../../../repo/tenant_settings_repository.dart';
import '../../../theme/components/atoms.dart';
import '../../../theme/components/overlays.dart';
import '../../../theme/components/states.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../customers/borc_hatirlatma.dart' show hatirlatmaSablonuHatasi;
import '../hatirlatma_sablonu_alani.dart';
import '../isletme_atomlari.dart';
import '../isletme_profili_ekrani.dart' show profilSaltOkunurUyarisi;

/// Ekranda listelenen tek bir şablon tanımı.
///
/// YENİ ŞABLON EKLEMENİN TEK YOLU BUDUR: bir kayıt daha ekle. `oku` satırdan mevcut değeri
/// çıkarır, `yaz` yalnız o alanı gönderen bir `save` çağrısı üretir — yani şablonlar birbirinin
/// değerini asla ezemez.
class MesajSablonu {
  const MesajSablonu({
    required this.anahtar,
    required this.baslik,
    required this.aciklama,
    required this.oku,
    required this.yaz,
  });

  final String anahtar;
  final String baslik;

  /// Şablonun NEREDE kullanıldığı. Bayi, düzenlediği metnin hangi düğmeden çıktığını bilmeli;
  /// aksi hâlde "bu yazı nereye gidiyor" diye sormak zorunda kalır.
  final String aciklama;

  final String? Function(TenantSetting? satir) oku;
  final Future<void> Function(TenantSettingsRepository repo, String? deger) yaz;
}

/// Bugünkü şablonlar. Liste büyüdükçe bu sabit büyür; ekran değişmez.
const List<MesajSablonu> kMesajSablonlari = [
  MesajSablonu(
    anahtar: 'hatirlatma',
    baslik: 'Borç Hatırlatma',
    aciklama: 'Borçlular listesindeki WhatsApp düğmesinden gönderilir.',
    oku: _hatirlatmaOku,
    yaz: _hatirlatmaYaz,
  ),
];

String? _hatirlatmaOku(TenantSetting? s) => s?.reminderTemplate;

Future<void> _hatirlatmaYaz(TenantSettingsRepository repo, String? deger) =>
    repo.save(reminderTemplate: Value(deger));

class MesajSablonlariEkrani extends StatefulWidget {
  const MesajSablonlariEkrani({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  @override
  State<MesajSablonlariEkrani> createState() => _MesajSablonlariEkraniState();
}

class _MesajSablonlariEkraniState extends State<MesajSablonlariEkrani> {
  late final _repo = TenantSettingsRepository(widget.db);
  late final Future<TenantSetting?> _veri = _repo.get();

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Mesajlar', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: FutureBuilder<TenantSetting?>(
                future: _veri,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SipGovde(children: [SipIskelet(adet: 3)]);
                  }
                  return _Liste(repo: _repo, satir: snap.data, writable: widget.writable);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.repo, required this.satir, required this.writable});

  final TenantSettingsRepository repo;
  final TenantSetting? satir;
  final bool writable;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipGovde(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.xl),
          child: Text(
            'Müşterilerinize gönderilen hazır metinler. İçlerindeki *yer tutucular* gönderim '
            'anında gerçek bilgiyle değişir.',
            style: SipText.metin(12.5, w: 500, h: 1.5).copyWith(color: t.ink2),
          ),
        ),
        for (final s in kMesajSablonlari)
          _SablonSatiri(
            sablon: s,
            mevcut: s.oku(satir),
            writable: writable,
            repo: repo,
          ),
      ],
    );
  }
}

/// Tek şablon satırı — dokununca düzenleme sayfası açılır.
///
/// LİSTE + DÜZENLEME SAYFASI, tek sayfada alt alta ALANLAR DEĞİL: bugün tek şablon var ama
/// beşinci şablonda tek sayfa okunamaz bir metin duvarına dönerdi. Yapı büyümeyi baştan kabul
/// ediyor; bugünkü bedeli bir dokunuş, kazancı ise büyürken hiçbir şeyin değişmemesi.
class _SablonSatiri extends StatelessWidget {
  const _SablonSatiri({
    required this.sablon,
    required this.mevcut,
    required this.writable,
    required this.repo,
  });

  final MesajSablonu sablon;
  final String? mevcut;
  final bool writable;
  final TenantSettingsRepository repo;

  @override
  Widget build(BuildContext context) {
    // ÖZEL Mİ VARSAYILAN MI — bayi bunu listeden görebilmeli: "ben bunu değiştirmiş miydim?"
    final ozel = (mevcut ?? '').trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.md),
      child: AyarKarti(satirlar: [
        AyarSatiri(
          ikon: SipIcons.chat,
          baslik: sablon.baslik,
          altBaslik: ozel ? 'Özel metin' : 'Varsayılan metin',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => SablonDuzenleEkrani(
              sablon: sablon,
              baslangic: mevcut,
              repo: repo,
              writable: writable,
            ),
          )),
        ),
      ]),
    );
  }
}

/// Tek bir şablonun düzenleme sayfası.
class SablonDuzenleEkrani extends StatefulWidget {
  const SablonDuzenleEkrani({
    super.key,
    required this.sablon,
    required this.baslangic,
    required this.repo,
    required this.writable,
  });

  final MesajSablonu sablon;
  final String? baslangic;
  final TenantSettingsRepository repo;
  final bool writable;

  @override
  State<SablonDuzenleEkrani> createState() => _SablonDuzenleEkraniState();
}

class _SablonDuzenleEkraniState extends State<SablonDuzenleEkrani> {
  late final _metin = TextEditingController(text: widget.baslangic ?? '');
  String? _hata;
  bool _kaydediyor = false;

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    if (!widget.writable) {
      SipToast.goster(context, profilSaltOkunurUyarisi);
      return;
    }
    final hata = hatirlatmaSablonuHatasi(_metin.text);
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }

    setState(() => _kaydediyor = true);
    // BOŞ METİN null YAZILIR: "varsayılana dön" bunu demektir ve varsayılan ileride
    // iyileşirse, şablona hiç dokunmamış bayi o iyileşmeyi alır (boş dize bunu engellerdi).
    final deger = _metin.text.trim().isEmpty ? null : _metin.text.trim();
    await widget.sablon.yaz(widget.repo, deger);
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    SipToast.goster(context, '${widget.sablon.baslik} kaydedildi');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(
              baslik: widget.sablon.baslik,
              onGeri: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SipGovde(children: [
                Padding(
                  padding: const EdgeInsets.only(top: SipSpace.xl, bottom: SipSpace.md),
                  child: AlanNotu(widget.sablon.aciklama, tur: AlanNotuTuru.bilgi),
                ),
                HatirlatmaSablonuAlani(
                  controller: _metin,
                  hata: _hata,
                  onDegis: () {
                    if (_hata != null) setState(() => _hata = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: SipSpace.govde),
                  child: SipButon(
                    etiket: 'Kaydet',
                    onTap: _kaydet,
                    yukleniyor: _kaydediyor,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
