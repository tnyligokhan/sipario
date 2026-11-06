// GİDER KATEGORİLERİ ekranı (saha, 2026-11-05: "Gider kategorilerini uygulama içinden ekleyebilme").
//
// Liste `tenant_settings.expense_categories`te durur ve bayinin bütün cihazlarına iner. Kategori bir
// etikettir: gider sheet'inde dokunuşla açıklamayı doldurur (bkz. `data/gider_kategorileri.dart`).
// Listeden silmek eski giderleri değiştirmez, bu yüzden silme tombstone istemez.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/gider_kategorileri.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_parts.dart' show YsEkleDugmesi;
import 'isletme_atomlari.dart';

const String giderKategoriSaltOkunurUyarisi =
    'Aboneliğiniz sona erdiği için liste değiştirilemiyor';

class GiderKategorileriEkrani extends StatelessWidget {
  const GiderKategorileriEkrani({
    super.key,
    required this.db,
    required this.writable,
    required this.rol,
  });

  final AppDatabase db;

  /// Abonelik salt-okunur kipinde false; liste okunur, değiştirilemez.
  final bool writable;

  /// Oturumdaki rol; kurye bu ekranı göremez (K2).
  final String? rol;

  TenantSettingsRepository get _repo => TenantSettingsRepository(db);

  Future<void> _ekle(BuildContext context, GiderKategorileri mevcut) async {
    if (!writable) {
      SipToast.goster(context, giderKategoriSaltOkunurUyarisi);
      return;
    }
    final ad = await sipSheet<String>(
      context,
      baslik: 'Yeni Kategori',
      govde: (ctx) => _EklemeGovdesi(mevcut: mevcut),
    );
    if (ad == null || !context.mounted) return;
    await _repo.giderKategorileriKaydet(mevcut.ile(ad));
    if (context.mounted) SipToast.goster(context, 'Kategori eklendi');
  }

  Future<void> _sil(BuildContext context, GiderKategorileri mevcut, String ad) async {
    if (!writable) {
      SipToast.goster(context, giderKategoriSaltOkunurUyarisi);
      return;
    }
    if (!mevcut.silinebilir) {
      SipToast.goster(context, 'Listede en az bir kategori kalmalı');
      return;
    }
    final onay = await sipOnay(
      context,
      baslik: 'Kategori silinsin mi?',
      mesaj: '"$ad" listeden kalkacak, eski giderler değişmez',
      onayEtiketi: 'Sil',
      tehlike: true,
    );
    if (!onay || !context.mounted) return;
    await _repo.giderKategorileriKaydet(mevcut.haric(ad));
    if (context.mounted) SipToast.goster(context, 'Kategori silindi');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return YoneticiKapisi(
      rol: rol,
      baslik: 'Gider Kategorileri',
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<GiderKategorileri>(
            stream: _repo.watchGiderKategorileri(),
            builder: (context, snap) {
              final kategoriler = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SipUst(
                    baslik: 'Gider Kategorileri',
                    alt: 'Gider eklerken tek dokunuşla seçilir',
                    onGeri: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: SipGovde(
                      children: kategoriler == null
                          ? const [SipIskelet(adet: 3)]
                          : [
                              for (final ad in kategoriler.adlar)
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: _Satir(
                                    ad: ad,
                                    onSil: () => _sil(context, kategoriler, ad),
                                  ),
                                ),
                              const SizedBox(height: SipSpace.md),
                              YsEkleDugmesi(
                                etiket: 'Kategori ekle',
                                ikon: SipIcons.plus,
                                onTap: () => _ekle(context, kategoriler),
                              ),
                            ],
                    ),
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

class _Satir extends StatelessWidget {
  const _Satir({required this.ad, required this.onSil});

  final String ad;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.fromLTRB(SipSpace.x2, 6, 6, 6),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ad,
              style: SipText.metin(13.5, w: 600).copyWith(color: t.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SipIkonButon(
            ikon: SipIcons.trash,
            ikonBoyut: 16,
            renk: t.muted,
            etiket: '$ad kategorisini sil',
            onTap: onSil,
          ),
        ],
      ),
    );
  }
}

class _EklemeGovdesi extends StatefulWidget {
  const _EklemeGovdesi({required this.mevcut});

  final GiderKategorileri mevcut;

  @override
  State<_EklemeGovdesi> createState() => _EklemeGovdesiState();
}

class _EklemeGovdesiState extends State<_EklemeGovdesi> {
  final _ad = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  void _kaydet() {
    final hata = widget.mevcut.eklemeHatasi(_ad.text);
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    Navigator.of(context).pop(_ad.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('KATEGORİ ADI', ustBosluk: 2),
        SipInput(
          controller: _ad,
          ipucu: 'Ör. Kömür, Kira',
          otomatikOdak: true,
          hata: _hata != null,
          onChanged: (_) {
            if (_hata != null) setState(() => _hata = null);
          },
        ),
        if (_hata != null) AlanNotu(_hata!),
        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Kategoriyi Ekle', onTap: _kaydet),
      ],
    );
  }
}
