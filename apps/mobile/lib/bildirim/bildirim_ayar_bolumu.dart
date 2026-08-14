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
// ── ÜÇ AYRI KAPI VAR, BİRİ DİĞERİNİ KANITLAMAZ (2026-07-27 dersi) ──────────────────────────
// `flutter analyze` temiz → derlendiği anlamına gelmez.
// `flutter test` yeşil → APK'nın derlendiği anlamına gelmez: bildirim paketi eklendiğinde 622
// test geçiyordu ama release derlemesi `checkReleaseAarMetadata`da düşüyordu (core library
// desugaring kapalıydı, bkz. `android/app/build.gradle.kts`). Yani Faz 1 "bitti" görünürken
// telefona kurulacak APK yoktu. Bildirim/native tarafına dokunan her değişiklikten sonra
// `flutter build apk --release` de koşulmalı.
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

import '../screens/isletme/atomlar/form_atomlari.dart';
import '../screens/isletme/atomlar/kart_atomlari.dart';
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
  const BildirimAyarBolumu({
    super.key,
    this.servis,
    this.ayarlar,
    this.yoneticiMi = true,
  });

  /// Test/araç yolu — verilmezse uygulamanın gerçek servisi ve deposu kullanılır.
  final BildirimServisi? servis;
  final BildirimAyarlari? ayarlar;

  /// Oturumdaki kullanıcı yönetici mi (patron/operatör)?
  ///
  /// Kuryede `BildirimKategori.yalnizYonetici` kategorileri HİÇ GÖSTERİLMEZ: sunucu "teslim
  /// edildi" ve "kasa devri" dürtülerini yalnız yöneticilere gönderir, yani kuryede o anahtar
  /// kapatılınca da açılınca da hiçbir şey değişmezdi. Çalışmayan bir anahtar, ayarların
  /// tamamına olan güveni bozar.
  final bool yoneticiMi;

  @override
  State<BildirimAyarBolumu> createState() => _BildirimAyarBolumuState();
}

class _BildirimAyarBolumuState extends State<BildirimAyarBolumu> {
  BildirimServisi get _servis => widget.servis ?? bildirimServisi;
  BildirimAyarlari get _ayarlar => widget.ayarlar ?? bildirimAyarlari;

  PushDurumu? _pushDurumu;
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
      _pushDurumu = _ayarlar.pushDurumu;
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

  /// Sessiz saat aralığını sorar ve yazar. null dönerse (vazgeçildi) hiçbir şey değişmez.
  ///
  /// KAPATMA DA BİR SEÇENEKTİR ve `baslangic == bitis` ile ifade edilir — modelin kendi
  /// kuralı (`SessizSaatler.kapali`). Ayrı bir "açık mı" bayrağı EKLENMEDİ: aynı gerçeği iki
  /// alanda tutmak, ikisinin bir gün çelişmesi demektir (bu depoda ödenmiş bir ders).
  Future<void> _sessizSor() async {
    final secim = await sipSheet<SessizSaatler>(
      context,
      baslik: 'Sessiz saatler',
      govde: (ctx) => _SessizGovde(baslangic: _ayarlar.sessizSaatler),
    );
    if (secim == null || !mounted) return;
    await _ayarlar.sessizYaz(secim);
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
          // PUSH DURUMU — SAHA TEŞHİSİ (2026-08-14). "Bildirim gelmiyor" şikâyetinde
          // bakılacak İLK yer burasıdır: telefon sunucuya kaydolabilmiş mi?
          //
          // HAZIR OLDUĞUNDA GİZLENMEZ, SÖYLENİR: çalışan bir şeyin çalıştığını göstermek,
          // bayiye "burada bir özellik var" bilgisini de verir. Bu bölümün baştan beri
          // uyguladığı kuralın aynısı — izin reddedildiğinde de gizlemiyor, söylüyoruz.
          if (_pushDurumu != null)
            AyarSatiri(
              ikon: _pushDurumu == PushDurumu.hazir ? SipIcons.check : SipIcons.info,
              baslik: 'Anlık bildirimler',
              altBaslik: _pushDurumu!.aciklama,
            ),
          // SESSİZ SAATLER ARTIK DÜZENLENEBİLİR (2026-08-13). Faz 1'de SABİT ve yalnız
          // bilgilendirme satırıydı; `BildirimAyarlari.sessizYaz()` yazılmış, okunmuş ve
          // bildirim servisi tarafından UYGULANIYORDU ama onu çağıran TEK BİR EKRAN YOKTU —
          // yani ürün özelliği taşıyordu, kullanıcı ona hiç erişemiyordu. Kod hazırdı, kapı
          // yoktu. Su bayilerinin çalışma saatleri birbirinden çok farklı (sabah 6'da açan da
          // var, gece 1'e kadar teslimat yapan da); sabit 22-8 ikisinde de yanlış.
          AyarSatiri(
            ikon: SipIcons.moon,
            baslik: 'Sessiz saatler',
            altBaslik: _sessizMetin(_ayarlar.sessizSaatler),
            onTap: _sessizSor,
          ),
          // Kuryede yönetici kategorileri LİSTEYE HİÇ GİRMEZ (gerekçe: `yoneticiMi` yorumu).
          // Boş bir widget eklemek yerine atlanır: kart satırlarının arasına ayırıcı çiziyor,
          // görünmez bir satır görünür bir boşluk bırakırdı.
          for (final k in BildirimKategori.values)
            if (!k.yalnizYonetici || widget.yoneticiMi)
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
        BildirimKategori.gunKapanisHatirlatma => SipIcons.clock,
        BildirimKategori.kullanimHakki => SipIcons.info,
        BildirimKategori.sistem => SipIcons.settings,
        BildirimKategori.siparisAtandi => SipIcons.box,
        BildirimKategori.siparisIptal => SipIcons.alert,
        BildirimKategori.siparisTeslim => SipIcons.check,
        BildirimKategori.kasaDevri => SipIcons.wallet,
        BildirimKategori.yeniCihaz => SipIcons.user,
      };
}

/// Sessiz saat aralığı seçici (2026-08-13).
///
/// İKİ ŞERİT, TEK EKRAN: başlangıç ve bitiş saatleri yan yana kaydırılabilir hap listelerdir.
/// İki AŞAMALI bir akış (önce başlangıç sor, sonra bitiş sor) daha az kod olurdu ama kullanıcı
/// aralığı BİR BÜTÜN olarak düşünür — "22'den 8'e" tek bir karardır; ikiye bölmek, ikinci
/// adımda ilkini hatırlamayı gerektirirdi.
///
/// GECE YARISINI AŞAN ARALIK NORMALDİR (22 → 8) ve modelde zaten destekleniyor
/// (`SessizSaatler.icindeMi`); seçici bu yüzden "başlangıç bitişten küçük olmalı" gibi bir
/// kısıt DAYATMAZ. Dayatsaydı, en yaygın kullanım biçimini yasaklamış olurduk.
class _SessizGovde extends StatefulWidget {
  const _SessizGovde({required this.baslangic});

  final SessizSaatler baslangic;

  @override
  State<_SessizGovde> createState() => _SessizGovdeState();
}

class _SessizGovdeState extends State<_SessizGovde> {
  late int _bas = widget.baslangic.baslangicSaat;
  late int _bit = widget.baslangic.bitisSaat;

  static String _ss(int saat) => '${saat.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final kapali = _bas == _bit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bu aralıkta bildirim gösterilmez; sıradaki bildirim aralığın bitişine ertelenir. '
          'Kaybolmaz — yalnız beklerler.',
          style: SipText.yardimci.copyWith(color: t.muted),
        ),
        const SipFormEtiket('BAŞLANGIÇ', ustBosluk: 14),
        // ANAHTARLAR TEST İÇİN ve bu bilinçli: iki şerit AYNI 24 metni taşıyor, yani
        // `find.text('11')` iki sonuç döndürüyor ve sıraya güvenen bir test sessizce yanlış
        // şeridi seçebiliyor (ilk koşumda tam bu oldu: başlangıç 6 beklenirken 11 çıktı).
        // Kimliği ürüne yazmak, testin tahmin etmesinden iyidir.
        _SaatSeridi(
          key: const Key('sessiz-baslangic'),
          secili: _bas,
          onSec: (s) => setState(() => _bas = s),
        ),
        const SipFormEtiket('BİTİŞ'),
        _SaatSeridi(
          key: const Key('sessiz-bitis'),
          secili: _bit,
          onSec: (s) => setState(() => _bit = s),
        ),

        // ÖZET SATIRI: iki şerit ayrı ayrı okunuyor, sonucu bir cümlede söylemek gerekiyor.
        // Aynı iki saatin seçilmesi KAPALI demektir ve bunu kullanıcı ancak burada anlar —
        // sessizce "22:00 – 22:00" yazmak, hiçbir şey anlatmayan bir aralık gösterirdi.
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.xl),
          child: AlanNotu(
            kapali
                ? 'Aynı saat seçildi — sessiz saatler KAPALI, bildirimler her an gelir.'
                : 'Sessiz: ${_ss(_bas)} – ${_ss(_bit)}',
            tur: kapali ? AlanNotuTuru.uyari : AlanNotuTuru.bilgi,
          ),
        ),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Kaydet',
          yukseklik: 50,
          onTap: () => Navigator.of(context).pop(
            SessizSaatler(baslangicSaat: _bas, bitisSaat: _bit),
          ),
        ),
      ],
    );
  }
}

/// 24 saatlik yatay hap şeridi; seçili olan accent dolgulu.
class _SaatSeridi extends StatelessWidget {
  const _SaatSeridi({super.key, required this.secili, required this.onSec});

  final int secili;
  final ValueChanged<int> onSec;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 24,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, saat) {
          final secildi = saat == secili;
          return SipDokun(
            onTap: () => onSec(saat),
            zemin: secildi ? t.accent : t.surface2,
            radius: SipRadius.brHap,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                saat.toString().padLeft(2, '0'),
                style: SipText.tutar(14, w: 700)
                    .copyWith(color: secildi ? t.accentInk : t.ink2),
              ),
            ),
          );
        },
      ),
    );
  }
}
