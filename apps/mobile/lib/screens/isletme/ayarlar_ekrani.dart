// AYARLAR ekranı — tasarım s-ayarlar.jsx + Sipario.html `.ayar-kart` / `.ayar-row`.
//
// Kart içinde ayraçlı satırlar: ikon kutusu + başlık (+ alt açıklama) + chevron ya da anahtar.
//
// ══ MAĞAZA KURALI (pazarlıksız) ════════════════════════════════════════════════════════════
// Bu ekranda abonelik / ödeme / satın alma / fiyat / üyelik bağlantısı OLAMAZ. Lisans yalnız
// NÖTR bir bilgi satırı olarak durur ("N gün kaldı"); hiçbir eyleme bağlanmaz. Yasaklı sözcük
// testleri (`Abone`, `Satın al`, `Üye ol`, `Kaydol`) bu ekranı da tarar.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../bildirim/bildirim_ayar_bolumu.dart';
import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../cagri/arayan_tanima_ayari.dart';
import '../cagri/cagri_cozumleyici.dart';
import '../cagri/cagri_gunlugu.dart';
import '../cagri/cagri_karti.dart';
import '../cagri/cagri_model.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/customer_form_screen.dart';
import 'isletme_atomlari.dart';
import 'isletme_profili_ekrani.dart';
import 'siparis_kodu_ayari.dart';

/// Uygulama sürümü — APK'nın KENDİSİNDEN okunur, elle yazılmaz.
///
/// Eskiden burada `'Sipario 3.2'` sabiti duruyordu ve APK'daki gerçek sürümle (o gün hâlâ
/// Flutter varsayılanı olan `1.0.0+1`) HİÇBİR bağı yoktu: 2026-07-27'de dört ayrı APK
/// derlendi, dördü de aynı sürümü gösteriyordu ve sahadaki bayi hangisini test ettiğini
/// söyleyemiyordu. İki yerde ayrı yazılan bir sayı, biri güncellenip diğeri unutulduğunda
/// sessizce yalan söyler.
///
/// `package_info_plus` Android'de `PackageManager`dan okur — yani `build.gradle.kts`in git
/// commit sayısından türettiği yapı numarası ne ise bayi onu görür. Bu YEREL bir sorgudur,
/// ağ kullanmaz; offline-first çizgisi korunur.
///
/// YAPI NUMARASI GÖSTERİLMEK ZORUNDA: saha testinde "hangi APK?" sorusunu tek başına o
/// cevaplıyor. Sürüm adı iki derleme arasında aynı kalabilir, yapı numarası kalamaz.
Future<String> siparioSurumunuOku() async {
  try {
    final bilgi = await PackageInfo.fromPlatform();
    final ad = bilgi.version.trim();
    final yapi = bilgi.buildNumber.trim();
    if (ad.isEmpty) return 'Sipario';
    return yapi.isEmpty ? 'Sipario $ad' : 'Sipario $ad ($yapi)';
  } catch (_) {
    // Platform kanalı yoksa (test ortamı, iOS'ta eksik kayıt) ÇÖKME — nötr metne düş.
    // Ayarlar ekranının tamamı bir sürüm satırı yüzünden açılamaz hâle gelemez; bu dersi
    // bildirim ayar bölümünde bir kez ödedik (LateInitializationError, 2026-07-27).
    return 'Sipario';
  }
}

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({
    super.key,
    required this.db,
    this.rol,
    this.writable = true,
    this.onSihirbaz,
    this.onCagriSimulasyonu,
    this.onOlcumler,
    this.koyuTema,
    this.onTema,
  });

  final AppDatabase db;

  /// `patron|operator|kurye`. Bu ekranın KENDİSİNDE artık rol kapısı yok: Kuryeler/Muaf girişleri
  /// çekmeceye taşındı (tasarım `s-ayarlar.jsx` yalnız Görünüm/Arayan Tanıma/İşletme/Hakkında
  /// bölümlerini taşır) ve kapı orada. Alan, çağrı geçmişinden açılan müşteri defterinin rol
  /// kapısını bağlamak için duruyor (o yüzey `screens/customers/` sahipliğinde).
  final String? rol;

  final bool writable;

  /// Kurulum sihirbazını yeniden çalıştırır (kabuk ajanının akışı).
  final VoidCallback? onSihirbaz;

  /// Verilen numarayla çağrı kartını açar (cagri ajanının akışı).
  final ValueChanged<String>? onCagriSimulasyonu;

  /// Geçerli tema — DEĞER değil DİNLENEBİLİR kaynak. Sahibi KABUKTUR; kalıcılık
  /// `lib/theme/tema_deposu.dart` üzerindedir ve çağrı kartının native tarafı da aynı kaynağı
  /// okur, o yüzden ekran kendi bayrağını tutamaz.
  ///
  /// Düz `bool` geçmek YETMEZ: bu ekran `Navigator.push` ile açılıyor, yani kabuk tema
  /// değişince yeniden çizilse bile bu rota kendi anlık kopyasıyla kalır ve anahtar tema
  /// döndüğü hâlde eski konumunda takılı görünür (cihazda görüldü).
  final ValueListenable<bool>? koyuTema;

  /// Tema değişimini kabuğa bildirir.
  final ValueChanged<bool>? onTema;

  /// Faz 0 gecikme ölçüm ekranını (`Phase0Screen`) açar. Satır YALNIZ hata ayıklama
  /// derlemesinde çizilir — aşağıdaki `kDebugMode` notuna bakın. null → satır hiç çizilmez.
  final VoidCallback? onOlcumler;

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  // Tema kabuktan gelir (tema_deposu.dart orada yaşar): tercih kalıcı olmalı ve çağrı kartının
  // native tarafı da AYNI kaynaktan okuyor. Ekranın kendi bayrağını tutması, anahtarı çevirince
  // hiçbir şeyin kalıcılaşmadığı sahte bir kontrol demekti.

  // Anahtarı `_Govde` (ayrı widget) çeviriyor; `setState` korumalı olduğundan dışarıdan
  // çağrılamaz — geçiş bu genel yöntemden yapılır.
  void koyuTemayiCevir() =>
      widget.onTema?.call(!(widget.koyuTema?.value ?? false));

  Future<void> _cagriDene() async {
    final numara = await sipSheet<String>(
      context,
      baslik: 'Çağrı Simülasyonu',
      govde: (ctx) => const _SimulasyonListesi(),
    );
    if (numara == null || !mounted) return;
    final geriCagri = widget.onCagriSimulasyonu;
    if (geriCagri == null) {
      SipToast.goster(context, 'Çağrı ekranı bu görünümde bağlı değil.');
      return;
    }
    geriCagri(numara);
  }

  /// Çağrı geçmişini açar (`cagri` ajanının ekranı). Giriş noktası ana ekran DEĞİL burasıdır:
  /// ana ekrandaki "Son Arama" kutusunun dokunma davranışı tasarımda zaten dolu, oraya ikinci
  /// bir jest eklemek keşfedilemez olurdu. Muaf Telefonlar ve Çağrı Simülasyonu da bu öbekte.
  Future<void> _cagriGecmisi() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (rotaCtx) => CagriGunluguSayfasi(
        db: widget.db,
        onGeri: () => Navigator.of(rotaCtx).maybePop(),
        onAc: (arama) => _aramayiAc(rotaCtx, arama),
      ),
    ));
  }

  /// Bir arama satırına dokunulduğunda (s-uygulama.jsx:90 kuralı): kayıtlıysa müşteri defteri,
  /// kayıtsızsa çağrı kartı. Kartın kayıtsız hâli tek eylem sunar ("Müşteri Olarak Kaydet"),
  /// o yüzden dönen tek anlamlı sonuç [CagriEylemi.kaydet]'tir.
  ///
  /// Kayıt durumu DOKUNMA ANINDA `cagriKisiCoz` ile yeniden çözülür: geçmiş satırı çağrı
  /// ANINDAKİ eşleşmeyi taşır ve arayan o çağrıdan sonra müşteri olarak kaydedilmiş olabilir.
  /// Eskiden burada koşulsuz `CagriKisi.kayitsiz` geçiliyordu; borçlu bir müşteri bile kartta
  /// "kayıtsız" görünüyordu.
  ///
  /// Kart burada muaf listesine BAKMAZ: muaf kapısı çalan telefonda kartın kendiliğinden
  /// açılmasını engellemek içindir; geçmişten dokunmak kullanıcının kasıtlı isteğidir.
  Future<void> _aramayiAc(BuildContext rotaCtx, AramaKaydi arama) async {
    final kisi = await cagriKisiCoz(widget.db, arama.numara);
    if (!rotaCtx.mounted) return;

    final musteriId = arama.musteriId ?? kisi.musteriId;
    if (musteriId != null) {
      await Navigator.of(rotaCtx).push(MaterialPageRoute<void>(
        builder: (_) => CustomerDetailScreen(
          db: widget.db,
          customerId: musteriId,
          writable: widget.writable,
        ),
      ));
      return;
    }

    // Yön GEÇMİŞ SATIRINDAN gelir: kart yönü kendi başına bilemez, verilmezse "GELEN ÇAĞRI"
    // varsayar ve bayi kendi yaptığı aramanın kartında gelen çağrı görürdü (2026-07-27 saha
    // bulgusunun geçmiş ekranındaki ayağı). `arama.tip` çağrı ANINDAKİ yöndür ve değişmez —
    // kayıt durumunun aksine yeniden çözülmesi gerekmez.
    final eylem = await cagriKartiGoster(rotaCtx, kisi: kisi, yon: arama.tip);
    if (eylem != CagriEylemi.kaydet || !rotaCtx.mounted) return;

    if (!widget.writable) {
      SipToast.goster(rotaCtx, 'Salt-okunur kip: yeni müşteri eklenemez.');
      return;
    }
    final eklendi = await musteriEkleSheet(rotaCtx, db: widget.db, onTel: arama.numara);
    if (eklendi != true || !rotaCtx.mounted) return;

    // Tasarım `s-uygulama.jsx:116`: kayıttan sonra YENİ müşterinin defteri açılır. Kimliği
    // çözücüden yeniden okuyoruz — sheet yalnız "kaydedildi" bilgisini döndürür.
    final yeni = await cagriKisiCoz(widget.db, arama.numara);
    final yeniId = yeni.musteriId;
    if (yeniId == null || !rotaCtx.mounted) return;
    await Navigator.of(rotaCtx).push(MaterialPageRoute<void>(
      builder: (_) => CustomerDetailScreen(
        db: widget.db,
        customerId: yeniId,
        writable: widget.writable,
      ),
    ));
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
              baslik: 'Ayarlar',
              onGeri: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              // İşletme satırındaki ad/iletişim özeti `tenant_settings`ten CANLI okunur —
              // profil ekranında kaydedilince buraya geri dönmeden güncellenir.
              child: StreamBuilder<TenantSetting?>(
                stream: TenantSettingsRepository(widget.db).watch(),
                builder: (context, snap) => _Govde(state: this, profil: snap.data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.state, required this.profil});

  final _AyarlarEkraniState state;

  /// `tenant_settings` satırı; henüz kaydedilmediyse null.
  final TenantSetting? profil;

  @override
  Widget build(BuildContext context) {
    final ad = (profil?.businessName ?? '').trim();
    final sahip = (profil?.ownerName ?? '').trim();
    final telefon = (profil?.phone ?? '').trim();
    final iletisim = [
      if (sahip.isNotEmpty) sahip,
      if (telefon.isNotEmpty) sipTelefon(telefon),
    ].join(' · ');

    return SipGovde(
      children: [
        const SipBolumBaslik('Görünüm', ustBosluk: 18),
        AyarKarti(satirlar: [
          AyarSatiri(
            ikon: SipIcons.moon,
            baslik: 'Koyu tema',
            onTap: state.koyuTemayiCevir,
            sag: ValueListenableBuilder<bool>(
              valueListenable:
                  state.widget.koyuTema ?? const AlwaysStoppedAnimation<bool>(false),
              builder: (context, koyu, child) => SipKnob(acik: koyu),
            ),
          ),
        ]),

        const SipBolumBaslik('Arayan Tanıma', ustBosluk: 18),
        AyarKarti(satirlar: [
          // AÇ/KAPA anahtarı EN ÜSTTE: bölümün diğer satırları (kurulum, geçmiş, deneme)
          // özelliğin parçalarıdır; özelliğin kendisinin düğmesi hepsinden önce gelir.
          const ArayanTanimaSatiri(),
          AyarSatiri(
            ikon: SipIcons.phone,
            baslik: 'Kurulum ve izinler',
            onTap: () {
              final sihirbaz = state.widget.onSihirbaz;
              if (sihirbaz == null) {
                SipToast.goster(context, 'Kurulum sihirbazı bu görünümde bağlı değil.');
              } else {
                sihirbaz();
              }
            },
          ),
          AyarSatiri(
            ikon: SipIcons.clock,
            baslik: 'Çağrı Geçmişi',
            altBaslik: 'Son gelen ve giden aramalar',
            onTap: state._cagriGecmisi,
          ),
          AyarSatiri(
            ikon: SipIcons.phoneCall,
            baslik: 'Gelen çağrıyı dene',
            altBaslik: '4 varyant: borçlu, temiz, alacaklı, kayıtsız',
            onTap: state._cagriDene,
          ),
          // Faz 0 gecikme ölçüm ekranı. Tasarımda YOK ve esnafın menüsünde işi de yok — ama
          // silinemez: çağrı kartının 1 SANİYELİK bütçesini (BRIEF kırmızı çizgisi) ölçen tek
          // araç orası. Girişi kaldırınca ekran hiçbir yerden açılamaz hâle geldi (bu projede
          // Ayarlar/Kuryeler/Muaf dalı aynen böyle ölmüştü), o yüzden `kDebugMode` ile geri
          // kondu: geliştirme derlemesinde ölçüm yapılır, üretim derlemesinde satır derlenmez.
          if (kDebugMode && state.widget.onOlcumler != null)
            AyarSatiri(
              ikon: SipIcons.clock,
              baslik: 'Gecikme ölçümleri',
              altBaslik: 'Çağrı kartı 1 sn bütçesinin ölçüm kaydı · yalnız geliştirme derlemesi',
              onTap: state.widget.onOlcumler,
            ),
        ]),

        // Bildirim bölümü kendi dosyasında (`lib/bildirim/bildirim_ayar_bolumu.dart`):
        // izin durumu ve kategori anahtarları kendi durumunu yönetiyor.
        const BildirimAyarBolumu(),

        if (state.widget.rol == 'patron') ...[
          const SipBolumBaslik('İşletme', ustBosluk: 18),
          AyarKarti(satirlar: [
            AyarSatiri(
              ikon: SipIcons.home,
              baslik: ad.isEmpty ? 'İşletme profili' : ad,
              altBaslik: iletisim.isEmpty ? 'Bilgileri tamamlayın' : iletisim,
              sag: SipMetinButon(
                etiket: 'Düzenle',
                zemin: context.sip.surface2,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => IsletmeProfiliEkrani(
                      db: state.widget.db,
                      writable: state.widget.writable,
                    ),
                  ),
                ),
              ),
            ),
            // Sipariş satırındaki kod tercihi
            SiparisKoduSatiri(db: state.widget.db, writable: state.widget.writable),
          ]),
        ],

        // "Yönetim" bölümü (Kuryeler + Muaf telefonlar) KALDIRILDI: tasarım `s-ayarlar.jsx`
        // yalnız dört bölüm taşır, o iki ekranın girişi ÇEKMECEDEDİR (`s-bilesenler.jsx:83-87`).
        // İki giriş noktası, iki farklı rol kapısı demekti.

        const SipBolumBaslik('Hakkında', ustBosluk: 18),
        _HakkindaKarti(db: state.widget.db),
      ],
    );
  }
}

/// Sürüm + lisans. Lisans NÖTR bilgidir: gün sayısı ve kalan oto-sıralama hakkı gösterilir,
/// hiçbir eyleme bağlanmaz (mağaza kuralı).
///
/// Veri AKIŞTAN okunur, tek atıştan DEĞİL: `validUntilIso` ve `routeCredits` SUNUCU SAHİPLİ
/// alanlardır, senkron sırasında değişirler. `syncState()` tek atışıyla okunduğunda ekran
/// senkrondan sonra bayat değerde kalıyordu (bu vardiyada iki kez görüldü).
class _HakkindaKarti extends StatelessWidget {
  const _HakkindaKarti({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncMetaData>(
      stream: db.watchSyncState(),
      builder: (context, snap) {
        final meta = snap.data;
        return AyarKarti(satirlar: [
          // Sürüm APK'dan okunuyor (asenkron); gelene kadar satır yerini korur ve nötr
          // 'Sipario' yazar — yer değiştiren/zıplayan bir satır yerine sabit bir satır.
          FutureBuilder<String>(
            future: siparioSurumunuOku(),
            builder: (context, surum) => AyarSatiri(
              baslik: 'Sürüm',
              altBaslik: surum.data ?? 'Sipario',
            ),
          ),
          AyarSatiri(baslik: 'Lisans', altBaslik: lisansMetni(meta)),
        ]);
      },
    );
  }
}

/// Lisans satırının metni — tasarım `s-ayarlar.jsx:50` "248 gün kaldı · oto sıralama 34 hak".
///
/// Ekrandan BAĞIMSIZ (saf testle sınanır). Oto sıralama parçası yalnız özellik AÇIKKEN
/// (`routeCreditsMonthly > 0`) yazılır — kapalı bayide "0 hak" görünmesi yanlış olurdu.
/// [simdi] yalnız test içindir.
String lisansMetni(SyncMetaData? meta, {DateTime? simdi}) {
  final parcalar = <String>[_kalanSureMetni(meta, simdi: simdi)];
  if (meta != null && meta.routeCreditsMonthly > 0) {
    parcalar.add('oto sıralama ${meta.routeCredits} hak');
  }
  return parcalar.join(' · ');
}

String _kalanSureMetni(SyncMetaData? meta, {DateTime? simdi}) {
  final bitis = meta?.validUntilIso;
  if (bitis == null) return 'Durum bilinmiyor';
  final t = DateTime.tryParse(bitis);
  if (t == null) return 'Durum bilinmiyor';
  final kalan = t.difference(simdi ?? DateTime.now()).inDays;
  if (kalan < 0) return 'Süre doldu — kayıtlar salt-okunur';
  return '$kalan gün kaldı';
}

/// Simülasyon satırının anlamı — ikon rengini bu belirler (tasarım `s-ayarlar.jsx:6-9`).
enum _SimTuru { borclu, temiz, alacakli, kayitsiz }

/// CSS `.sr-list` + `.aday-row` — tasarımdaki dört çağrı senaryosu.
///
/// Alt satır SOMUT örnek verir (isim + tutar), genel ifade değil: kullanıcı hangi varyantı
/// açtığını kartın çıkmasından ÖNCE bilsin. Renk de satır başına ayrılır — dört satır aynı
/// renkte olunca "borçlu" ile "temiz" arasındaki fark yalnız metinde kalıyordu.
class _SimulasyonListesi extends StatelessWidget {
  const _SimulasyonListesi();

  static List<({String ad, String alt, String no, _SimTuru tur})> get _senaryolar => [
        (
          ad: 'Kayıtlı · Borçlu',
          alt: 'Ahmet Yılmaz · ${sipTutar(34000)} borç',
          no: '05324152290',
          tur: _SimTuru.borclu,
        ),
        (
          ad: 'Kayıtlı · Temiz',
          alt: 'Selin Kaya · hesap temiz',
          no: '05332207841',
          tur: _SimTuru.temiz,
        ),
        (
          ad: 'Kayıtlı · Alacaklı',
          alt: 'Murat Öz · ${sipTutar(12000)} alacak',
          no: '05429076322',
          tur: _SimTuru.alacakli,
        ),
        (
          ad: 'Kayıtsız Numara',
          alt: 'Defterde olmayan arayan',
          no: '02165550188',
          tur: _SimTuru.kayitsiz,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final senaryolar = _senaryolar;
    Color renk(_SimTuru tur) => switch (tur) {
          _SimTuru.borclu => t.danger,
          _SimTuru.temiz => t.ok,
          _SimTuru.alacakli => t.ok,
          _SimTuru.kayitsiz => t.muted,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < senaryolar.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: SipDokun(
              onTap: () => Navigator.of(context).pop(senaryolar[i].no),
              zemin: t.surface,
              basiliZemin: t.accentSoft,
              radius: SipRadius.br2,
              kenarlik: Border.all(color: t.line, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 11),
              child: Row(
                children: [
                  SipIkonKutu(
                    ikon: SipIcons.phoneCall,
                    cap: 32,
                    ikonBoyut: 15,
                    kalinlik: 2.1,
                    zemin: t.surface2,
                    renk: renk(senaryolar[i].tur),
                  ),
                  const SizedBox(width: SipSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senaryolar[i].ad,
                          style: SipText.metin(13, w: 700, h: 1.35).copyWith(color: t.ink),
                        ),
                        Text(
                          '${senaryolar[i].alt} · ${sipTelefon(senaryolar[i].no)}',
                          style: SipText.metin(11, w: 600).copyWith(color: t.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
