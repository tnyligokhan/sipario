// YÖNETİM → MESAJLAR — müşteriye giden metinler: hazır türler ve bayinin kendi eklediği mesajlar.
//
// ══ NEDEN LİSTE + DÜZENLEME SAYFASI (kullanıcı eleştirisi 2026-08-13) ══════════════════════
// Hatırlatma şablonu "İşletme Profili" formunun içinde, vergi numarasıyla çalışma saatlerinin
// arasında duruyordu. Kullanıcının tespiti aynen şuydu: *"mesaj şablonları ilerleyen zamanlarda
// mesaj sayısı artacak, orada olmaya devam mı edecek?"* Bu sayfa o büyümeye göre kuruldu ve
// 2026-11-06'da büyüdü: hazır türler `data/mesaj_sablonlari.dart`ta, bayi kendi mesajını ekler.
// Mesajlar sipariş ayrıntısındaki Bilgilendirme Mesajı düğmesinden seçilir.
//
// YALNIZ PATRON: kapı çekmecede ve kabukta. Çekmeceye taşınmadan önce de bu ekrana yalnız patron
// ulaşıyordu; yer değişti, yetki değişmedi.
//
// ⚠️ HER MESAJ YALNIZ KENDİ ALANINA YAZAR: Borç Hatırlatma `reminder_template`e, ötekiler
// `message_templates`e. `save` kısmi kayıttır ve dokunulmayan alan korunur.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../data/app_database.dart';
import '../../../data/ids.dart';
import '../../../data/mesaj_sablonlari.dart';
import '../../../repo/tenant_settings_repository.dart';
import '../../../theme/components/atoms.dart';
import '../../../theme/components/overlays.dart';
import '../../../theme/components/states.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../customers/borc_hatirlatma.dart';
import '../hatirlatma_sablonu_alani.dart';
import '../isletme_atomlari.dart';
import '../isletme_profili_ekrani.dart' show profilSaltOkunurUyarisi;

/// Ekranda düzenlenebilen tek mesaj. Üç türü vardır; ekran hangisi olduğunu bilmez.
abstract class MesajKaydi {
  const MesajKaydi();

  String get baslik;

  /// Mesajın nerede kullanıldığı. Bayi düzenlediği metnin nereden çıktığını bilmeli.
  String get aciklama;

  /// Bayinin yazdığı metin; varsayılan kullanılıyorsa null.
  String? get ozelMetin;

  /// Hazır metin; bayinin kendi mesajında yoktur.
  String? get varsayilan => null;

  List<HatirlatmaYerTutucu> get yerTutucular => bilgilendirmeYerTutuculari;

  bool get adDuzenlenir => false;
  bool get silinebilir => false;

  /// Form bu metinle açılır: bayi müşteriye ne gideceğini boş kutu yerine görmeli.
  String get baslangic => ozelMetin ?? varsayilan ?? '';

  String? adHatasi(String ad) => null;
  String? metinHatasi(String metin) => hatirlatmaSablonuHatasi(metin);

  Future<void> kaydet(TenantSettingsRepository repo, {required String ad, required String metin});

  Future<void> sil(TenantSettingsRepository repo) async {}
}

class _BorcKaydi extends MesajKaydi {
  const _BorcKaydi(this._kayitli);

  final String? _kayitli;

  @override
  String get baslik => 'Borç Hatırlatma';

  @override
  String get aciklama => 'Sipariş ayrıntısından ve Borçlular listesinden gönderilir';

  @override
  String? get ozelMetin => hatirlatmaSablonuOzelMi(_kayitli) ? _kayitli : null;

  @override
  String get varsayilan => varsayilanHatirlatmaSablonu;

  @override
  List<HatirlatmaYerTutucu> get yerTutucular => hatirlatmaYerTutuculari;

  /// BOŞ ya da DEĞİŞMEMİŞ METİN null YAZILIR: "varsayılana dön" bunu demektir ve varsayılan ileride
  /// iyileşirse, şablona hiç dokunmamış bayi o iyileşmeyi alır.
  @override
  Future<void> kaydet(TenantSettingsRepository repo, {required String ad, required String metin}) {
    final temiz = metin.trim();
    return repo.save(
      reminderTemplate: Value(temiz.isEmpty || temiz == varsayilan ? null : temiz),
    );
  }
}

class _SistemKaydi extends MesajKaydi {
  const _SistemKaydi(this._tur, this._sablonlar);

  final MesajTuru _tur;
  final MesajSablonlari _sablonlar;

  @override
  String get baslik => _tur.baslik;

  @override
  String get aciklama => _tur.aciklama;

  @override
  String? get ozelMetin => _sablonlar.ozelMetin(_tur);

  @override
  String get varsayilan => _tur.varsayilan;

  @override
  Future<void> kaydet(TenantSettingsRepository repo, {required String ad, required String metin}) =>
      repo.mesajSablonlariGuncelle((m) => m.sistemIle(_tur, metin));
}

class _OzelKaydi extends MesajKaydi {
  const _OzelKaydi(this._sablonlar, [this._mesaj]);

  final MesajSablonlari _sablonlar;

  /// null = yeni mesaj.
  final OzelMesaj? _mesaj;

  @override
  String get baslik => _mesaj?.baslik ?? 'Yeni Mesaj';

  @override
  String get aciklama => 'Her siparişin ayrıntısında görünür';

  @override
  String? get ozelMetin => _mesaj?.metin;

  @override
  bool get adDuzenlenir => true;

  @override
  bool get silinebilir => _mesaj != null;

  @override
  String? adHatasi(String ad) => _sablonlar.adHatasi(ad, id: _mesaj?.id);

  @override
  String? metinHatasi(String metin) =>
      metin.trim().isEmpty ? 'Mesaj metnini yazın' : super.metinHatasi(metin);

  @override
  Future<void> kaydet(TenantSettingsRepository repo, {required String ad, required String metin}) {
    final kayit = OzelMesaj(id: _mesaj?.id ?? newId(), baslik: ad.trim(), metin: metin.trim());
    return repo.mesajSablonlariGuncelle((m) => m.ozelIle(kayit));
  }

  @override
  Future<void> sil(TenantSettingsRepository repo) =>
      repo.mesajSablonlariGuncelle((m) => m.ozelHaric(_mesaj!.id));
}

class MesajSablonlariEkrani extends StatefulWidget {
  const MesajSablonlariEkrani({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  @override
  State<MesajSablonlariEkrani> createState() => _MesajSablonlariEkraniState();
}

class _MesajSablonlariEkraniState extends State<MesajSablonlariEkrani> {
  late final _repo = TenantSettingsRepository(widget.db);

  // AKIŞ, tek atış değil: düzenleme sayfasından dönünce liste yeni durumu göstermeli.
  late final Stream<TenantSetting?> _veri = _repo.watch();

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
              child: StreamBuilder<TenantSetting?>(
                stream: _veri,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
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

  void _ac(BuildContext context, MesajKaydi kayit) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SablonDuzenleEkrani(kayit: kayit, repo: repo, writable: writable),
        ),
      );

  Widget _hazirSatir(BuildContext context, MesajKaydi k) => AyarSatiri(
        ikon: SipIcons.chat,
        baslik: k.baslik,
        // ÖZEL Mİ VARSAYILAN MI listeden görünmeli: "ben bunu değiştirmiş miydim?"
        altBaslik: k.ozelMetin == null ? 'Varsayılan metin' : 'Özel metin',
        onTap: () => _ac(context, k),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final sablonlar = MesajSablonlari.coz(satir?.messageTemplatesJson);
    return SipGovde(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.xl),
          child: Text(
            'Müşterilerinize gönderilen hazır metinler. Sipariş ayrıntısındaki Bilgilendirme '
            'Mesajı düğmesinden seçilirler ve gönderim anında gerçek bilgiyle dolarlar. Kalın, '
            'italik gibi WhatsApp biçimlerini metin kutusunun üstündeki düğmelerle ekleyin.',
            style: SipText.metin(12.5, w: 500, h: 1.5).copyWith(color: t.ink2),
          ),
        ),
        const SipBolumBaslik('Hazır Mesajlar', ustBosluk: 18),
        AyarKarti(satirlar: [
          for (final tur in kMesajTurleri) _hazirSatir(context, _SistemKaydi(tur, sablonlar)),
          _hazirSatir(context, _BorcKaydi(satir?.reminderTemplate)),
        ]),
        const SipBolumBaslik('Kendi Mesajlarınız', ustBosluk: 18),
        if (sablonlar.ozel.isNotEmpty)
          AyarKarti(satirlar: [
            for (final o in sablonlar.ozel)
              AyarSatiri(
                ikon: SipIcons.chat,
                baslik: o.baslik,
                onTap: () => _ac(context, _OzelKaydi(sablonlar, o)),
              ),
          ])
        else
          Text(
            'Kampanya ya da duyuru gibi metinleri buradan ekleyin',
            style: SipText.metin(12.5, w: 500, h: 1.5).copyWith(color: t.muted),
          ),
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.xl),
          child: SipButon(
            etiket: 'Yeni Mesaj Ekle',
            tur: SipButonTuru.ikincil,
            onTap: () {
              if (!sablonlar.yeniEklenebilir) {
                SipToast.goster(context, 'En çok ${MesajSablonlari.azamiOzel} mesaj eklenebilir');
                return;
              }
              _ac(context, _OzelKaydi(sablonlar));
            },
          ),
        ),
      ],
    );
  }
}

/// Tek bir mesajın düzenleme sayfası.
class SablonDuzenleEkrani extends StatefulWidget {
  const SablonDuzenleEkrani({
    super.key,
    required this.kayit,
    required this.repo,
    required this.writable,
  });

  final MesajKaydi kayit;
  final TenantSettingsRepository repo;
  final bool writable;

  @override
  State<SablonDuzenleEkrani> createState() => _SablonDuzenleEkraniState();
}

class _SablonDuzenleEkraniState extends State<SablonDuzenleEkrani> {
  late final _metin = TextEditingController(text: widget.kayit.baslangic);
  late final _ad = TextEditingController(
    text: widget.kayit.silinebilir ? widget.kayit.baslik : '',
  );
  String? _adHata;
  String? _hata;
  bool _kaydediyor = false;

  MesajKaydi get _kayit => widget.kayit;

  @override
  void dispose() {
    _metin.dispose();
    _ad.dispose();
    super.dispose();
  }

  bool _yazilabilir() {
    if (widget.writable) return true;
    SipToast.goster(context, profilSaltOkunurUyarisi);
    return false;
  }

  Future<void> _kaydet() async {
    if (_kaydediyor || !_yazilabilir()) return;
    final adHata = _kayit.adHatasi(_ad.text);
    final hata = _kayit.metinHatasi(_metin.text);
    if (adHata != null || hata != null) {
      setState(() {
        _adHata = adHata;
        _hata = hata;
      });
      return;
    }

    setState(() => _kaydediyor = true);
    await _kayit.kaydet(widget.repo, ad: _ad.text, metin: _metin.text);
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    SipToast.goster(context, 'Mesaj kaydedildi');
    Navigator.of(context).maybePop();
  }

  Future<void> _sil() async {
    if (!_yazilabilir()) return;
    final onay = await sipOnay(
      context,
      baslik: 'Mesaj silinsin mi?',
      mesaj: '${_kayit.baslik} sipariş ekranından da kalkar.',
      onayEtiketi: 'Sil',
      tehlike: true,
    );
    if (!onay || !mounted) return;
    await _kayit.sil(widget.repo);
    if (!mounted) return;
    SipToast.goster(context, 'Mesaj silindi');
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
            SipUst(baslik: _kayit.baslik, onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SipGovde(children: [
                Padding(
                  padding: const EdgeInsets.only(top: SipSpace.xl, bottom: SipSpace.md),
                  child: AlanNotu(_kayit.aciklama, tur: AlanNotuTuru.bilgi),
                ),
                if (_kayit.adDuzenlenir) ...[
                  const SipBolumBaslik('Mesaj Adı', ustBosluk: 8),
                  SipInput(
                    controller: _ad,
                    ipucu: 'Sipariş ekranındaki düğmede yazar',
                    hata: _adHata != null,
                    onChanged: (_) {
                      if (_adHata != null) setState(() => _adHata = null);
                    },
                  ),
                  if (_adHata != null) AlanNotu(_adHata!),
                ],
                HatirlatmaSablonuAlani(
                  controller: _metin,
                  baslik: 'Mesaj Metni',
                  yerTutucular: _kayit.yerTutucular,
                  varsayilanMetin: _kayit.varsayilan,
                  ipucu: _kayit.varsayilan == null
                      ? 'Müşteriye gidecek metni yazın'
                      : 'Boş bırakılırsa varsayılan mesaj gönderilir',
                  satirlar: 12,
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
                if (_kayit.silinebilir)
                  Padding(
                    padding: const EdgeInsets.only(top: SipSpace.md),
                    child: SipButon(
                      etiket: 'Mesajı Sil',
                      tur: SipButonTuru.ikincil,
                      onTap: _sil,
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
