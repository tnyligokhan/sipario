// İŞLETME PROFİLİ ekranı — tasarım s-isletme.jsx + Sipario.html `.fk-*`, `.gs-baslik`,
// `.s-flabel`, `.s-input`, `.s-textarea`, `.ym-err`.
//
// Kimlik · iletişim · adres · vergi · çalışma saatleri · fiş alt notu. Kalıcılık `tenant_settings`
// tablosunda TEK SATIR (id=1) olarak durur ve outbox'tan sunucuya LWW upsert ile gider.
//
// FİRMA KODU SUNUCU SAHİPLİDİR: kullanıcılar onunla giriş yapar, cihazdan değiştirilemez.
// Formda alan olarak değil, `.fk-kart` koyu bloğunda salt-okunur + kopyalanabilir gösterilir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../customers/borc_hatirlatma.dart' show hatirlatmaSablonuAzamiUzunluk;
import 'hatirlatma_sablonu_alani.dart';
import 'iban.dart';
import 'isletme_atomlari.dart';

export 'iban.dart' show ibanNormal, ibanOkunur;

/// Salt-okunur kip uyarısı — diğer işletme ekranlarıyla aynı dil.
const String profilSaltOkunurUyarisi = 'Salt-okunur kip: işletme profili değiştirilemez.';

/// Ekranın açılışta ihtiyaç duyduğu her şey: kayıtlı satır + sunucu sahipli firma kodu.
class IsletmeProfilVerisi {
  const IsletmeProfilVerisi({required this.satir, required this.firmaKodu});

  final TenantSetting? satir;
  final String? firmaKodu;
}

class IsletmeProfiliEkrani extends StatefulWidget {
  const IsletmeProfiliEkrani({super.key, required this.db, this.writable = true});

  final AppDatabase db;

  /// Abonelik salt-okunur kipinde false — profil okunur, kaydedilemez.
  final bool writable;

  @override
  State<IsletmeProfiliEkrani> createState() => _IsletmeProfiliEkraniState();
}

class _IsletmeProfiliEkraniState extends State<IsletmeProfiliEkrani> {
  late final TenantSettingsRepository _repo = TenantSettingsRepository(widget.db);
  late final Future<IsletmeProfilVerisi> _veri = _yukle();

  Future<IsletmeProfilVerisi> _yukle() async {
    final satir = await _repo.get();
    final sunucu = await _repo.readOnlyServerFields();
    return IsletmeProfilVerisi(satir: satir, firmaKodu: sunucu.tenantCode);
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
              baslik: 'İşletme Profili',
              onGeri: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: FutureBuilder<IsletmeProfilVerisi>(
                future: _veri,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SipGovde(children: [SipIskelet(adet: 4)]);
                  }
                  return _Form(
                    repo: _repo,
                    veri: snap.data!,
                    writable: widget.writable,
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

class _Form extends StatefulWidget {
  const _Form({required this.repo, required this.veri, required this.writable});

  final TenantSettingsRepository repo;
  final IsletmeProfilVerisi veri;
  final bool writable;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _alanlar = <String, TextEditingController>{
    'ad': TextEditingController(text: widget.veri.satir?.businessName ?? ''),
    'sahip': TextEditingController(text: widget.veri.satir?.ownerName ?? ''),
    'telefon': TextEditingController(text: widget.veri.satir?.phone ?? ''),
    'whatsapp': TextEditingController(text: widget.veri.satir?.whatsapp ?? ''),
    'adres': TextEditingController(text: widget.veri.satir?.addressText ?? ''),
    'vergiDairesi': TextEditingController(text: widget.veri.satir?.taxOffice ?? ''),
    'vergiNo': TextEditingController(text: widget.veri.satir?.taxNumber ?? ''),
    'acilis': TextEditingController(text: widget.veri.satir?.opensAt ?? '08:00'),
    'kapanis': TextEditingController(text: widget.veri.satir?.closesAt ?? '19:00'),
    'fisNotu': TextEditingController(text: widget.veri.satir?.receiptNote ?? ''),
    'iban': TextEditingController(text: ibanOkunur(widget.veri.satir?.iban)),
    'ibanAlici': TextEditingController(text: widget.veri.satir?.ibanOwnerName ?? ''),
    'sablon': TextEditingController(text: widget.veri.satir?.reminderTemplate ?? ''),
  };

  Map<String, String> _hata = const {};
  bool _kaydediyor = false;

  @override
  void dispose() {
    for (final c in _alanlar.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _metin(String anahtar) => _alanlar[anahtar]!.text.trim();

  void _temizle() {
    if (_hata.isNotEmpty) setState(() => _hata = const {});
  }

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    if (!widget.writable) {
      SipToast.goster(context, profilSaltOkunurUyarisi);
      return;
    }

    final hatalar = isletmeProfilHatalari({
      for (final girdi in _alanlar.entries) girdi.key: girdi.value.text,
    });
    if (hatalar.isNotEmpty) {
      setState(() => _hata = hatalar);
      return;
    }

    setState(() => _kaydediyor = true);
    await widget.repo.save(
      businessName: _metin('ad'),
      ownerName: _metin('sahip'),
      phone: _metin('telefon'),
      whatsapp: _bosNull('whatsapp'),
      addressText: _bosNull('adres'),
      taxOffice: _bosNull('vergiDairesi'),
      taxNumber: _bosNull('vergiNo'),
      opensAt: _metin('acilis'),
      closesAt: _metin('kapanis'),
      receiptNote: _bosNull('fisNotu'),
      // Saklama biçimi TEK: boşluksuz, büyük harf. Bayi okunaklı olsun diye boşluklu yazar;
      // mesaja ve sunucuya giden değer normalleştirilmiş olmalı (sunucu da aynısını yapar).
      iban: ibanNormal(_metin('iban')),
      ibanOwnerName: _bosNull('ibanAlici'),
      // Boş şablon null yazılır: "varsayılana dön" bu demektir ve varsayılan metin ileride
      // iyileşirse şablona hiç dokunmamış bayi o iyileşmeyi alır.
      reminderTemplate: _bosNull('sablon'),
    );
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    SipToast.goster(context, 'İşletme profili kaydedildi');
  }

  /// Boş metin null olarak yazılır — "girilmedi" ile "boş bırakıldı" aynı şey, kolon nullable.
  String? _bosNull(String anahtar) {
    final s = _metin(anahtar);
    return s.isEmpty ? null : s;
  }

  Future<void> _kodKopyala(String kod) async {
    await Clipboard.setData(ClipboardData(text: kod));
    if (mounted) SipToast.goster(context, 'Firma kodu kopyalandı');
  }

  @override
  Widget build(BuildContext context) {
    final kod = widget.veri.firmaKodu;
    return SipGovde(
      children: [
        FirmaKoduKarti(
          kod: kod,
          onKopyala: kod == null ? null : () => _kodKopyala(kod),
        ),
        const AlanNotu(
          'Kullanıcılarınız bu kodla giriş yapar; değiştirilemez.',
          tur: AlanNotuTuru.bilgi,
        ),

        // Yıldız = zorunlu alan (tasarım `s-isletme.jsx:32,35,40`). İşaret olmadan kullanıcı
        // hangi alanı boş bırakabileceğini ancak Kaydet'e basıp hata alınca öğreniyordu.
        const SipBolumBaslik('Kimlik', ustBosluk: 20),
        _alan('ad', 'İŞLETME ADI *', 'Ör. Merkez Bayi', ustBosluk: 2),
        _alan('sahip', 'YETKİLİ *', 'Ad Soyad'),

        const SipBolumBaslik('İletişim', ustBosluk: 20),
        _alan('telefon', 'TELEFON *', '0242 XXX XX XX', telefon: true, ustBosluk: 2),
        _alan('whatsapp', 'WHATSAPP HATTI', 'Boş bırakılabilir', telefon: true),
        _alan('adres', 'ADRES', 'Dükkân adresi (fişte görünür)', satirlar: 2),

        const SipBolumBaslik('Vergi', ustBosluk: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _alan('vergiDairesi', 'VERGİ DAİRESİ', 'Ör. Muratpaşa', ustBosluk: 2)),
            const SizedBox(width: SipSpace.xl),
            Expanded(
              child: _alan('vergiNo', 'VERGİ NO', '10-11 rakam',
                  telefon: true, ustBosluk: 2),
            ),
          ],
        ),

        const SipBolumBaslik('Çalışma Saatleri', ustBosluk: 20),
        _SaatSatiri(
          acilis: _alanlar['acilis']!,
          kapanis: _alanlar['kapanis']!,
          hatali: _hata.containsKey('saat'),
          onDegis: _temizle,
        ),
        if (_hata['saat'] != null) AlanNotu(_hata['saat']!),
        const AlanNotu(
          'Saat dışında gelen çağrılar yine kaydedilir, bildirim sessiz kalır.',
          tur: AlanNotuTuru.bilgi,
        ),

        // TAHSİLAT (kullanıcı isteği 2026-08-04): borçluya WhatsApp'tan gönderilen hatırlatma
        // mesajı bu IBAN'ı taşır. Alan boşken düğme çalışmaz ve nedenini söyler — bu yüzden
        // notu "boş bırakılabilir" değil, NE İŞE YARADIĞI yazar.
        const SipBolumBaslik('Tahsilat', ustBosluk: 20),
        _alan('iban', 'IBAN', 'TR00 0000 0000 0000 0000 0000 00',
            ustBosluk: 2, filtreler: [_IbanBicimi()], stilTutar: true),
        // ALICI ADI IBAN'IN HEMEN ALTINDA (kullanıcı isteği 2026-08-06): hesap sahibi çoğu zaman
        // ŞAHIS adıdır ve işletme adıyla aynı değildir; banka uygulaması havale ekranında ad
        // soyad ister, müşteri "Merkez Su Bayii" yazınca işlemi tamamlayamaz. Boş bırakılırsa
        // mesaj eskisi gibi işletme adını yazar — kimse "Alıcı" satırını bu sürümle kaybetmez.
        _alan('ibanAlici', 'IBAN ALICI ADI', 'Hesap sahibi — ad soyad'),
        if (_hata['iban'] == null)
          const AlanNotu(
            'Borçlulara gönderilen WhatsApp hatırlatmasında bu IBAN ve alıcı adı yazar.',
            tur: AlanNotuTuru.bilgi,
          ),

        HatirlatmaSablonuAlani(
          controller: _alanlar['sablon']!,
          hata: _hata['sablon'],
          onDegis: _temizle,
        ),

        // Bölüm başlığından SONRA doğrudan alan gelir (tasarım `s-isletme.jsx:71-72`): araya
        // "FİŞ NOTU" etiketi koymak aynı şeyi iki kez söylemekti.
        const SipBolumBaslik('Fiş Alt Notu', ustBosluk: 20),
        SipInput(
          controller: _alanlar['fisNotu']!,
          ipucu: 'Ör. Bizi tercih ettiğiniz için teşekkürler.',
          satirlar: 2,
          onChanged: (_) => _temizle(),
        ),

        Padding(
          padding: const EdgeInsets.only(top: SipSpace.govde),
          child: SipButon(etiket: 'Kaydet', onTap: _kaydet, yukleniyor: _kaydediyor),
        ),
      ],
    );
  }

  Widget _alan(
    String anahtar,
    String etiket,
    String ipucu, {
    bool telefon = false,
    int satirlar = 1,
    double ustBosluk = 14,
    List<TextInputFormatter>? filtreler,
    bool stilTutar = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SipFormEtiket(etiket, ustBosluk: ustBosluk),
        SipInput(
          controller: _alanlar[anahtar]!,
          ipucu: ipucu,
          satirlar: satirlar,
          klavye: telefon ? TextInputType.phone : null,
          girdiFiltreleri: filtreler,
          stil: (telefon || stilTutar) ? SipText.tutar(15, w: 500) : null,
          hata: _hata.containsKey(anahtar),
          onChanged: (_) => _temizle(),
        ),
        if (_hata[anahtar] != null) AlanNotu(_hata[anahtar]!),
      ],
    );
  }
}

/// IBAN alanı biçimlendirici: harfleri büyütür, IBAN'da yeri olmayan karakterleri düşürür.
///
/// Boşluğa İZİN VERİLİR (silinmez): bayi hesabını bankadan gördüğü gibi "TR12 3456 …" yazar ve
/// kendi yazdığını okuyabilmelidir. Boşluk yalnız KAYDEDERKEN atılır — saklama biçimi tektir.
class _IbanBicimi extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue eski, TextEditingValue yeni) {
    final temiz = yeni.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z ]'), '');
    if (temiz == yeni.text) return yeni;
    // İmleç, düşen karakter sayısı kadar geri alınır; yoksa kullanıcı yazdıkça imleç sona atlar.
    final fark = yeni.text.length - temiz.length;
    final konum = (yeni.selection.baseOffset - fark).clamp(0, temiz.length);
    return TextEditingValue(
      text: temiz,
      selection: TextSelection.collapsed(offset: konum),
    );
  }
}

/// CSS `.fk-kart` — koyu hero blok: "FİRMA KODU" + kod + Kopyala.
class FirmaKoduKarti extends StatelessWidget {
  const FirmaKoduKarti({super.key, required this.kod, this.onKopyala});

  final String? kod;
  final VoidCallback? onKopyala;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.only(top: SipSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(color: t.hero, borderRadius: SipRadius.br2),
      child: DefaultTextStyle(
        style: const TextStyle(color: SipTokens.onHero),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CSS `.fk-l`
                  Text(
                    'FİRMA KODU',
                    style: SipText.metin(10, w: 800)
                        .copyWith(color: SipTokens.onHeroMid, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  // CSS `.fk-kod`
                  Text(
                    kod ?? 'Senkronla gelecek',
                    style: SipText.tutar(15, w: 700)
                        .copyWith(color: SipTokens.onHero, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            if (onKopyala != null) ...[
              const SizedBox(width: SipSpace.lg),
              // Tasarımda (`s-isletme.jsx:27`) düz metin: onay ikonu "kopyalandı" gibi okunup
              // düğmenin bir DURUM gösterdiği yanılgısını veriyordu.
              SipMetinButon(
                etiket: 'Kopyala',
                zemin: SipTokens.onHeroFill2,
                renk: SipTokens.onHero,
                onTap: onKopyala,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Açılış — kapanış: iki ortalanmış saat alanı, aralarında kısa çizgi.
class _SaatSatiri extends StatelessWidget {
  const _SaatSatiri({
    required this.acilis,
    required this.kapanis,
    required this.hatali,
    required this.onDegis,
  });

  final TextEditingController acilis;
  final TextEditingController kapanis;
  final bool hatali;
  final VoidCallback onDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.md),
      child: Row(
        children: [
          Expanded(child: _saatAlani(acilis, '08:00')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl),
            child: Text('—', style: SipText.metin(14, w: 700).copyWith(color: t.muted)),
          ),
          Expanded(child: _saatAlani(kapanis, '19:00')),
        ],
      ),
    );
  }

  Widget _saatAlani(TextEditingController c, String ipucu) => SipInput(
        controller: c,
        ipucu: ipucu,
        klavye: TextInputType.datetime,
        girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
        stil: SipText.tutar(15, w: 600),
        hizalama: TextAlign.center,
        hata: hatali,
        onChanged: (_) => onDegis(),
      );
}

/// Profil doğrulaması — ekrandan BAĞIMSIZ (saf testle sınanır). Alan adı → hata metni.
/// Saat hatası tek anahtarda (`saat`) toplanır: iki alan tek kural, tek satır uyarı.
Map<String, String> isletmeProfilHatalari(Map<String, String> alanlar) {
  final hatalar = <String, String>{};
  String al(String k) => (alanlar[k] ?? '').trim();
  String haneler(String k) => al(k).replaceAll(RegExp(r'\D'), '');

  if (al('ad').length < 2) hatalar['ad'] = 'İşletme adı girin (en az 2 karakter)';
  if (al('sahip').length < 2) hatalar['sahip'] = 'Yetkili adı girin';

  final tel = haneler('telefon');
  if (tel.length < 10 || tel.length > 11) {
    hatalar['telefon'] = 'Geçerli telefon girin (10-11 hane)';
  }

  final wa = haneler('whatsapp');
  if (al('whatsapp').isNotEmpty && (wa.length < 10 || wa.length > 11)) {
    hatalar['whatsapp'] = 'Geçerli numara girin ya da boş bırakın';
  }

  final vno = al('vergiNo');
  if (vno.isNotEmpty && !RegExp(r'^\d{10,11}$').hasMatch(vno)) {
    hatalar['vergiNo'] = 'Vergi no 10-11 rakam olmalı';
  }

  if (!_saatGecerli(al('acilis')) || !_saatGecerli(al('kapanis'))) {
    hatalar['saat'] = 'Saatleri SS:DD biçiminde girin';
  }

  // IBAN boş bırakılabilir (zorunlu alan değil); DOLU ise mod-97 sağlamasını geçmek ZORUNDA.
  // Yanlış IBAN sessiz bir hatadır: mesaj gider, para gelmez, kimse nedenini bilmez.
  final ibanHata = ibanHatasi(al('iban'));
  if (ibanHata != null) hatalar['iban'] = ibanHata;

  // Şablon uzunluğu SUNUCUDAKİ kolonla aynı sınırdadır ve hata BURADA söylenir: sınır yalnız
  // sunucuda olsaydı aşan değer senkron partisinde reddedilir, bayi kaydettiğini sanıp günler
  // sonra "mesajım eski" derdi.
  final sablon = al('sablon');
  if (sablon.length > hatirlatmaSablonuAzamiUzunluk) {
    hatalar['sablon'] =
        'Mesaj çok uzun ($hatirlatmaSablonuAzamiUzunluk karakter sınırı, şu an ${sablon.length})';
  }

  return hatalar;
}

bool _saatGecerli(String s) {
  final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(s);
  if (m == null) return false;
  final saat = int.parse(m.group(1)!);
  final dakika = int.parse(m.group(2)!);
  return saat < 24 && dakika < 60;
}
