// GİDER EKLEME alt sayfası (kullanıcı isteği 2026-08-25) — kasadan çıkan nakdin kaydı.
//
// NEDEN GÜN ÖZETİNDE: gider, akşam sayılan parayla sistemin beklediği para arasındaki farkın
// adıdır. Ayrı bir "Giderler" ekranına konsaydı bayi onu ancak fark çıktıktan SONRA arar, oysa
// para çekmeceden çıkarken yazılmalı. Kaydın doğduğu yer ile okunduğu yer aynı ekrandır.
//
// NEDEN TUTAR + AÇIKLAMA, DAHA FAZLASI DEĞİL: bu bir kâr-zarar defteri değil, bir KASA
// düzeltmesidir. Kategori kolonu, KDV, fiş görseli ve aylık gider raporu ayrı bir üründür ve
// hiçbiri "akşam kasa tutmuyor" sorununu çözmez. Sık kullanılan başlıklar hazır dokunuşlar
// olarak duruyor ama yazdıkları şey yine serbest açıklamadır — şemaya bir alan eklemeden, ve
// bayinin kendi kelimesini kullanmasına engel olmadan.
//
// TUTAR ZORUNLU, AÇIKLAMA DEĞİL: "200 ₺ çıktı" kasa için tamamlanmış bir bilgidir; ne olduğunu
// yazmayan bayiyi kaydı hiç girmemeye itmek, kasayı açıklanamaz bırakmaktan kötüdür.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_kapatma_sheet.dart' show kurusaCevir;
import 'isletme_atomlari.dart';

/// Gider sheet'inin sonucu: tutar (kuruş, POZİTİF) + açıklama.
@immutable
class GiderSonucu {
  const GiderSonucu({required this.kurus, required this.aciklama});

  final int kurus;
  final String aciklama;
}

/// Sık kullanılan gider başlıkları — dokunuş açıklama alanını DOLDURUR, kilitlemez.
///
/// Sabit bir kategori LİSTESİ değildir ve olmamalı: her bayinin gideri kendine benzer (su
/// bayiinde "damacana tamiri", dönercide "kömür") ve kapalı bir liste, listede olmayan gideri
/// "Diğer"e sürerdi — yani en çok açıklama gereken kayıt en az açıklamalı olurdu.
const List<String> kGiderKisayollari = [
  'Yakıt',
  'Tamir',
  'Yemek',
  'Nakliye',
  'Personel avansı',
];

/// Kasadan nakit çıkışı kaydeder. [kapsamAdi] parayı kimin kasasından çıktığını söyler
/// (gün hesabında "Kasa", kişi kapsamında o kişinin adı) — kayıt o kişiye yazılacağı için
/// bayi bunu ONAYLAMADAN önce görmeli.
Future<GiderSonucu?> giderSheet(
  BuildContext context, {
  required String kapsamAdi,
  required int mevcutNakit,
}) {
  return sipSheet<GiderSonucu>(
    context,
    baslik: 'Gider Ekle',
    govde: (ctx) => _GiderGovdesi(kapsamAdi: kapsamAdi, mevcutNakit: mevcutNakit),
  );
}

/// GİDER İPTALİ ONAYI — `true` dönerse iptal edilir.
///
/// Ara tahsilat iptaliyle AYNI gerekçe: satır kaydırılan bir listenin ortasında duruyor ve
/// kazara dokunuş kalıcı bir düzeltme kaydı yazardı (append-only: iptalin iptali yoktur, yeni
/// bir gider girmek gerekir).
Future<bool> giderIptalOnayi(
  BuildContext context, {
  required int tutarKurus,
  String? aciklama,
}) {
  final ne = (aciklama ?? '').trim();
  return sipOnay(
    context,
    baslik: 'Gider iptal edilsin mi?',
    mesaj: ne.isEmpty
        ? '${sipTutar(tutarKurus)} tutarındaki gider geri alınacak; bu para yine kasada sayılacak.'
        : '"$ne" için yazılan ${sipTutar(tutarKurus)} geri alınacak; bu para yine kasada sayılacak.',
    onayEtiketi: 'İptal Et',
    vazgecEtiketi: 'Vazgeç',
    tehlike: true,
  );
}

class _GiderGovdesi extends StatefulWidget {
  const _GiderGovdesi({required this.kapsamAdi, required this.mevcutNakit});

  final String kapsamAdi;

  /// Kapsamda ŞU AN görünen nakit — girilen tutarın anlık karşılaştırması için.
  final int mevcutNakit;

  @override
  State<_GiderGovdesi> createState() => _GiderGovdesiState();
}

class _GiderGovdesiState extends State<_GiderGovdesi> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  int? get _kurus {
    final s = _tutar.text.trim();
    if (s.isEmpty) return null;
    return kurusaCevir(s);
  }

  void _kisayol(String ad) {
    setState(() {
      _aciklama.text = ad;
      _aciklama.selection = TextSelection.collapsed(offset: ad.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kurus = _kurus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KAYDIN KİME YAZILACAĞI EN ÜSTTE. Gider `collected_by_user_id`ye düşer ve o alan
        // kuryenin cebindeki parayı ölçen bütün hesapların girdisidir: yanlış kişiye yazılan bir
        // gider, akşam BAŞKASININ kasasını eksik gösterir. Bayi bunu kaydetmeden önce okumalı.
        AlanNotu(
          '${widget.kapsamAdi} kasasından düşülecek',
          tur: AlanNotuTuru.bilgi,
        ),

        const SipFormEtiket('TUTAR (₺)', ustBosluk: 2),
        SipInput(
          controller: _tutar,
          ipucu: '0',
          klavye: const TextInputType.numberWithOptions(decimal: true),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
          stil: SipText.tutar(22),
          yukseklik: 56,
          otomatikOdak: true,
          onChanged: (_) => setState(() {}),
        ),

        // GİRİLEN TUTAR KASADAKİ NAKDİ AŞIYORSA SÖYLENİR ama ENGELLENMEZ: para gerçekten çıkmış
        // olabilir (kurye kendi cebinden ödeyip kasadan almış, ya da bir tahsilat henüz
        // senkronla inmemiş). Engellemek, olmuş bir olayı deftere yazdırmamak olurdu — BRIEF'in
        // "eksik para kanıt olarak görünür kalmalı" kuralının tersi.
        if (kurus != null && kurus > widget.mevcutNakit)
          const AlanNotu(
            'Bu tutar kasada görünen nakitten fazla; yine de kaydedilir',
            tur: AlanNotuTuru.uyari,
          ),

        const SipFormEtiket('Ne için? (isteğe bağlı)'),
        SipInput(
          controller: _aciklama,
          ipucu: 'Ör. benzin, lastik tamiri',
          onChanged: (_) => setState(() {}),
        ),

        Padding(
          padding: const EdgeInsets.only(top: SipSpace.md),
          child: Wrap(
            spacing: SipSpace.md,
            runSpacing: SipSpace.md,
            children: [
              for (final ad in kGiderKisayollari)
                _Kisayol(
                  etiket: ad,
                  secili: _aciklama.text.trim() == ad,
                  onTap: () => _kisayol(ad),
                ),
            ],
          ),
        ),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Gideri Kaydet',
          ikon: SipIcons.wallet,
          // Sıfır tutarlı bir gider hiçbir şey anlatmaz; boş girdi gibi ele alınır.
          onTap: kurus == null || kurus == 0
              ? null
              : () => Navigator.of(context).pop(
                    GiderSonucu(kurus: kurus, aciklama: _aciklama.text.trim()),
                  ),
        ),
      ],
    );
  }
}

/// Açıklama alanını dolduran tek dokunuşluk başlık.
class _Kisayol extends StatelessWidget {
  const _Kisayol({required this.etiket, required this.secili, required this.onTap});

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: secili ? t.accentSoft : t.surface2,
      basiliZemin: t.surface2,
      radius: SipRadius.brHap,
      kenarlik: Border.all(color: secili ? t.accent : t.line2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(
        etiket,
        style: SipText.metin(12.5, w: 700)
            .copyWith(color: secili ? t.accent : t.ink2),
      ),
    );
  }
}
