// Ayarlar ekranındaki "Bildirimler" bölümü.
//
// AYRI DOSYA: `ayarlar_ekrani.dart` bu vardiyada yalnız bildirim bölümü için açıldı; bölümü
// kendi dosyasında tutmak o ekrana tek satır (bir widget çağrısı) dokunmayı yeterli kılıyor
// ve 500 satır sınırını da rahatlatıyor.
//
// İZİN REDDEDİLDİYSE GİZLENMEZ, SÖYLENİR (bu deponun yerleşik kuralı): bayi bildirimleri
// açtığını sanıp hiç bildirim almamalı. Durum satırı sebebini yazar ve tek dokunuşla sistem
// iznini yeniden ister.
//
// ── `flutter analyze` TEMİZ OLMASI ÇALIŞTIĞI ANLAMINA GELMEZ (2026-07-27 dersi) ────────────
// Bu bölüm ayarlar ekranına eklendiğinde analiz temizdi ama `ui_isletme_ayarlar_test.dart`in
// TAMAMI düştü: widget kurulurken gerçek bildirim servisi çağrılıyor, o da platform eklentisini
// çözmeye çalışıp `LateInitializationError` atıyordu (test ortamında eklenti kaydı yok).
// Statik analiz bunu göremez — çalışma zamanı davranışıdır. Ekrana gömülü her widget, platform
// eklentisine uzanıyorsa testte ÇÖKMEDEN pasifleşmek zorundadır; kapı
// `YerelBildirimServisi._android()` içinde (bkz. oradaki gerekçe). Aynı disiplin
// `tutamac_deposu` / `tema_deposu` desenlerinde de var: platform yoksa varsayılana düş.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../screens/isletme/atomlar/kart_atomlari.dart';
import '../theme/components/bicim.dart';
import '../theme/components/dokunma.dart';
import '../theme/components/form.dart';
import '../theme/components/overlays.dart';
import '../theme/components/yerlesim.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'bildirim_ayarlari.dart';
import 'bildirim_servisi.dart';
import 'bildirim_sozlesmesi.dart';

/// Ayarlar ekranına gömülen bölüm: başlık + izin durumu + kategori anahtarları.
class BildirimAyarBolumu extends StatefulWidget {
  const BildirimAyarBolumu({super.key, this.servis, this.ayarlar});

  /// Test/araç yolu — verilmezse uygulamanın gerçek servisi ve deposu kullanılır.
  final BildirimServisi? servis;
  final BildirimAyarlari? ayarlar;

  @override
  State<BildirimAyarBolumu> createState() => _BildirimAyarBolumuState();
}

class _BildirimAyarBolumuState extends State<BildirimAyarBolumu> {
  BildirimServisi get _servis => widget.servis ?? bildirimServisi;
  BildirimAyarlari get _ayarlar => widget.ayarlar ?? bildirimAyarlari;

  bool _izinVar = true;
  bool _yuklendi = false;
  final Map<BildirimKategori, bool> _acik = {};

  @override
  void initState() {
    super.initState();
    _tazele();
  }

  Future<void> _tazele() async {
    await _ayarlar.yukle();
    final izin = await _servis.izinDurumu();
    if (!mounted) return;
    setState(() {
      _izinVar = izin;
      for (final k in BildirimKategori.values) {
        _acik[k] = _ayarlar.kategoriAcik(k);
      }
      _yuklendi = true;
    });
  }

  Future<void> _izinIste() async {
    final verildi = await _servis.izinIste();
    if (!mounted) return;
    setState(() => _izinVar = verildi);
    if (!verildi) {
      SipToast.goster(
        context,
        'Bildirim izni verilmedi. Telefonun Ayarlar → Uygulamalar bölümünden açabilirsiniz.',
      );
    }
  }

  Future<void> _kategoriCevir(BildirimKategori k) async {
    final yeni = !(_acik[k] ?? true);
    setState(() => _acik[k] = yeni);
    await _ayarlar.kategoriYaz(k, yeni);
    // Kapatılan kategorinin BEKLEYEN zamanlanmışları da susmalı; aksi hâlde bayi anahtarı
    // kapattıktan sonra akşam yine bildirim alır ve ayara güveni biter.
    if (!yeni) await _servis.iptal(bildirimKimligi(k, bildirimGunAnahtari(DateTime.now())));
  }

  bool get _esikVar => _ayarlar.borcEsigiBelirlendi;

  /// Eşiği LİRA olarak sorar, kuruşa çevirip yazar. Kuruş girdirmiyoruz: esnaf eşiği "iki bin
  /// lira" diye düşünür; kuruş alanı hem yanlış girişe hem 100 kat hataya açık.
  /// Boş bırakmak eşiği SİLER ve kategoriyi pasife alır — kapatmak için ayrı bir anahtar yok.
  Future<void> _esikSor() async {
    final girilen = await sipSheet<String>(
      context,
      baslik: 'Borç eşiği',
      govde: (ctx) => _EsikGovde(
        baslangicLira: _esikVar ? (_ayarlar.borcEsigiKurus ~/ 100).toString() : '',
      ),
    );
    if (girilen == null || !mounted) return;

    final lira = int.tryParse(girilen.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    await _ayarlar.borcEsigiYaz(lira * 100);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (!_yuklendi) {
      // Kısa bir okuma; iskelet göstermek yerine bölümü hiç çizmiyoruz (ayar ekranı zaten
      // akış içinde kuruluyor ve yarım çizilmiş anahtar yanıltıcı olurdu).
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipBolumBaslik('Bildirimler', ustBosluk: 18),
        AyarKarti(satirlar: [
          if (!_izinVar)
            AyarSatiri(
              ikon: SipIcons.info,
              baslik: 'Bildirim izni kapalı',
              altBaslik: 'İzin verilmeden hiçbir bildirim gösterilemez',
              sag: SipMetinButon(
                etiket: 'İzin ver',
                zemin: t.accentSoft,
                renk: t.accent,
                onTap: _izinIste,
              ),
            ),
          // Sessiz saatler Faz 1'de SABİT ve yalnız bilgilendirme satırı: bayi gece bildirim
          // gelmediğini bir yerde okuyabilmeli, yoksa "bildirimler çalışmıyor" diye döner.
          AyarSatiri(
            ikon: SipIcons.moon,
            baslik: 'Sessiz saatler',
            altBaslik: _sessizMetin(_ayarlar.sessizSaatler),
          ),
          for (final k in BildirimKategori.values)
            if (k == BildirimKategori.borcEsigi)
              // BORÇ EŞİĞİ ÖZEL: eşik girilmeden kategori PASİF (lead kararı). Anahtar yerine
              // eşik alanı gösterilir — bayiye "kapalı" demek yetmez, NEDEN kapalı olduğunu ve
              // ne yapması gerektiğini söylemek gerekir.
              AyarSatiri(
                ikon: _ikon(k),
                baslik: k.ad,
                altBaslik: _esikVar
                    ? 'Borç ${sipTutar(_ayarlar.borcEsigiKurus)} tutarını aşınca haber ver'
                    : 'Pasif — bir eşik belirleyin',
                onTap: _esikSor,
                sag: SipMetinButon(
                  etiket: _esikVar ? sipTutar(_ayarlar.borcEsigiKurus) : 'Eşik belirle',
                  zemin: _esikVar ? t.surface2 : t.accentSoft,
                  renk: _esikVar ? t.ink : t.accent,
                  onTap: _esikSor,
                ),
              )
            else
              AyarSatiri(
                ikon: _ikon(k),
                baslik: k.ad,
                altBaslik: k.aciklama,
                onTap: () => _kategoriCevir(k),
                sag: SipKnob(acik: _acik[k] ?? true),
              ),
        ]),
      ],
    );
  }

  static String _sessizMetin(SessizSaatler s) {
    if (s.kapali) return 'Kapalı — her saat bildirim gelebilir';
    String iki(int x) => x.toString().padLeft(2, '0');
    return '${iki(s.baslangicSaat)}:00 – ${iki(s.bitisSaat)}:00 arası bildirim gelmez, sabaha ertelenir';
  }

  static String _ikon(BildirimKategori k) => switch (k) {
        BildirimKategori.gunSonuOzeti => SipIcons.book,
        BildirimKategori.borcEsigi => SipIcons.info,
        BildirimKategori.vadesiGecenBorc => SipIcons.clock,
        BildirimKategori.musteriGecikti => SipIcons.user,
        BildirimKategori.rutinTeslimGunu => SipIcons.box,
        BildirimKategori.sistem => SipIcons.settings,
      };
}

/// Borç eşiği sheet'inin gövdesi. Kaydet, girilen LİRA metnini döndürür; boş metin eşiği
/// siler (kategori pasife döner).
class _EsikGovde extends StatefulWidget {
  const _EsikGovde({required this.baslangicLira});

  final String baslangicLira;

  @override
  State<_EsikGovde> createState() => _EsikGovdeState();
}

class _EsikGovdeState extends State<_EsikGovde> {
  late final TextEditingController _c =
      TextEditingController(text: widget.baslangicLira);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bir müşterinin borcu bu tutarı aştığında haber verilir. '
          'Her bayinin cirosu farklı olduğu için hazır bir değer önerilmiyor.',
          style: SipText.yardimci.copyWith(color: t.muted),
        ),
        const SipFormEtiket('EŞİK (₺)', ustBosluk: 2),
        SipInput(
          controller: _c,
          ipucu: '0',
          klavye: TextInputType.number,
          girdiFiltreleri: [FilteringTextInputFormatter.digitsOnly],
          stil: SipText.tutar(22),
          yukseklik: 56,
          otomatikOdak: true,
        ),
        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Kaydet',
          yukseklik: 50,
          onTap: () => Navigator.of(context).pop(_c.text.trim()),
        ),
        const SizedBox(height: SipSpace.md),
        SipMetinButon(
          etiket: 'Eşiği sil (bildirimi kapat)',
          zemin: t.surface2,
          renk: t.ink2,
          onTap: () => Navigator.of(context).pop(''),
        ),
      ],
    );
  }
}
