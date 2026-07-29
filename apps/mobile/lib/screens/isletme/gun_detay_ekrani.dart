// GÜN DETAYI — geçmiş bir güne dokununca açılan tam sayfa (kullanıcı isteği 2026-07-29).
//
// Bölümler: kasa özeti · kurye kırılımı · satılan ürünler · kapanış kayıtları.
//
// NEDEN AYRI EKRAN (sheet değil): içerik dört bölüm ve kaydırma gerektiriyor; ayrıca "daha
// sonraki sürümlerde detaylı istatistik arayüzü" bu sayfanın üstüne oturacak (kullanıcı notu).
// Bir sheet'i büyütmek yerine sayfayı baştan sayfa yapmak, o genişlemeyi ucuzlatır.
//
// SALT OKUNUR: bu ekran hiçbir kayıt YAZMAZ. Geçmiş bir günün rakamlarını düzeltmenin yolu
// defterdir (düzeltme kaydı), arşivi elle değiştirmek değil — kırmızı çizgi #2.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../sync/yenileme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_arsivi.dart';
import 'gun_kapatma_sheet.dart' show arsivDetaySheet;
import 'gun_sonu_kartlari.dart';
import 'isletme_atomlari.dart';

class GunDetayEkrani extends StatefulWidget {
  const GunDetayEkrani({super.key, required this.db, required this.gun});

  final AppDatabase db;
  final DateTime gun;

  @override
  State<GunDetayEkrani> createState() => _GunDetayEkraniState();
}

class _GunDetayEkraniState extends State<GunDetayEkrani> {
  late Future<GunDetayi> _detay = gunDetayi(widget.db, widget.gun);

  /// Geçmiş bir gün de tazelenebilir olmalı: kuryenin telefonundaki teslimat ya da düzeltme
  /// kaydı senkronla sonradan gelebilir ve o gün "kapanmış" olsa bile RAKAMI değişir.
  Future<void> _yenile() async {
    await yenile();
    if (mounted) setState(() => _detay = gunDetayi(widget.db, widget.gun));
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
              baslik: gunBasligi(widget.gun),
              alt: gunTamBasligi(widget.gun),
              onGeri: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: FutureBuilder<GunDetayi>(
                future: _detay,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return SipHataEkran(onTekrar: () => setState(() {}));
                  }
                  final d = snap.data;
                  if (d == null) return const SipIskelet(adet: 4);
                  return _Govde(detay: d, onYenile: _yenile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.detay, required this.onYenile});

  final GunDetayi detay;
  final Future<void> Function() onYenile;

  @override
  Widget build(BuildContext context) {
    final d = detay;
    return SipGovde(
      onYenile: onYenile,
      children: [
        const SipBolumBaslik('Kasa Özeti', ustBosluk: 18),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Nakit', deger: sipTutar(d.kasa.nakit)),
            DegerSatiri(etiket: 'Kart', deger: sipTutar(d.kasa.kart)),
            DegerSatiri(etiket: 'Havale', deger: sipTutar(d.kasa.havale)),
            DegerSatiri(
              etiket: 'Toplam Tahsilat · ${d.teslimat} teslimat',
              deger: sipTutar(d.kasa.toplam),
              toplam: true,
            ),
          ],
        ),

        // Tek kişilik bayide bölüm HİÇ çizilmez (BRIEF: kurye adımları görünmemeli).
        if (d.kuryeler.isNotEmpty) ...[
          const SipBolumBaslik('Kuryeler', ustBosluk: 18),
          for (var i = 0; i < d.kuryeler.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: _KuryeKarti(kurye: d.kuryeler[i]),
            ),
        ],

        const SipBolumBaslik('Satılan Ürünler', ustBosluk: 18),
        if (d.urunler.isEmpty)
          const _BosNot('Bu gün teslim edilmiş sipariş yok.')
        else
          DegerKarti(
            satirlar: [
              for (final u in d.urunler)
                DegerSatiri(etiket: '${u.ad} ×${u.adet}', deger: sipTutar(u.tutar)),
              DegerSatiri(
                etiket: 'Toplam · ${d.satilanAdet} adet',
                deger: sipTutar(d.urunTutari),
                toplam: true,
              ),
            ],
          ),

        if (d.kapanislar.isNotEmpty) ...[
          const SipBolumBaslik('Kapanış Kayıtları', ustBosluk: 18),
          for (var i = 0; i < d.kapanislar.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: ArsivSatiri(
                kapanis: d.kapanislar[i],
                kapsamAdi: d.kapanislar[i].userId == null ? 'Gün hesabı' : 'Kurye devri',
                onTap: () => arsivDetaySheet(
                  context,
                  d.kapanislar[i],
                  kapsamAdi: d.kapanislar[i].userId == null ? 'Gün hesabı' : 'Kurye devri',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Kurye kartı — kullanıcı kararı: kartlar TAM AÇIK durur, ekstra dokunuş yok.
class _KuryeKarti extends StatelessWidget {
  const _KuryeKarti({required this.kurye});

  final KuryeGunu kurye;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final k = kurye;
    final fark = k.farkKurus;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.fromLTRB(SipSpace.x2, 12, SipSpace.x2, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SipIkonKutu(
                ikon: SipIcons.truck,
                cap: 30,
                ikonBoyut: 15,
                zemin: t.surface2,
                renk: t.ink2,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(k.ad,
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(sipTutar(k.kasa.toplam),
                  style: SipText.metin(14, w: 800).copyWith(color: t.ink)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Nakit ${sipTutar(k.kasa.nakit)} · Kart ${sipTutar(k.kasa.kart)} · '
            'Havale ${sipTutar(k.kasa.havale)}',
            style: SipText.yardimci.copyWith(color: t.muted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text('${k.teslimat} teslimat',
                    style: SipText.yardimci.copyWith(color: t.muted)),
              ),
              // Fark YALNIZ sayım yapıldıysa yazılır. Sayılmamış bir kasaya "fark 0" demek,
              // mutabakat yapılmış gibi göstermek olurdu (kırmızı çizgi: eksik para görünür kalır).
              if (fark != null)
                Text(
                  fark == 0 ? 'kasa tuttu' : 'fark ${sipTutar(fark)}',
                  style: SipText.yardimci
                      .copyWith(color: fark == 0 ? t.ok : t.danger),
                )
              else
                Text('devir yok', style: SipText.yardimci.copyWith(color: t.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BosNot extends StatelessWidget {
  const _BosNot(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 14),
      child: Text(metin, style: SipText.yardimci.copyWith(color: t.muted)),
    );
  }
}
