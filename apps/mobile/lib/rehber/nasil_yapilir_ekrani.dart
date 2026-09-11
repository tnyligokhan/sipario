// KATMAN C — "NASIL YAPILIR": aranabilir görev tarifleri.
//
// REHBERİN ATLANABİLİR OLMASININ BEDELİNİ BU EKRAN ÖDER. Tur bir kez izlenir ve unutulur;
// bayinin aylar sonra "veresiyeyi nasıl tahsil ediyordum" diye bakacağı kalıcı bir yer olmalı.
// Bu yüzden maddeler GÖREV bazlıdır, ekran bazlı değil: kullanıcı hangi ekranda olduğunu
// değil, ne yapmak istediğini bilir.
//
// ⚠️ İÇERİDE HİÇBİR EYLEM YOK, sadece anlatı. Tarifin sonuna "şimdi yap" düğmesi koymak cazip
// ama yanlış olurdu: yardım ekranından açılan bir akış, kullanıcıyı okuduğu yerin dışına
// atar ve geri döndüğünde nerede kaldığını bulamaz.
//
// ARAMA AKSANA BAKMAZ (`rehber_modeli.dart` sadeleştirmesi): klavyede "urun" yazan bayi
// "ürün" maddesini bulur. Eş anlamlılar `rehber_nasil.dart` içindeki etiketlerde.

import 'package:flutter/material.dart';

import '../theme/components/atoms.dart';
import '../theme/components/states.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'rehber_nasil.dart';
import 'rehber_modeli.dart';

class NasilYapilirEkrani extends StatefulWidget {
  const NasilYapilirEkrani({super.key, required this.kuryeMi});

  /// Kurye yalnız kendi yapabildiği işlerin tarifini görür. Yapamayacağı bir işi tarif etmek,
  /// olmayan bir yolu tarif etmektir (Ayarlar'daki "kalıcı olarak kapalı kapıyı gösterme"
  /// kuralının aynısı).
  final bool kuryeMi;

  @override
  State<NasilYapilirEkrani> createState() => _NasilYapilirEkraniState();
}

class _NasilYapilirEkraniState extends State<NasilYapilirEkrani> {
  final TextEditingController _arama = TextEditingController();

  /// Açık olan tarifin başlığı; aynı anda tek tarif açık kalır — liste uzun ve hepsi açıkken
  /// tarama imkânsızlaşıyor.
  String? _acik;

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final liste = nasilYapilirListesi(kuryeMi: widget.kuryeMi, arama: _arama.text);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(
              baslik: 'Yardım',
              alt: 'Nasıl yapılır',
              onGeri: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SipSpace.govde, SipSpace.md, SipSpace.govde, SipSpace.xl),
              child: SipArama(
                controller: _arama,
                ipucu: 'Ne yapmak istiyorsun',
                onChanged: (_) => setState(() {}),
                onTemizle: () => setState(() => _arama.clear()),
              ),
            ),
            Expanded(
              child: liste.isEmpty
                  ? _Bos(arama: _arama.text)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          SipSpace.govde, 0, SipSpace.govde, SipSpace.x6),
                      itemCount: liste.length,
                      itemBuilder: (context, i) {
                        final n = liste[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: SipSpace.lg),
                          child: _Tarif(
                            madde: n,
                            acik: _acik == n.baslik,
                            onDokun: () => setState(
                              () => _acik = _acik == n.baslik ? null : n.baslik,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek tarif — kapalıyken yalnız başlık, açıkken numaralı adımlar.
class _Tarif extends StatelessWidget {
  const _Tarif({required this.madde, required this.acik, required this.onDokun});

  final NasilYapilir madde;
  final bool acik;
  final VoidCallback onDokun;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipKart(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SipDokun(
            onTap: onDokun,
            radius: SipRadius.br2,
            padding: const EdgeInsets.symmetric(
                horizontal: SipSpace.x2, vertical: SipSpace.x2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    madde.baslik,
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  ),
                ),
                const SizedBox(width: SipSpace.md),
                SipIcon(
                  acik ? SipIcons.up : SipIcons.down,
                  boyut: 17,
                  kalinlik: 2.2,
                  renk: t.muted,
                ),
              ],
            ),
          ),
          if (acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SipSpace.x2, 0, SipSpace.x2, SipSpace.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < madde.adimlar.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SipSpace.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Numara ADIM SIRASINI anlatır: tarifler sırayla yapılır, madde
                          // işareti (nokta) bunu söylemez.
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${i + 1}',
                              style: SipText.metin(12.5, w: 700).copyWith(color: t.accent),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              madde.adimlar[i],
                              style: SipText.metin(13, h: 1.4).copyWith(color: t.ink2),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bos extends StatelessWidget {
  const _Bos({required this.arama});

  final String arama;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SipIcon(SipIcons.search, boyut: 30, kalinlik: 1.8, renk: t.muted),
            const SizedBox(height: SipSpace.x2),
            Text(
              '"$arama" için bir tarif yok',
              style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SipSpace.sm),
            Text(
              'Başka bir kelime dene ya da menüden destek satırını kullan',
              style: SipText.metin(12.5, h: 1.4).copyWith(color: t.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
